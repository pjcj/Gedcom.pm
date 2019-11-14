# Gedcom - a module to manipulate GEDCOM genealogy files

[![Build Status](https://travis-ci.org/pjcj/Gedcom.pm.svg?branch=master)](https://travis-ci.org/pjcj/Gedcom.pm) [![Coverage Status](https://coveralls.io/repos/github/pjcj/Gedcom.pm/badge.svg?branch=master)](https://coveralls.io/github/pjcj/Gedcom.pm?branch=master)

# SYNOPSIS

    use Gedcom;

    my $ged = Gedcom->new;
    my $ged = Gedcom->new($gedcom_file);
    my $ged = Gedcom->new(grammar_version => "5.5.1",
                          gedcom_file     => $gedcom_file,
                          read_only       => 1,
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
    $ged->set_encoding("utf-8");
    $ged->write($new_gedcom_file, $flush);
    $ged->write_xml($new_xml_file);
    my @individuals = $ged->individuals;
    my @families = $ged->families;
    my $me = $ged->get_individual("Paul Johnson");
    my $xref = $ged->next_xref("I");
    my $record = $ged->add_header;
                       add_submitter
                       add_individual
                       add_family
                       add_note
                       add_repository
                       add_source
                       add_trailer
    my $source = $ged->get_source("S1");

# DESCRIPTION

This module provides for manipulation of GEDCOM files.  GEDCOM is a format for
storing genealogical information designed by The Church of Jesus Christ of
Latter-Day Saints (http://www.lds.org).  Information about GEDCOM used to be
available as a zip file at ftp://gedcom.org/pub/genealogy/gedcom/gedcom55.zip.
That may still be the case, but it seems to be password protected now.
However, the document in that archive seems to be available in a somewhat more
accessible format at
https://chronoplexsoftware.com/gedcomvalidator/gedcom/gedcom-5.5.pdf.

Requirements:

    Perl 5.005 or later
    ActivePerl5 Build Number 520 or later has been reported to work

Optional Modules:

    Date::Manip.pm       to work with dates
    Text::Soundex.pm     to use soundex
    Parse::RecDescent.pm to use lines2perl
    Roman.pm             to use the LifeLines function roman from lines2perl

The GEDCOM format is specified in a grammar file (gedcom-5.5.grammar).
Gedcom.pm parses the grammar which is then used to validate and allow
manipulation of the GEDCOM file.  I have only used Gedcom.pm with versions 5.5
and 5.5.1 of the GEDCOM grammar, which I had to modify slightly to correct a
few errors.  The advantage of this approach is that Gedcom.pm should be useful
if the GEDCOM grammar is ever updated.  It also made the software easier to
write, and probably more dependable too.  I suppose this is the virtue of
laziness shining through.

The vice of laziness is also shining brightly - I need to document how to use
this module in much greater detail.  This is happening - this release has more
documentation than the previous ones - but if you would like information feel
free to send me mail or better still, ask on the mailing list.

This module provides some functions which work over the entire GEDCOM file,
such as reformatting dates, renumbering entries and ordering the entries.  It
also allows access to individuals, and then to relations of individuals, for
example sons, siblings, spouse, parents and so forth.

The distribution includes a lines2perl program to convert LifeLines programs to
Perl.  The program works, but it has a few rough edges, and some missing
functionality.  I'll be working on it when it hits the top of my TODO list.

There is now an option for read only access to the GEDCOM file.  Actually, this
doesn't stop you changing or writing the file, but it does parse the GEDCOM
file lazily, meaning that only those portions of the GEDCOM file which are
needed will be read.  This can provide a substantial saving of time and memory
providing that not too much of the GEDCOM file is read.  If you are going to
read the whole GEDCOM file, this mode is less efficient unless you do some
manual housekeeping.

Should you find this software useful, or if you make changes to it, or if you
would like me to make changes to it, please send me mail.  I would like to have
some sort of an idea of the use this software is getting.  Apart from being of
interest to me, this will guide my decisions when I feel the need to make
changes to the interface.

There is a low volume mailing list available for discussing the use of Perl in
conjunction with genealogical work.  This is an appropriate forum for
discussing Gedcom.pm and if you use or are interested in this module I would
encourage you to join the list.  To subscribe send an empty message to
perl-gedcom-subscribe@perl.org.

To store my genealogy I wrote a syntax file (gedcom.vim) and used vim
(http://www.vim.org) to enter the data, and Gedcom.pm to validate and
manipulate it.  I find this to be a nice solution.

# GETTING STARTED

This space is reserved for something of a tutorial.  If you learn best by
looking at examples, take a look at the test directory, _t_.  The most simple
test is _birthdates.t_.

The first thing to do is to read in the GEDCOM file.  At its most simple, this
will involve a statement such as

    my $ged = Gedcom->new($gedcom_file);

It is now possible to access the records within the GEDCOM file.  Each
individual and family is a record.  Records can contain other records.  For
example, an individual is a record.  The birth information is a sub-record of
the individual, and the date of birth is a sub-record of the birth record.

Some records, such as the birth record, are simply containers for other
records.  Some records have a value, such as the date record, whose value is a
date.  This is all defined in the GEDCOM standard.

To access an individual use a statement such as

    my $i = $ged->get_individual("Paul Johnson");

To access information about the individual, use a function of the same name as
the GEDCOM tag, or its description.  Tags and descriptions are listed at the
head of Gedcom.pm.  For example

    for my $b ($i->birth) {
    }

will loop through all the birth records in the individual.  Usually there will
only be one such record, but there may be zero, one or more.  Calling the
function in scalar context will return only the first record.

    my $b = $i->birth;

But the second record may be returned with

    my $b = $i->birth(2);

If the record required has a value, for example

    my $n = $i->name;

then the value is returned, in this case the name of the individual.  If there
is no value, as is the case for the birth record, then the record itself is
returned.  If there is a value, but the record itself is required, then the
get\_record() function can be used.

Information must be accessed through the GEDCOM structure so, for example, the
birthdate is accessed via the date record from the birth record within an
individual.

    my $d = $b->date;

Be aware that if you access a record in scalar context, but there is no such
record, then undef is returned.  In this case, $d would be undef if $b had no
date record.  This is another reason why looping through records is a nice
solution, all else being equal.

Access to values can also be gained through the get\_value() function.  This is
a preferable solution where it is necessary to work down the GEDCOM structure.
For example

    my $bd = $i->get_value("birth date");
    my $bd = $i->get_value(qw(birth date));

will both return an individual's birth date or undef if there is none.  And

    my @bd = $i->get_value("birth date");

will return all the birth dates.  The second birth date, if there is one, is

    my $bd2 = $i->get_value(["birth", 2], "date");

Using the get\_record() function in place of the get\_value() function, in all
cases will return the record rather than the value.

All records are of a type derived from Gedcom::Item.  Individuals are of type
Gedcom::Individual.  Families are of type Gedcom::Family.  Events are of type
Gedcom::Event.  Other records are of type Gedcom::Record which is the base type
of Gedcom::Individual, Gedcom::Family and Gedcom::Event.

As individuals are of type Gedcom::Individual, the functions in
Gedcom::Individual.pm are available.  These allow access to relations and other
information specific to individuals, for example

    my @sons = $i->sons;

It is possible to get all the individuals in the GEDCOM file as

    my @individuals = $ged->individuals;

So putting everything together, here is a little program which will print out
the names and birthdates of everyone in a GEDCOM file specified on the command
line.

    #!/bin/perl -w

    use strict;
    use Gedcom;

    my $ged = Gedcom->new(shift);

    for my $i ($ged->individuals) {
        for my $bd ($i->get_value("birth date")) {
            print $i->name, " was born on $bd\n";
        }
    }

# HASH MEMBERS

I have not gone the whole hog with data encapsulation and such within this
module.  Maybe I should have done.  Maybe I will.  For now though, the data is
accessible though hash members.  This is partly because having functions to do
this is a little slow, especially on my old DECstation, and partly because of
laziness again.  I'm not too sure whether this is good or bad laziness yet.
Time will tell no doubt.

As of version 1.05, you should be able to access all the data through
functions, and as of version 1.10 write access is available.  I have a faster
machine now.

Some of the more important hash members are:

## $ged->{grammar}

This contains the GEDCOM grammar.

See Gedcom::Grammar.pm for more details.

## $ged->{record}

This contains the top level gedcom record.  A record contains a number of
items.  Each of those items are themselves records.  This is the way in which
the hierarchies are modelled.

If you want to get at the data in the gedcom object, this is where you start.

See Gedcom::Record.pm for more details.

# METHODS

## new

    my $ged = Gedcom->new;

    my $ged = Gedcom->new($gedcom_file);

    my $ged = Gedcom->new(grammar_version => "5.5.1",
                          gedcom_file     => $gedcom_file,
                          read_only       => 1,
                          callback        => $cb);

    my $ged = Gedcom->new(grammar_file => "gedcom-5.5.grammar",
                          gedcom_file  => $gedcom_file);

Create a new gedcom object.

gedcom\_file is the name of the GEDCOM file to parse.  If you do not supply a
gedcom\_file parameter then you will get an empty Gedcom object, empty that is
apart from a few mandatory records.

You may optionally pass grammar\_version as the version number of the GEDCOM
grammar you want to use.  There are two versions available, 5.5 and 5.5.1.  If
you do not specify a grammar version, you may specify a grammar file as
grammar\_file.  Usually, you will do neither of these, and in this case the
grammar version will default to the latest full available version, currently
5.5.  5.5.1 is only a draft, but it is available if you specify it.

The read\_only parameter indicates that the Gedcom data structure will be used
primarily for read\_only operations.  In this mode the GEDCOM file is read
lazily, such that whenever possible the Gedcom records are not read until they
are needed.  This can save on both memory and CPU usage, provided that not too
much of the GEDCOM file is needed.  If the whole of the GEDCOM file needs to be
read, for example to validate it, or to write it out in a different format,
then this option should not be used.

When using the read\_only option an index file is kept which can also speed up
operations.  It's usage should be transparent, but will require write access to
the directory containing the GEDCOM file.  If you access individuals only by
their xref (eg I20) then the index file will allow only the relevant parts of
the GEDCOM file to be read.

With or without the read\_only option, the GEDCOM file is accessed in the same
fashion and the data structures can be changed.  In this respect, the name
read\_only is not particularly accurate, but since changing the Gedcom data will
generally mean that the data will be written which means that the data will
first be read, the read\_only option is generally useful when the data will not
be written and when not all the data will be read.  You may find it useful to
experiment with this option and check the amount of CPU time and memory that
your application uses.  You may also need to read this paragraph a few times to
understand it.  Sorry.

callback is an optional reference to a subroutine which will be called at
various times while the GEDCOM file (and the grammar file, if applicable) is
being read.  Its purpose is to provide feedback during potentially long
operations.  The subroutine is called with five arguments:

    my ($title, $txt1, $txt2, $current, $total) = @_;

    $title is a brief description of the current operation
    $txt1 and $txt2 provide more information on the current operation
    $current is the number of operations performed
    $total is the number of operations that need to be performed

If the subroutine returns false, the operation is aborted.

## set\_encoding

    $ged->set_encoding("utf-8");

Valid arguments are "ansel" and "utf-8".  Defaults to "ansel" but is set to
"utf-8" if the GEDCOM data was read from a file which was deemed to contain
UTF-8, either due to the presence of a BOM or as specified by a CHAR item.

Set the encoding for the GEDCOM file.  Calling this directly doesn't alter the
CHAR item, but does affect the way in which files are written.

## write

    $ged->write($new_gedcom_file, $flush);

Write out the GEDCOM file.

Takes the name of the new GEDCOM file, and whether or not to indent the output
according to the level of the record.  $flush defaults to false, but the new
file name must be specified.

## write\_xml

    $ged->write_xml($new_xml_file);

Write the GEDCOM file as XML.

Takes the name of the new GEDCOM file.

Note that this function is experimental.  The XML output doesn't conform to any
standard; it's just me trying to turn the GEDCOM format into sensible XML.

## collect\_xrefs

    $ged->collect_xrefs($callback);

Collect all the xrefs into a data structure ($ged->{xrefs}) for easy location.
$callback is not used yet.

Called by new().

## resolve\_xref

    my $xref = $self->resolve_xref($value);

Return the record $value points to, or undef.

## resolve\_xrefs

    $ged->resolve_xrefs($callback);

Changes all xrefs to reference the record they are pointing to.  Like changing
a soft link to a hard link on a Unix filesystem.  $callback is not used yet.

## unresolve\_xrefs

    $ged->unresolve_xrefs($callback);

Changes all xrefs to name the record they contained.  Like changing a hard link
to a soft link on a Unix filesystem.  $callback is not used yet.

## validate

    return unless $ged->validate($callback);

Validate the Gedcom object.  This performs a number of consistency checks, but
could do even more.  $callback is not properly used yet.

Any errors found are given out as warnings.  If this is unwanted, use
$SIG{\_\_WARN\_\_} to catch the warnings.

Returns true iff the Gedcom object is valid.

## normalise\_dates

    $ged->normalise_dates;
    $ged->normalise_dates("%A, %E %B %Y");

Change all recognised dates into a consistent format.  This routine uses
Date::Manip to do the work, so you can look at its documentation regarding
formats that are recognised and % sequences for the output.

Optionally takes a format to use for the output.  The default is currently
"%A, %E %B %Y", but I may change this, as it seems that some programs don't
like that format.

## renumber

    $ged->renumber;
    my %xrefs = $ged->renumber(INDI => 34, FAM => 12, xrefs => [$xref1, $xref2]);

Renumber all the records.

Optional parameters are:

    tag name => last used number (defaults to 0)
    xrefs    => list of xrefs to renumber first

As a record is renumbered, it is assigned the next available number.  The
husband, wife, children, parents and siblings are then renumbered in that
order.  This helps to ensure that families are numerically close together.

The hash returned is the updated hash that was passed in.

## sort\_sub

    $ged->order($ged->sort_sub);

Default ordering subroutine.

The sort is by record type in the following order: HEAD, SUBM, INDI, FAM, NOTE,
TRLR, and then by xref within the type.

## order

    $ged->order;
    $ged->order($order_sub);

Order all the records.  Optionally provide a sort subroutine.

This orders the entries within the Gedcom object, which will affect the order
in which they are written out.  The default sort function is Gedcom::sort\_sub.
You will need to ensure that the HEAD record is first and that the TRLR record
is last.

## individuals

    my @individuals = $ged->individuals;

Return a list of all the individuals.

## families

    my @families = $ged->families;

Return a list of all the families.

## get\_individual

    my $me = $ged->get_individual("Paul Johnson");

Return a list of all individuals matching the specified name.

There are thirteen matches performed, in decreasing order of exactitude.  This
means that the more likely matches are at the head of the list.

In scalar context return the first match found.

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

## next\_xref

    my $xref = $ged->next_xref("I");

Return the next available xref with the specified prefix.

## add\_record

       add_header
       add_submitter
       add_individual
       add_family
       add_note
       add_repository
       add_source
       add_trailer

Create and return a new record of the specified type.

Normally you will not want to pass any arguments to the function.  Those
functions which have an xref (ie not header or trailer) accept an optional
first argument { xref => $x } which will use $x as the xref rather than letting
the module automatically choose the xref.

add\_note also accepts an optional second argument which is the text to be used
on the first line of the note.

## get\_record

       get_header
       get_submitter
       get_family
       get_note
       get_repository
       get_source
       get_trailer

Return all records of the specified type.  In scalar context just return the
first record.  If a parameter is passed in, just return records of that xref.

# LICENCE

Copyright 1998-2019, Paul Johnson (paul@pjcj.net)

This software is free.  It is licensed under the same terms as Perl itself.

The latest version of this software should be available from my homepage:
http://www.pjcj.net
