# Copyright 1998-1999, Paul Johnson (pjcj@transeda.com)

# This software is free.  It is licensed under the same terms as Perl itself.

# The latest version of this software should be available from my homepage:
# http://www.transeda.com/pjcj

# documentation at __END__

use strict;

require 5.004;

package Gedcom;

use Data::Dumper;
use FileHandle;

use Gedcom::Grammar    1.03;
use Gedcom::Individual 1.03;
use Gedcom::Family     1.03;

use vars qw($VERSION);
$VERSION = "1.03";

sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self = { buffer => [], records => [], xrefs => {}, @_ };
  bless $self, $class;

  # first read in the grammar
  my $grammar;
  if (defined $self->{grammar_file})
  {
    return undef unless
      $grammar = Gedcom::Grammar->new(file     => $self->{grammar_file},
                                      callback => $self->{callback});
  }
  else
  {
    $self->{grammar_version} = 5.5 unless defined $self->{grammar_version};
    (my $v = $self->{grammar_version}) =~ tr/./_/;
    my $g = "Gedcom::Grammar_$v";
    eval "use $g $VERSION";
    die $@ if $@;
    no strict "refs";
    return undef unless $grammar = ${$g . "::grammar"};
  }
  my @c = ($self->{grammar} = $grammar);
  while (@c)
  {
    @c = map { $_->{top} = $grammar; @{$_->{children}} } @c;
  }

  # now read in the gedcom file
  if (defined $self->{gedcom_file})
  {
    return undef unless
      $self->{record} =
        Gedcom::Record->new(file     => $self->{gedcom_file},
                            line     => 0,
                            tag      => "GEDCOM",
                            grammar  => $grammar->structure("GEDCOM"),
                            gedcom   => $self,
                            callback => $self->{callback});
  }
  $self->{record}{children} = [ Gedcom::Record->new(tag => "TRLR") ]
    unless @{$self->{record}{children}};

  $self->collect_xrefs;
  $self;
}

sub write
{
  my $self = shift;
  my $file = shift or die "No filename specified";
  $self->{fh} = FileHandle->new($file, "w") or die "Can't open $file: $!";
  $self->{record}->write($self->{fh}, -1);
  $self->{fh}->close or die "Can't close $file: $!";
}

sub collect_xrefs
{
  my $self = shift;
  my ($callback) = @_;
  $self->{gedcom}{xrefs} = [];
  $self->{record}->collect_xrefs($callback);
}

sub resolve_xref
{
  my $self = shift;;
  my ($x) = @_;
  my $xref;
  $xref = $self->{xrefs}{$x =~ /^\@(.*)\@$/ ? $1 : $x} if defined $x;
  $xref;
}

sub resolve_xrefs
{
  my $self = shift;
  my ($callback) = @_;
  $self->{record}->resolve_xrefs($callback);
}

sub unresolve_xrefs
{
  my $self = shift;
  my ($callback) = @_;
  $self->{record}->unresolve_xrefs($callback);
}

sub validate
{
  my $self = shift;
  my ($callback) = @_;
  $self->{validate_callback} = $callback;
  my $ok = $self->{record}->validate_syntax;
  for my $child (@{$self->{record}{children}})
  {
    $ok = 0 unless $child->validate_semantics;
  }
  $ok;
}

sub normalise_dates
{
  my $self = shift;
  $self->{record}->normalise_dates(@_);
}

sub renumber
{
  my $self = shift;
  my (%args) = @_;
  $self->resolve_xrefs;

  # initially, renumber any records passed in
  for my $xref (@{$args{xrefs}})
  {
    $self->{xrefs}{$xref}->renumber(\%args, 1) if exists $self->{xrefs}{$xref};
  }

  # now, renumber any records left over
  $_->renumber(\%args, 1) for @{$self->{record}{children}};

  # and remove new_xref so we can do it again
  delete @$_{qw(renumbered recursed)} for @{$self->{record}{children}};

  # and update the xrefs
  $self->collect_xrefs;

  %args
}

sub sort_sub
{
  my $self = shift;
  my $tag_order =
  {
    HEAD => 1,
    SUBM => 2,
    INDI => 3,
    FAM  => 4,
    NOTE => 5,
    TRLR => 6,
  };

  # subroutine to sort on tag order first, and then on xref
  sub
  {
             $tag_order->{$a->{tag}} <=> $tag_order->{$b->{tag}}
                                     ||
    do { $a->{xref} =~ /(\d+)/; $1 } <=> do { $b->{xref} =~ /(\d+)/; $1 }
  }
}

sub order
{
  my $self     = shift;
  my $sort_sub = shift || sort_sub;   # use default sort unless one is passed in
  local *_ss = $sort_sub;
  @{$self->{record}{children}} = sort _ss @{$self->{record}{children}}
}

sub individuals
{
  my $self = shift;
  grep { ref eq "Gedcom::Individual" } @{$self->{record}{children}}
}

sub families
{
  my $self = shift;
  grep { ref eq "Gedcom::Family" } @{$self->{record}{children}}
}

sub get_individual
{
  my $self = shift;
  my $name = "@_";

  # Store the name with the individual to avoid continually recalculating it.
  # This is a bit like a Schwartzian transform, with a grep instead of a sort.
  my @ind = map { [ $_->child_value("NAME") => $_ ] } $self->individuals;

  # look for various matches in decreasing order of exactitude
  my @i;
  for my $n ( map { qr/^$_$/, qr/\b$_\b/, $_ } map { $_, qr/$_/i } qr/\Q$name/ )
  {
    return @i if @i = map { $_->[1] } grep { $_->[0] =~ $n } @ind
  }

  # look for the names in any order
  # create an array with one element per name
  # each element is an array of REs in decreasing order of exactitude
  my @n = map { [ map { qr/\b$_\b/, $_ } map { qr/$_/, qr/$_/i } "\Q$_" ] }
              split / /, $name;
  for my $t (0 .. $#{$n[0]})
  {
    return @i if @i = map { $_->[1] }
                          grep
                          {
                            my $i = $_->[0];
                            my $r = 1;
                            for my $n (@n)
                            {
                              # remove matches as they are found - we
                              # don't want to match the same name twice
                              last unless $r = $i =~ s/$n->[$t]//;
                            }
                            $r
                          }
                          @ind;
  }
  ()
}

sub next_xref
{
  my $self = shift;
  my ($type) = @_;
  my $re = qr/^$type(\d+)$/;
  my $last = 0;
  for my $c (@{$self->{record}{children}})
  {
    $last = $1 if exists $c->{xref} and $c->{xref} =~ /$re/ and $1 > $last;
  }
  $type . ++$last
}

1;

__END__

=head1 NAME

Gedcom - a class to manipulate Gedcom genealogy files

Version 1.03 - 13th May 1999

=head1 SYNOPSIS

  use Gedcom;

  my $ged = Gedcom->new(gedcom_file => $gedcom_file);
  my $ged = Gedcom->new(grammar_version => 5.5,
                        gedcom_file     => $gedcom_file,
                        callback        => $cb);
  my $ged = Gedcom->new(grammar_file => "gedcom-5.5.grammar",
                        gedcom_file  => $gedcom_file);
  return unless $ged->validate;
  my $xref = $self->resolve_xref($value)
  $ged->resolve_xrefs;
  $ged->unresolve_xrefs;
  $ged->normalise_dates;
  my %xrefs = $ged->renumber;
  $ged->order;
  $ged->write($new_gedcom_file);
  my @individuals = $ged->individuals;
  my @families = $ged->families;
  my ($me) = $ged->get_individual("Paul Johnson");
  my $xref = $ged->next_xref("I");

=head1 DESCRIPTION

Copyright 1998-1999, Paul Johnson (pjcj@transeda.com)

This software is free.  It is licensed under the same terms as Perl itself.

The latest version of this software should be available from my homepage:
http://www.transeda.com/pjcj

This module provides for manipulation of Gedcom files.  Gedcom is a
format for storing genealogical information designed by The Church of
Jesus Christ of Latter-Day Saints (http://www.lds.org).  Information
about Gedcom is available as a zip file at
ftp://gedcom.org/pub/genealogy/gedcom/gedcom55.zip.  Unfortunately, this
is only usable if you can access a PC running Windows of some
description.  Part of the reason I wrote this module is because I don't
do that.

The Gedcom format is specified in a grammar file (gedcom-5.5.grammar).
Gedcom.pm parses the grammar which is then used to validate and allow
manipulation of the Gedcom file.  I have only used Gedcom.pm with
version 5.5 of the Gedcom grammar, which I had to modify slightly to
correct a few errors.  The advantage of this approach is that Gedcom.pm
should be useful if the Gedcom grammar is ever updated.  It also made
the software easier to write, and probably more dependable too.  I
suppose this is the virtue of laziness shining through.

The vice of laziness is also shining brightly - I need to document how
to use this module in much greater detail.  This is happening - this
release has more docuemntation than the previous ones - but if you would
like information feel free to send me mail.

This module provides some functions which work over the entire Gedcom
file, such as reformatting dates, renumbering entries and ordering the
entries.  It also allows acces to individuals, and then to relations of
individuals, for example sons, siblings, spouse, parents and so forth.

Note that this is an early release of this software - caveat emptor.

Should you find this software useful, or if you make changes to it, or
if you would like me to make changes to it, please send me mail.  I
would like to have some sort of an idea of the use this software is
getting.  Apart from being of interest to me, this will guide my
decisions when I feel the need to make changes to the interface.

I couldn't find a nice free program I could use to enter my genealogy,
and so I wrote a syntax file (ged.vim) and used vim (http://www.vim.org)
to enter the data, and Gedcom.pm to validate and manipulate it.  I find
this to be a nice solution.

=head1 HASH MEMBERS

I have not gone the whole hog with data encapsulation and such within
this module.  Maybe I should have done.  Maybe I will.  For now though,
the data is accessable though hash members.  This is partly because
having functions to do this is a little slow, especially on my old
DECstation, and partly because of laziness again.  I'm not too sure
whether this is good or bad laziness yet.  Time will tell no doubt.

Some of the more important hash members are:

=head2 $ged->{grammar}

This contains the gedcom grammar.

See Gedcom::Grammar.pm for more details.

=head2 $ged->{record}

This contains the top level gedcom record.  A record contains a number
of children.  Each of those children are themselves records.  This is
the way in which the hierarchies are modelled.

If you want to get at the data in the gedcom object, this is where you
start.

See Gedcom::Record.pm for more details.

=head1 METHODS

=head2 new

  my $ged = Gedcom->new(gedcom_file => $gedcom_file);

  my $ged = Gedcom->new(grammar_version => 5.5,
                        gedcom_file     => $gedcom_file,
                        callback        => $cb);

  my $ged = Gedcom->new(grammar_file => "gedcom-5.5.grammar",
                        gedcom_file  => $gedcom_file);

Create a new gedcom object.

gedcom_file is the name of the gedcom file to parse.

You may optionally pass grammar_version as the version number of the
gedcom grammar you want to use.  At the moment only version 5.5 is
available.  If you do not specify a grammar version, you may specify a
grammar file as grammar_file.  Usually, you will do neither of these,
and in this case the grammar version will default to the latest
available version, currently 5.5.

callback is an optional reference to a subroutine which will be called
at various times while the gedcom file (and the grammar file, ir
applicable) is being read.  It's purpose is to provide feedback during
potentially long operations.  The subroutine is called with five
arguments:

  my ($title, $txt1, $txt2, $current, $total) = @_;

  $title is a brief description of the current operation
  $txt1 and $txt2 provide more information on the current operation
  $current is the number of operations performed
  $total is the number of operations that need to be performed

If the subroutine returns false, the operation is aborted.

=head2 write

  $ged->write($new_gedcom_file);

Write out the gedcom file.

Takes the name of the new gedcom file.

=head2 collect_xrefs

  $ged->collect_xrefs($callback)

Collect all the xrefs into a data structure ($ged->{xrefs}) for easy
location.  $callback is not used yet.

Called by new().

=head2 resolve_xref

  my $xref = $self->resolve_xref($value)

Return the record $value points to, or undef.

=head2 resolve_xrefs

  $ged->resolve_xrefs($callback)

Changes all xrefs to reference the record they are pointing to.  Like
changing a soft link to a hard link on a Unix filesystem.  $callback is
not used yet.

=head2 unresolve_xrefs

  $ged->unresolve_xrefs($callback)

Changes all xrefs to name the record they contained.  Like changing a
hard link to a soft link on a Unix filesystem.  $callback is not used
yet.

=head2 validate

  return unless $ged->validate($callback)

Validate the gedcom object.  This performs a number of consistency
checks, but could do even more.  $callback is not properly used yet.

Any errors found are given out as warnings.  If this is unwanted, use
$SIG{__WARN__} to catch the warnings.

Returns true iff the gedcom object is valid.

=head2 normalise_dates

  $ged->normalise_dates;
  $ged->normalise_dates("%A, %E %B %Y");

Change all recognised dates into a consistent format.  This routine used
Date::Manip to do the work, so you can look at it's documentation
regarding formats that are recognised and % sequences for the output.

Optionally takes a format to use for the output.  The default is
currently "%A, %E %B %Y", but I may change this, as it seems that some
programs don't like that format.

=head2 renumber

  $ged->renumber;
  my %xrefs = $ged->renumber(INDI => 34, FAM => 12, xrefs => [$xref1, $xref2]);

Renumber all the records.

Optional parameters are:

  tag name => last used number (defaults to 0)
  xrefs    => list of xrefs to renumber first

As a record is renumbered, it is assigned the next available number.
The husband, wife, children parents and siblings are then renumbered in
that order.  This helps to ensure that families are numerically close
together.

The hash returned is the updated hash that was passed in.

=head2 sort_sub

  $ged->order($ged->sort_sub);

Default ordering subroutine.

The sort is by record type in the following order: HEAD, SUBM, INDI,
FAM, NOTE, TRLR, and then by xref within the type.

=head2 order

  $ged->order;
  $ged->order($order_sub);

Order all the records.  Optionally provide a sort subroutine.

This orders the entries within the gedcom object, which will affect the
order in which they are written out.  The default sort function is
Gedcom::sort_sub.  You will need to ensure that the HEAD record is first
and that the TRLR record is last.

=head2 individuals

  my @individuals = $ged->individuals;

Return a list of all the individuals.

=head2 families

  my @families = $ged->families;

Return a list of all the families.

=head2 get_individual

  my ($me) = $ged->get_individual("Paul Johnson");

Return a list of all individuals matching the specified name.

There are ten matches performed, and the results from the first
successful match are returned.

The matches are:

   1 - Exact
   2 - On word boundaries
   3 - Anywhere
   4 - Exact, case insensitive
   5 - On word boundaries, case insensitive
   6 - Anywhere, case insensitive
   7 - Names in any order, on word boundaries
   8 - Names in any order, anywhere
   9 - Names in any order, on word boundaries, case insensitive
  10 - Names in any order, anywhere, case insensitive

=head2 next_xref

  my $xref = $ged->next_xref("I");

Return the next available xref with the specified prefix.

=cut
