# Copyright 1998-2000, Paul Johnson (pjcj@cpan.org)

# This software is free.  It is licensed under the same terms as Perl itself.

# The latest version of this software should be available from my homepage:
# http://www.pjcj.fsnet.co.uk

# documentation at __END__

use strict;

require 5.005;

package Gedcom;

use Data::Dumper;
use FileHandle;

BEGIN { eval "use Text::Soundex" }           # We'll use this if it is available

use vars qw($VERSION $Tags);

BEGIN
{
  $VERSION = "1.07";

  $Tags =
  {
    ABBR => "Abbreviation",
    ADDR => "Address",
    ADOP => "Adoption",
    ADR1 => "Address1",
    ADR2 => "Address2",
    AFN  => "Afn",
    AGE  => "Age",
    AGNC => "Agency",
    ALIA => "Alias",
    ANCE => "Ancestors",
    ANCI => "Ances Interest",
    ANUL => "Annulment",
    ASSO => "Associates",
    AUTH => "Author",
    BAPL => "Baptism-LDS",
    BAPM => "Baptism",
    BARM => "Bar Mitzvah",
    BASM => "Bas Mitzvah",
    BIRT => "Birth",
    BLES => "Blessing",
    BLOB => "Binary Object",
    BURI => "Burial",
    CALN => "Call Number",
    CAST => "Caste",
    CAUS => "Cause",
    CENS => "Census",
    CHAN => "Change",
    CHAR => "Character",
    CHIL => "Child",
    CHR  => "Christening",
    CHRA => "Adult Christening",
    CITY => "City",
    CONC => "Concatenation",
    CONF => "Confirmation",
    CONL => "Confirmation L",
    CONT => "Continued",
    COPR => "Copyright",
    CORP => "Corporate",
    CREM => "Cremation",
    CTRY => "Country",
    DATA => "Data",
    DATE => "Date",
    DEAT => "Death",
    DESC => "Descendants",
    DESI => "Descendant Int",
    DEST => "Destination",
    DIV  => "Divorce",
    DIVF => "Divorce Filed",
    DSCR => "Phy Description",
    EDUC => "Education",
    EMIG => "Emigration",
    ENDL => "Endowment",
    ENGA => "Engagement",
    EVEN => "Event",
    FAM  => "Family",
    FAMC => "Family Child",
    FAMF => "Family File",
    FAMS => "Family Spouse",
    FCOM => "First Communion",
    FILE => "File",
    FORM => "Format",
    GEDC => "Gedcom",
    GIVN => "Given Name",
    GRAD => "Graduation",
    HEAD => "Header",
    HUSB => "Husband",
    IDNO => "Ident Number",
    IMMI => "Immigration",
    INDI => "Individual",
    LANG => "Language",
    LEGA => "Legatee",
    MARB => "Marriage Bann",
    MARC => "Marr Contract",
    MARL => "Marr License",
    MARR => "Marriage",
    MARS => "Marr Settlement",
    MEDI => "Media",
    NAME => "Name",
    NATI => "Nationality",
    NATU => "Naturalization",
    NCHI => "Children_count",
    NICK => "Nickname",
    NMR  => "Marriage_count",
    NOTE => "Note",
    NPFX => "Name_prefix",
    NSFX => "Name_suffix",
    OBJE => "Object",
    OCCU => "Occupation",
    ORDI => "Ordinance",
    ORDN => "Ordination",
    PAGE => "Page",
    PEDI => "Pedigree",
    PHON => "Phone",
    PLAC => "Place",
    POST => "Postal_code",
    PROB => "Probate",
    PROP => "Property",
    PUBL => "Publication",
    QUAY => "Quality Of Data",
    REFN => "Reference",
    RELA => "Relationship",
    RELI => "Religion",
    REPO => "Repository",
    RESI => "Residence",
    RESN => "Restriction",
    RETI => "Retirement",
    RFN  => "Rec File Number",
    RIN  => "Rec Id Number",
    ROLE => "Role",
    SEX  => "Sex",
    SLGC => "Sealing Child",
    SLGS => "Sealing Spouse",
    SOUR => "Source",
    SPFX => "Surn Prefix",
    SSN  => "Soc Sec Number",
    STAE => "State",
    STAT => "Status",
    SUBM => "Submitter",
    SUBN => "Submission",
    SURN => "Surname",
    TEMP => "Temple",
    TEXT => "Text",
    TIME => "Time",
    TITL => "Title",
    TRLR => "Trailer",
    TYPE => "Type",
    VERS => "Version",
    WIFE => "Wife",
    WILL => "Will",
  };
}

use Gedcom::Grammar    1.07;
use Gedcom::Individual 1.07;
use Gedcom::Family     1.07;
use Gedcom::Event      1.07;

sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self =
  {
    buffer    => [],
    records   => [],
    tags      => $Tags,
    tie       => 0,
    read_only => 0,
    types     => {},
    xrefs     => {},
    @_
  };
  # TODO - find a way to do this nicely for different grammars
  $self->{types}{INDI} = "Individual";
  $self->{types}{FAM}  = "Family";
  $self->{types}{$_}   = "Event"
    for qw( ADOP ANUL BAPM BARM BASM BIRT BLES BURI CAST CENS CENS CHR CHRA CONF
            CREM DEAT DIV DIVF DSCR EDUC EMIG ENGA EVEN EVEN FCOM GRAD IDNO IMMI
            MARB MARC MARL MARR MARS NATI NATU NCHI NMR OCCU ORDN PROB PROP RELI
            RESI RETI SSN WILL );
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
    @c = map { $_->{top} = $grammar; @{$_->{items}} } @c;
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
    $self->{record}{items} = [ Gedcom::Record->new(tag => "TRLR") ]
      unless @{$self->{record}{items}};

    $self->collect_xrefs;
  }
  $self;
}

sub write
{
  my $self  = shift;
  my $file  = shift or die "No filename specified";
  my $flush = shift;
  $self->{fh} = FileHandle->new($file, "w") or die "Can't open $file: $!";
  $self->{record}->write($self->{fh}, -1, $flush);
  $self->{fh}->close or die "Can't close $file: $!";
}

sub write_xml
{
  my $self  = shift;
  my $file  = shift or die "No filename specified";
  $self->{fh} = FileHandle->new($file, "w") or die "Can't open $file: $!";
  $self->{record}->write_xml($self->{fh});
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
  for my $item (@{$self->{record}->_items})
  {
    $ok = 0 unless $item->validate_semantics;
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
  $_->renumber(\%args, 1) for @{$self->{record}->_items};

  # actually change the xref
  for my $record (@{$self->{record}->_items})
  {
    $record->{xref} = delete $record->{new_xref};
    delete $record->{recursed}
  }

  # and update the xrefs
  $self->collect_xrefs;

  %args
}

sub sort_sub
{
  my $self = shift;

  # subroutine to sort on tag order first, and then on xref

  my $tag_order =
  {
    HEAD => 1,
    SUBM => 2,
    INDI => 3,
    FAM  => 4,
    NOTE => 5,
    REPO => 6,
    SOUR => 7,
    TRLR => 8,
  };

  my $t = sub
  {
    my ($r) = @_;
    return -2 unless defined $r->{tag};
    exists $tag_order->{$r->{tag}} ? $tag_order->{$r->{tag}} : -1
  };

  my $x = sub
  {
    my ($r) = @_;
    return -2 unless defined $r->{xref};
    $r->{xref} =~ /(\d+)/;
    defined $1 ? $1 : -1
  };

  sub
  {
    $t->($a) <=> $t->($b)
              ||
    $x->($a) <=> $x->($b)
  }
}

sub order
{
  my $self     = shift;
  my $sort_sub = shift || sort_sub;   # use default sort unless one is passed in
  local *_ss = $sort_sub;
  @{$self->{record}{items}} = sort _ss @{$self->{record}->_items}
}

sub individuals
{
  my $self = shift;
  grep { ref eq "Gedcom::Individual" } @{$self->{record}->_items}
}

sub families
{
  my $self = shift;
  grep { ref eq "Gedcom::Family" } @{$self->{record}->_items}
}

sub get_individual
{
  my $self = shift;
  my $name = "@_";

  my $i = $self->resolve_xref($name) || $self->resolve_xref(uc $name);
  return $i if $i;

  # search for the name in the specified order
  my $ordered = sub
  {
    my ($n, @ind) = @_;
    map { $_->[1] } grep { $_->[0] =~ $n } @ind
  };

  # search for the name in any order
  my $unordered = sub
  {
    my ($names, $t, @ind) = @_;
    map { $_->[1] }
        grep
        {
          my $i = $_->[0];
          my $r = 1;
          for my $n (@$names)
          {
            # remove matches as they are found
            # we don't want to match the same name twice
            last unless $r = $i =~ s/$n->[$t]//;
          }
          $r
        }
        @ind;
  };

  # look for various matches in decreasing order of exactitude
  my @individuals = $self->individuals;
  my @i;

  # Store the name with the individual to avoid continually recalculating it.
  # This is a bit like a Schwartzian transform, with a grep instead of a sort.
  my @ind = map { [ $_->tag_value("NAME") => $_ ] } @individuals;

  for my $n ( map { qr/^$_$/, qr/\b$_\b/, $_ } map { $_, qr/$_/i } qr/\Q$name/ )
  {
    return wantarray ? @i : $i[0] if @i = $ordered->($n, @ind)
  }

  # create an array with one element per name
  # each element is an array of REs in decreasing order of exactitude
  my @names = map { [ map { qr/\b$_\b/, $_ } map { qr/$_/, qr/$_/i } "\Q$_" ] }
              split / /, $name;
  for my $t (0 .. $#{$names[0]})
  {
    return wantarray ? @i : $i[0] if @i = $unordered->(\@names, $t, @ind)
  }

  # check soundex
  my @sdx = map { [ $_->soundex => $_ ] } @individuals;

  for my $n ( map { qr/$_/ } $name, soundex($name) )
  {
    return wantarray ? @i : $i[0] if @i = $ordered->($n, @sdx)
  }

  return wantarray ? () : undef;
}

sub next_xref
{
  my $self = shift;
  my ($type) = @_;
  my $re = qr/^$type(\d+)$/;
  my $last = 0;
  for my $c (@{$self->{record}->_items})
  {
    # warn "last $last xref $c->{xref}\n";
    $last = $1 if defined $c->{xref} and $c->{xref} =~ /$re/ and $1 > $last;
  }
  $type . ++$last
}

1;

__END__

=head1 NAME

Gedcom - a module to manipulate Gedcom genealogy files

Version 1.07 - 14th March 2000

=head1 SYNOPSIS

  use Gedcom;

  my $ged = Gedcom->new(gedcom_file => $gedcom_file);
  my $ged = Gedcom->new(grammar_version => 5.5,
                        gedcom_file     => $gedcom_file,
                        callback        => $cb);
  my $ged = Gedcom->new(grammar_file => "gedcom-5.5.grammar",
                        gedcom_file  => $gedcom_file);
  return unless $ged->validate;
  my $xref = $self->resolve_xref($value);
  $ged->resolve_xrefs;
  $ged->unresolve_xrefs;
  $ged->normalise_dates;
  my %xrefs = $ged->renumber;
  $ged->order;
  $ged->write($new_gedcom_file, $flush);
  $ged->write_xml($fh, $level);
  my @individuals = $ged->individuals;
  my @families = $ged->families;
  my $me = $ged->get_individual("Paul Johnson");
  my $xref = $ged->next_xref("I");

=head1 DESCRIPTION

Copyright 1998-2000, Paul Johnson (pjcj@cpan.org)

This software is free.  It is licensed under the same terms as Perl itself.

The latest version of this software should be available from my homepage:
http://www.pjcj.fsnet.co.uk

This module provides for manipulation of Gedcom files.  Gedcom is a
format for storing genealogical information designed by The Church of
Jesus Christ of Latter-Day Saints (http://www.lds.org).  Information
about Gedcom is available as a zip file at
ftp://gedcom.org/pub/genealogy/gedcom/gedcom55.zip.  Unfortunately, this
is only usable if you can access a PC running Windows of some
description.  Part of the reason I wrote this module is because I don't
do that.  Well, I didn't.  I can now although I prefer not to...

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
release has more documentation than the previous ones - but if you would
like information feel free to send me mail.

This module provides some functions which work over the entire Gedcom
file, such as reformatting dates, renumbering entries and ordering the
entries.  It also allows access to individuals, and then to relations of
individuals, for example sons, siblings, spouse, parents and so forth.

This release includes a lines2perl program to convert LifeLines programs
to Perl.  The program works, but it has a few rough edges, and some
missing functionality.  I'll be working on it when it hits the top of my
TODO list.

This release provides an option for read only access to the gedcom file.
Actually, this doesn't stop you changing or writing the file, but it
does parse the gedcom file lazily, meaning that only those portions of
the gedcom file which are needed will be read.  This can provide a
substantial saving of time and memory providing that not too much of the
gedcom file is read.  If you are going to read the whole gedcom file,
this mode is less efficient.

Note that this is an early release of this software - caveat emptor.

Should you find this software useful, or if you make changes to it, or
if you would like me to make changes to it, please send me mail.  I
would like to have some sort of an idea of the use this software is
getting.  Apart from being of interest to me, this will guide my
decisions when I feel the need to make changes to the interface.

There is a low volume mailing list available for discussing the use of
Perl in conjunction with genealogical work.  This is an appropriate
forum for discussing Gedcom.pm.  To subscribe to the regular list, send
a message to majordomo@icomm.ca and put subscribe S<perl-gedcom> as the
body of the message. To get on the digest version of the list, put
subscribe S<perl-gedcom-digest>.

To store my genealogy I wrote a syntax file (gedcom.vim) and used vim
(http://www.vim.org) to enter the data, and Gedcom.pm to validate and
manipulate it.  I find this to be a nice solution.

=head1 GETTING STARTED

This space is reserved for something of a tutorial.  If you learn best
by looking at examples, take a look at the test directory, I<t>.  The
most simple test is I<birthdates.t>.

The first thing to do is to read in the Gedcom file.  At its most
simple, this will involve a statement such as

  my $ged = Gedcom->new(gedcom_file => $gedcom_file);

It is now possible to access the records within the gedcom file.  Each
individual and family is a record.  Records can contain other records.
For example, an individual is a record.  The birth information is
a sub-record of the individual, and the date of birth is a sub-record of
the birth record.

Some records, such as the birth record, are simply containers for other
records.  Some records have a value, such as the date record, whose
value is a date.  This is all defined in the Gedcom standard.

To access an individual use a statement such as

  my $i = $ged->get_individual("Paul Johnson");

To access information about the individual, use a function of the same
name as the Gedcom tag, or its description.  Tags and descriptions are
listed at the head of Gedcom.pm.  For example

    for my $b ($i->birth)
    {
    }

will loop through all the birth records in the individual.  Usually
there will only be one such record, but there may be zero, one or more.
Calling the function in scalar context will return only the first
record.

  my $b = $i->birth;

But the second record may be returned with

  my $b = $i->birth(2);

If the record required has a value, for example

  my $n = $i->name;

then the value is returned, in this case the name of the individual.  If
there is no value, as is the case for the birth record, then the record
itself is returned.  If there is a value, but the record itself is
required, then the get_record() function can be used.

Information must be accesed through the Gedcom structure so, for
example, the birthdate is accessed via the date record from the birth
record within an individual.

  my $d = $b->date;

Be aware that if you access a record in scalar context, but there is no
such record, then undef is returned.  In this case, $b would be undef if
$i had no birth record.  This is another reason why looping through
records is a nice solution, all else being equal.

Access to values can also be gained through the get_value() function.
This is a preferable solution where it is necessary to work down the
Gedcom structure.  For example

  my $bd = $i->get_value("birth date");
  my $bd = $i->get_value(qw(birth date));

will both return an individual's birth date or undef if there is none.
And

  my @bd = $i->get_value("birth date");

will return all the birth dates.  The second birth date, if there is
one, is

  my $bd2 = $i->get_value(["birth", 2], "date");

Using the get_record() function in place of the get_value() function, in
all cases will return the record rather than the value.

All records are of a type derived from Gedcom::Item.  Individuals are of
type Gedcom::Individual.  Families are of type Gedcom::Family.  Events
are of type Gedcom::Event.  Other records are of type Gedcom::Record
which is the base type of Gedcom::Individual, Gedcom::Family and
Gedcom::Event.

As individuals are of type Gedcom::Individual, the functions in
Gedcom::Individual.pm are available.  These allow access to relations
and other information specific to individuals, for example

  my @sons = $i->sons;

It is possible to get all the individuals in the gedcom file as

  my @individuals = $ged->individuals;

=head1 HASH MEMBERS

I have not gone the whole hog with data encapsulation and such within
this module.  Maybe I should have done.  Maybe I will.  For now though,
the data is accessable though hash members.  This is partly because
having functions to do this is a little slow, especially on my old
DECstation, and partly because of laziness again.  I'm not too sure
whether this is good or bad laziness yet.  Time will tell no doubt.

As of version 1.05, you should be able to access all the data through
functions.  Well, read access anyway.  The TODO list mentions something
about improving the situation as far as write access is concerned.

Some of the more important hash members are:

=head2 $ged->{grammar}

This contains the gedcom grammar.

See Gedcom::Grammar.pm for more details.

=head2 $ged->{record}

This contains the top level gedcom record.  A record contains a number
of items.  Each of those items are themselves records.  This is the way
in which the hierarchies are modelled.

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

  $ged->write($new_gedcom_file, $flush);

Write out the gedcom file.

Takes the name of the new gedcom file, and whether or not to indent the
output according to the level of the record.  $flush defaults to false,
but the new file name must be specified.

=head2 write_xml

  $ged->write_xml($fh);

Write the item to a FileHandle as XML.

Takes the name of the new gedcom file.

Note that this function is experimental.  The XML output doesn't conform
to any standard that I know of, because I don't know of any standard.
If and when such a standard surfaces, and probably even if it doesn't,
I'll change the output from this function.  If you make use of this
function, beware.  I'd also be very interested in hearing from you to
determine the requirements for the XML.

=head2 collect_xrefs

  $ged->collect_xrefs($callback);

Collect all the xrefs into a data structure ($ged->{xrefs}) for easy
location.  $callback is not used yet.

Called by new().

=head2 resolve_xref

  my $xref = $self->resolve_xref($value);

Return the record $value points to, or undef.

=head2 resolve_xrefs

  $ged->resolve_xrefs($callback);

Changes all xrefs to reference the record they are pointing to.  Like
changing a soft link to a hard link on a Unix filesystem.  $callback is
not used yet.

=head2 unresolve_xrefs

  $ged->unresolve_xrefs($callback);

Changes all xrefs to name the record they contained.  Like changing a
hard link to a soft link on a Unix filesystem.  $callback is not used
yet.

=head2 validate

  return unless $ged->validate($callback);

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

  my $me = $ged->get_individual("Paul Johnson");

Return a list of all individuals matching the specified name.

There are thirteen matches performed, and the results from the first
successful match are returned.

The matches are:

   1 - Xref
   2 - Exact
   3 - On word boundaries
   4 - Anywhere
   5 - Exact, case insensitive
   6 - On word boundaries, case insensitive
   7 - Anywhere, case insensitive
   8 - Names in any order, on word boundaries
   9 - Names in any order, anywhere
  10 - Names in any order, on word boundaries, case insensitive
  11 - Names in any order, anywhere, case insensitive
  12 - Soundex code
  13 - Soundex of name

=head2 next_xref

  my $xref = $ged->next_xref("I");

Return the next available xref with the specified prefix.

=cut
