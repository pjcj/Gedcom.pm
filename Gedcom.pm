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

use Gedcom::Grammar 1.00;
use Gedcom::Record  1.00;

BEGIN
{
  use vars qw($VERSION);
  $VERSION = "1.00";
}

sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self = { buffer => [], records => [], @_ };
  bless($self, $class);
  return undef unless
    $self->{grammar} = Gedcom::Grammar->new(file     => $self->{grammar_file},
                                            callback => $self->{callback});
# print "grammar is ", Dumper($self->{grammar});

  my $grammar = $self->{grammar};
  my $structures = $grammar->{structures} = $grammar->structures();
  my %children = map { $_->{tag} => $_ }
                     $structures->{GEDCOM}->valid_children($structures);
  $grammar->{valid_children} = \%children;
# print "valid children are: ", join(", ", keys %children), "\n";

  return undef unless
    $self->{record} = Gedcom::Record->new(file     => $self->{gedcom_file},
                                          grammar  => $self->{grammar},
                                          callback => $self->{callback});
  $self->{record}{children} = [ Gedcom::Record->new(tag => "TRLR") ]
    unless @{$self->{record}{children}};
# print "record is ", Dumper($self->{record});
  $self->collect_xrefs();
  $self;
}

sub write
{
  my $self = shift;
  my $file = shift or die "No filename specified";
  $self->{fh} = FileHandle->new($file, "w") or die "Can't open $file: $!";
  $self->{record}->write($self->{fh}, -1);
  $self->{fh}->close() or die "Can't close $file: $!";
}

sub collect_xrefs
{
  my $self = shift;
  my $xrefs = $self->{xrefs} = {};
  $self->{record}->collect_xrefs($xrefs);
}

sub resolve_xrefs
{
  my $self = shift;
  $self->{record}->resolve_xrefs($self->{xrefs});
}

sub validate
{
  my $self = shift;
  my $xrefs = $self->{xrefs};
  for my $child (@{$self->{record}{children}})
  {
    $child->validate($self->{record}, $xrefs);
  }
  1;
}

sub normalise_dates
{
  my $self = shift;
  $self->{record}->normalise_dates();
}

sub renumber
{
  my $self = shift;
  my $callback;
  my $f = 1;
  my $i = 1;
  for my $xref (@_)
  {
    if (exists $self->{xrefs}{$xref})
    {
      $self->{xrefs}{$xref}->renumber($self->{xrefs}, $callback, $f, $i);
    }
  }
  for my $child (@{$self->{record}{children}})
  {
    $child->renumber($self->{xrefs}, $callback, $f, $i);
  }
}

sub order
{
  my $self = shift;
  my ($sort_sub) = @_;
  my $tag_order =
  {
    HEAD => 1,
    SUBM => 2,
    INDI => 3,
    FAM  => 4,
    NOTE => 5,
    TRLR => 6,
  };
  $sort_sub = sub
  {
             $tag_order->{$a->{tag}} <=> $tag_order->{$b->{tag}}
                                     ||
    do { $a->{xref} =~ /(\d+)/; $1 } <=> do { $b->{xref} =~ /(\d+)/; $1 }
  } unless defined $sort_sub;
  local *_ss = $sort_sub;
  @{$self->{record}{children}} = sort _ss @{$self->{record}{children}};
}

1;

__END__

=head1 NAME

Gedcom - a class to manipulate Gedcom genealogy files

Version 1.00 - 8th March 1999

=head1 SYNOPSIS

  use Gedcom;
  my $ged = Gedcom->new(grammar_file => "gedcom-5.5.grammar",
                        gedcom_file  => $gedcom_file);
  return unless $ged->validate;
  $ged->resolve_xrefs($ged->{xrefs});
  $ged->normalise_dates;
  $ged->renumber;
  $ged->order;
  $ged->write("$new_gedcom_file");

=head1 DESCRIPTION

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
to use this module in much greater detail.  This will happen sometime,
but if you would like information in the meantime, feel free to send me
mail.

Note that this is the first release of this software - caveat emptor.

Should you find this software useful, or if you make changes to it, or
if you would like me to make changes to it, please send me mail.  I
would like to have some sort of an idea of the use this software is
getting.  Apart from being of interest to me, this will guide my
decisions when (if :-?) I have to make changes to the interface.

I couldn't find a nice free program I could use to enter my genealogy,
and so I wrote a syntax file (ged.vim) and used vim (http://www.vim.org)
to enter the data, and Gedcom.pm to validate and manipulate it.  I find
this to be a nice solution.

=cut
