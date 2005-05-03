# Copyright 1998-2005, Paul Johnson (pjcj@cpan.org)

# This software is free.  It is licensed under the same terms as Perl itself.

# The latest version of this software should be available from my homepage:
# http://www.pjcj.net

# documentation at __END__

use strict;

require 5.005;

package Gedcom::Record;

use vars qw($VERSION @ISA $AUTOLOAD);
$VERSION = "1.15";
@ISA     = qw( Gedcom::Item );

use Carp;
BEGIN { eval "use Date::Manip" }             # We'll use this if it is available

use Gedcom::Item       1.15;
use Gedcom::Comparison 1.15;

BEGIN
{
  use subs keys %Gedcom::Funcs;
  *tag_record    = \&Gedcom::Item::get_item;
  *delete_record = \&Gedcom::Item::delete_item;
  *get_record    = \&record;
}

sub DESTROY {}

sub AUTOLOAD
{
  my ($self) = @_;                         # don't change @_ because of the goto
  my $func = $AUTOLOAD;
  # print "autoloading $func\n";
  $func =~ s/^.*:://;
  carp "Undefined subroutine $func called" unless $Gedcom::Funcs{lc $func};
  no strict "refs";
  *$func = sub
  {
    my $self = shift;
    my ($count) = @_;
    my $v;
    # print "[[ $func ]]\n";
    if (wantarray)
    {
      return map
        { $_ && do { $v = $_->full_value; defined $v && length $v ? $v : $_ } }
        $self->record([$func, $count]);
    }
    else
    {
      my $r = $self->record([$func, $count]);
      return $r && do { $v = $r->full_value; defined $v && length $v ? $v : $r }
    }
  };
  goto &$func
}

sub record
{
  my $self = shift;
  my @records = ($self);
  for my $func (map { ref() ? $_ : split } @_)
  {
    my $count = 0;
    ($func, $count) = @$func if ref $func eq "ARRAY";
    if (ref $func)
    {
      warn "Invalid record of type ", ref $func, " requested";
      return undef;
    }
    my $record = $Gedcom::Funcs{lc $func};
    unless ($record)
    {
      warn $func
      ? "Non standard record of type $func requested"
      : "Record type not specified";
      $record = $func;
    }

    @records = map { $_->tag_record($record, $count) } @records;

    # fams and famc need to be resolved
    @records = map { $self->resolve($_->{value}) } @records
      if $record eq "FAMS" || $record eq "FAMC";
  }
  wantarray ? @records : $records[0]
}

sub get_value
{
  my $self = shift;
  if (wantarray)
  {
    return map { my $v = $_->full_value; defined $v and length $v ? $v : () }
               $self->record(@_);
  }
  else
  {
    my $record = $self->record(@_);
    return $record && $record->full_value;
  }
}

sub tag_value
{
  my $self = shift;
  if (wantarray)
  {
    return map { my $v = $_->full_value; defined $v and length $v ? $v : () }
               $self->tag_record(@_);
  }
  else
  {
    my $record = $self->tag_record(@_);
    return $record && $record->full_value;
  }
}

sub add_record
{
  my $self = shift;
  my (%args) = @_;

  die "No tag specified" unless defined $args{tag};

  my $record = Gedcom::Record->new
  (
    gedcom   => $self->{gedcom},
    callback => $self->{callback},
    %args
  );

  if (!defined $self->{grammar})
  {
    warn "$self->{tag} has no grammar\n";
  }
  elsif (my @g = $self->{grammar}->item($args{tag}))
  {
    $self->parse($record, $g[0]);
  }
  else
  {
    warn "$args{tag} is not a sub-item of $self->{tag}\n";
  }

  push @{$self->{items}}, $record;

  $record
}

sub add
{
  my $self = shift;
  my $val;
  $val = pop if @_ > 1 && ref $_[-1] ne "ARRAY";

  my @funcs = map { ref() ? $_ : split } @_;
  $funcs[-1] = [$funcs[-1], 0] unless ref $funcs[-1];
  my $r = $self->get_and_create(@funcs);

  if (defined $val)
  {
    if (UNIVERSAL::isa($val, "Gedcom::Record"))
    {
      $r->{value} = $val->{xref};
      $self->{gedcom}{xrefs}{$val->{xref}} = $val;
    }
    else
    {
      $r->{value} = $val;
    }
  }

  $r
}

sub set
{
  my $self = shift;
  my $val = pop;

  my @funcs = map { ref() ? $_ : split } @_;
  my $r = $self->get_and_create(@funcs);

  if (UNIVERSAL::isa($val, "Gedcom::Record"))
  {
    $r->{value} = $val->{xref};
    $self->{gedcom}{xrefs}{$val->{xref}} = $val;
  }
  else
  {
    $r->{value} = $val;
  }

  $r
}

sub get_and_create
{
  my $self = shift;
  my @funcs = @_;

  my $rec = $self;
  for my $f (0 .. $#funcs)
  {
    my ($func, $count) = ($funcs[$f], 1);
    ($func, $count) = @$func if ref $func eq "ARRAY";
    $count--;

    if (ref $func)
    {
      warn "Invalid record of type ", ref $func, " requested";
      return undef;
    }

    my $record = $Gedcom::Funcs{lc $func};
    unless ($record)
    {
      warn $func
      ? "Non standard record of type $func requested"
      : "Record type not specified";
      $record = $func;
    }

    # print "$func [$count]\n";

    my @records = $rec->tag_record($record);

    if ($count < 0)
    {
      $rec = $rec->add_record(tag => $record);
    }
    elsif ($#records < $count)
    {
      my $new;
      $new = $rec->add_record(tag => $record) for (0 .. @records - $count);
      $rec = $new;
    }
    else
    {
      $rec = $records[$count];
    }
  }

  $rec
}

sub parse
{
  # print "parsing\n";
  my $self = shift;
  my ($record, $grammar, $test) = @_;
  $test ||= 0;

  # print "checking "; $record->print();
  # print "against ";  $grammar->print();
  # print "test is $test\n";

  my $t = $record->{tag};
  my $g = $grammar->{tag};
  die "Can't match $t with $g" if $t && $t ne $g;               # internal error

  $record->{grammar} = $grammar;
  my $class = $record->{gedcom}{types}{$t};
  bless $record, "Gedcom::$class" if $class;

  my $match = 1;

  for my $r (@{$record->{items}})
  {
    my $tag = $r->{tag};
    my @i;
    # print "- valid sub-items of $t are @{[keys %{$grammar->valid_items}]}\n";
    for my $i ($grammar->item($tag))
    {
      # Try to get rid of matches we don't want because they only match
      # in name.

      # Check that the level is appropriate.
      # print " - ", $i->level, "|", $r->level, "\n";
      next unless $i->level =~ /^[+0]/ || $i->level == $r->level;

      # Check we have a pointer iff we need one.
      # print " + ", $i->value, "|", $r->value, "|", $r->pointer, "\n";
      # next if $i->value && $r->value && ($i->value =~ /^<XREF:/ ^ $r->pointer);
      next if $i->value && ($i->value =~ /^<XREF:/ ^ ($r->pointer || 0));

      # print "pushing\n";
      push @i, $i;
    }

    # print "valid sub-items of $t are @{[keys %{$grammar->valid_items}]}\n";
    # print "<$tag> => <@i>\n";

    unless (@i)
    {
      # unless $tag eq "CONT" || $tag eq "CONC" || substr($tag, 0, 1) eq "_";
      # TODO - should CONT and CONC be allowed anywhere?
      unless (substr($tag, 0, 1) eq "_")
      {
        warn "$self->{file}:$r->{line}: $tag is not a sub-item of $t\n",
             "Valid sub-items are ",
             join(", ", sort keys %{$grammar->{_valid_items}}), "\n"
          unless $test;
        $match = 0;
        next;
      }
    }

    # print "$self->{file}:$r->{line}: Ambiguous tag $tag as sub-item of $t, ",
          # "found ", scalar @i, " matches\n" if @i > 1;
    my $m = 0;
    for my $i (@i)
    {
      last if $m = $self->parse($r, $i, @i > 1);
    }

    if (@i > 1 && !$m)
    {
      # TODO - I'm not even sure if this can happen.
      warn "$self->{file}:$r->{line}: Ambiguous tag $tag as sub-item of $t, ",
           "found ", scalar @i, " matches, all of which have errors.  ",
           "Reporting errors from last match.\n";
      $self->parse($r, $i[-1]);
      $match = 0;
      # TODO - count the errors in each match and use the best.
    }
  }
  # print "parsed $match\n";

  $match
}

sub collect_xrefs
{
  my $self = shift;
  my ($callback) = @_;
  $self->{gedcom}{xrefs}{$self->{xref}} = $self if defined $self->{xref};
  $_->collect_xrefs($callback) for @{$self->{items}};
  $self
}

sub resolve_xref
{
  shift->{gedcom}->resolve_xref(@_);
}

sub resolve
{
  my $self = shift;
  my @x = map
  {
    ref($_)
    ? $_
    : do { my $x = $self->{gedcom}->resolve_xref($_); defined $x ? $x : () }
  } @_;
  wantarray ? @x : $x[0];
}

sub resolve_xrefs
{
  my $self = shift;;
  my ($callback) = @_;
  if (my $xref = $self->{gedcom}->resolve_xref($self->{value}))
  {
    $self->{value} = $xref;
  }
  $_->resolve_xrefs($callback) for @{$self->_items};
  $self
}

sub unresolve_xrefs
{
  my $self = shift;;
  my ($callback) = @_;
  $self->{value} = $self->{value}{xref}
    if defined $self->{value}
       and UNIVERSAL::isa $self->{value}, "Gedcom::Record"
       and exists $self->{value}{xref};
  $_->unresolve_xrefs($callback) for @{$self->_items};
  $self
}

my $D =  0;                                               # turn on debug output
my $I = -1;                                            # indent for debug output

sub validate_syntax
{
  my $self = shift;
  return 1 unless exists $self->{grammar};
  my $ok = 1;
  $self->{gedcom}{validate_callback}->($self)
    if defined $self->{gedcom}{validate_callback};
  my $grammar = $self->{grammar};
  $I++;
  print "  " x $I . "validate_syntax(" .
        (defined $grammar->{tag} ? $grammar->{tag} : "") . ")\n" if $D;
  my $file = $self->{gedcom}{record}{file};
  my $here = "$file:$self->{line}: $self->{tag}" .
             (defined $self->{xref} ? " $self->{xref}" : "");
  my %counts;
  for my $record (@{$self->_items})
  {
    print "  " x $I . "level $record->{level} on $self->{level}\n" if $D;
    $ok = 0, warn "$here: Can't add level $record->{level} to $self->{level}\n"
      if $record->{level} > $self->{level} + 1;
    $counts{$record->{tag}}++;
    $ok = 0 unless $record->validate_syntax;
  }
  my $valid_items = $grammar->valid_items;
  for my $tag (sort keys %$valid_items)
  {
    for my $g (@{$valid_items->{$tag}})
    {
      my $min = $g->{min};
      my $max = $g->{max};
      my $matches = delete $counts{$tag} || 0;
      my $msg = "$here has $matches $tag" . ($matches == 1 ? "" : "s");
      print "  " x $I . "$msg - min is $min max is $max\n" if $D;
      $ok = 0, warn "$msg - minimum is $min\n" if $matches < $min;
      $ok = 0, warn "$msg - maximum is $max\n" if $matches > $max && $max;
    }
  }
  for my $tag (keys %counts)
  {
    for my $c ($self->tag_record($tag))
    {
      $ok = 0, warn "$file:$c->{line}: $tag is not a sub-item of $self->{tag}\n"
        unless substr($tag, 0, 1) eq "_";
        # unless $tag eq "CONT" || $tag eq "CONC" || substr($tag, 0, 1) eq "_";
        # TODO - should CONT and CONC be allowed anywhere?
    }
  }
  $I--;
  $ok;
}

my $Check =
{
  INDI =>
  {
    FAMS => [ "HUSB", "WIFE" ],
    FAMC => [ "CHIL" ]
  },
  FAM =>
  {
    HUSB => [ "FAMS" ],
    WIFE => [ "FAMS" ],
    CHIL => [ "FAMC" ],
  },
};

sub validate_semantics
{
  my $self = shift;
  return 1 unless $self->{tag} eq "INDI" || $self->{tag} eq "FAM";
  # print "validating: "; $self->print; print $self->summary, "\n";
  my $ok = 1;
  my $xrefs = $self->{gedcom}{xrefs};
  my $chk = $Check->{$self->{tag}};
  for my $f (keys %$chk)
  {
    my $found = 1;
    RECORD:
    for my $record ($self->tag_value($f))
    {
      $found = 0;
      $record = $xrefs->{$record} unless ref $record;
      if ($record)
      {
        for my $back (@{$chk->{$f}})
        {
          # print "back $back\n";
          for my $i ($record->tag_value($back))
          {
            # print "record is $i\n";
            $i = $xrefs->{$i} unless ref $i;
            if ($i && $i->{xref} eq $self->{xref})
            {
              $found = 1;
              # print "found...\n";
              next RECORD;
            }
          }
        }
        unless ($found)
        {
          # TODO - use the line of the offending record
          $ok = 0;
          my $file = $self->{gedcom}{record}{file};
          warn "$file:$self->{line}: $f $record->{xref} " .
               "does not reference $self->{tag} $self->{xref}. Add the line:\n".
               "$file:" . ($record->{line} + 1) . ": 1   " .
               join("or ", @{$chk->{$f}}) .  " $self->{xref}\n";
        }
      }
    }
  }
  $ok;
}

sub normalise_dates
{
  my $self = shift;
  unless ($INC{"Date/Manip.pm"})
  {
    warn "Date::Manip.pm is required to use normalise_dates()";
    return;
  }
  my $format = shift || "%A, %E %B %Y";
  if (defined $self->{tag} && $self->{tag} =~ /^date$/i)
  {
    if (defined $self->{value} && $self->{value})
    {
      # print "date was $self->{value}\n";
      my @dates = split / or /, $self->{value};
      for my $dt (@dates)
      {
        # don't change the date if it is just < 7 digits
        if ($dt !~ /^\s*(\d+)\s*$/ || length $1 > 6)
        {
          my $date = ParseDate($dt);
          my $d = UnixDate($date, $format);
          $dt = $d if $d;
        }
      }
      $self->{value} = join " or ", @dates;
      # print "date is  $self->{value}\n";
    }
  }
  $_->normalise_dates($format) for @{$self->_items};
  $self->delete_items if $self->level > 1;
}

sub renumber
{
  my $self = shift;
  my ($args, $recurse) = @_;
  # TODO - add the xref if there is supposed to be one
  return if exists $self->{recursed} or not defined $self->{xref};
  # we can't actaully change the xrefs until the end
  my $x = $self->{tag} eq "SUBM" ? "SUBM" : substr $self->{tag}, 0, 1;
  $self->{new_xref} = $x . ++$args->{$self->{tag}}
    unless exists $self->{new_xref};
  return unless $recurse and not exists $self->{recursed};
  $self->{recursed} = 1;
  if ($self->{tag} eq "INDI")
  {
    my @r = map { $self->$_() } qw(fams famc spouse children parents siblings);
    $_->renumber($args, 0) for @r;
    $_->renumber($args, 1) for @r;
  }
}

sub child_value
{
  # NOTE - This function is deprecated - use tag_value instead
  my $self = shift;;
  $self->tag_value(@_)
}

sub child_values
{
  # NOTE - This function is deprecated - use tag_value instead
  my $self = shift;;
  $self->tag_value(@_)
}

sub compare
{
    my $self = shift;
    my ($r) = @_;
    Gedcom::Comparison->new($self, $r)
}

sub summary
{
  my $self = shift;
  my $s = "";
  $s .= sprintf("%-5s", $self->{xref});
  my $r = $self->tag_record("NAME");
  $s .= sprintf(" %-40s", $r ? $r->{value} : "");
  $r = $self->tag_record("SEX");
  $s .= sprintf(" %1s", $r ? $r->{value} : "");
  my $d = "";
  if ($r = $self->tag_record("BIRT") and my $date = $r->tag_record("DATE"))
  {
    $d = $date->{value};
  }
  $s .= sprintf(" %16s", $d);
  $s;
}

1;

__END__

=head1 NAME

Gedcom::Record - a module to manipulate Gedcom records

Version 1.15 - 3rd May 2005

=head1 SYNOPSIS

  use Gedcom::Record;

  my $record  = tag_record("CHIL", 2);
  my @records = tag_record("CHIL");
  my @recs = $record->record("birth");
  my @recs = $record->record("birth", "date");
  my $rec  = $record->record("birth date");
  my $rec  = $record->record(["birth", 2], "date");
  my @recs = $record->get_record("birth");
  my $val  = $record->get_value;
  my @vals = $record->get_value("date");
  my @vals = $record->get_value("birth", "date");
  my $val  = $record->get_value("birth date");
  my $val  = $record->get_value(["birth", 2], "date");
  my $rec  = $record->add("birth date", "1 Jan 2000");
  my $rec  = $record->set("birth date", "2 Jan 2000");
  $self->parse($record, $grammar);
  $record->collect_xrefs($callback);
  my $xref = $record->resolve_xref($record->{value});
  my @famc = $record->resolve $record->get_value("FAMC");
  $record->resolve_xrefs($callback);
  $record->unresolve_xrefs($callback);
  return 0 unless $record->validate_semantics;
  $record->normalise_dates($format);
  $record->renumber($args);
  print $record->summary, "\n";
  $record->delete_record($sub_record);

=head1 DESCRIPTION

A selection of subroutines to handle records in a gedcom file.

Derived from Gedcom::Item.

=head1 HASH MEMBERS

Some of the more important hash members are:

=head2 $record->{new_xref}

Used by renumber().

=head2 $record->{recursed}

Used by renumber().

=head1 METHODS

=head2 tag_record

  my $record  = tag_record("CHIL", 2);
  my @records = tag_record("CHIL");

Get specific sub-records from the record.  This function is identical to
Gedcom::Item::get_item().

The arguments are the name of the tag, and optionally the count.

In scalar context, returns the sub-record, or undef if it doesn't exist.
In array context, returns all sub-records matching the specified tag.

=head2 record

  my @recs = $record->record("birth");
  my @recs = $record->record("birth", "date");
  my $rec  = $record->record("birth date");
  my $rec  = $record->record(["birth", 2], "date");
  my @recs = $record->get_record("birth");

Retrieve a record.

The get_record() function is identical to the record() function.

In scalar context, record() returns the specified record, or undef if
there is none.  In list context, record() returns all the specified
records.

Records may be specified by a list of strings.  Each string is either a
Gedcom tag or a description.  Starting from the first string in the
list, specified records are retrieved.  Then from those records, records
specified by the next string in the list are retrieved.  This continues
until all strings from the list have been used.

In list context, all specified records are retrieved.  In scalar
context, only the first record is retrieved.  If a record other than the
first is wanted, then instead of passing a string, a reference to an
array containing the string and a count may be passed.

Instead of specifying a list of strings, it is possible to specify a
single space separated string.  This can make the interface nicer.

=head2 get_value

  my $val  = $record->get_value;
  my @vals = $record->get_value("date");
  my @vals = $record->get_value("birth", "date");
  my $val  = $record->get_value("birth date");
  my $val  = $record->get_value(["birth", 2], "date");

Retrieve a record's value.

If arguments are specified, record() is first called with those
arguments, and the values of those records are returned.

=head2 add

  my $rec  = $record->add("birth date", "1 Jan 2000");

Add a new record.

Add a new record ($rec) as a sub-item of $record.  Set its value to the
last argument given.  The first arguments may be specified as for
record().  A new record will always be created for the last argument,
and for any arguments for which the count is explicitly set to zero.

If the new record does not take a value then do not supply one.  This
does mean that you cannot use the function with many arguments if the
last one is a scalar, but not a value.  In this case either specify the
last argument as ["arg", 0], or add undef as the last argument.

=head2 set

  my $rec  = $record->set("birth date", "2 Jan 2000");

Set the value of a record.

This is the same as add(), with the exception that a new record is not
created for the last argument.

=head2 parse

  $self->parse($record, $grammar);

Parse a Gedcom record.

Match a Gedcom::Record against a Gedcom::Grammar.  Warn of any
mismatches, and associate the Gedcom::Grammar with the Gedcom::Record as
$record->{grammar}.  Do this recursively.

=head2 collect_xrefs

  $record->collect_xrefs($callback);

Recursively collect all the xrefs.  Called by Gedcom::collect_xrefs.
$callback is not used yet.

=head2 resolve_xref

  my $xref = $record->resolve_xref($value);

See Gedcom::resolve_xrefs()

=head2 resolve

  my @famc = $record->resolve $record->tag_value("FAMC");

For each argument, either return it or, if it an xref, return the
referenced record.

=head2 resolve_xrefs

  $record->resolve_xrefs($callback);

See Gedcom::resolve_xrefs()

=head2 unresolve_xrefs

  $record->unresolve_xrefs($callback);

See Gedcom::unresolve_xrefs()

=head2 validate_semantics

  return 0 unless $record->validate_semantics;

Validate the semantics of the Gedcom::Record.  This performs a number of
consistency checks, but could do even more.

Returns true iff the Record is valid.

=head2 normalise_dates

  $record->normalise_dates($format);

Change the format of all dates in the record.

See the documentation for Gedcom::normalise_dates

=head2 renumber

  $record->renumber($args);

Renumber the record.

See Gedcom::renumber().

=head2 child_value

NOTE - This function is deprecated - use tag_value instead.

  my $child = $record->child_value("NAME");

=head2 child_values

NOTE - This function is deprecated - use tag_value instead.

  my @children = $record->child_values("CHIL");

=head2 summary

  print $record->summary, "\n";

Return a line of text summarising the record.

=head2 delete_record

  $record->delete_record($sub_record);

Delete the specified sub-record from the record.

=head2 Access functions

All the Gedcom tag names can be used as function names.  Depending on
the context in which they are called, the functions return either an
array of the specified sub-items, or the first specified sub-item.

The descriptions of the tags, with spaces replaced by underscores, can
also be used as function names.  The function names can be of either, or
mixed case.  Unless you use the tag name, in either case, or the
description in lower case, the function will not be pre-declared and you
will need to qualify it or C<use subs>.

=cut

=begin if we cannot make the min/max assumptions specified in
       Gedcom::Grammar::valid_items

use as:
  my @items = @{$ged->{record}{items}};
  my ($m, $w) =
   $ged->{record}->validate_structure($ged->{record}{grammar}, \@items, 1);
  warn $w if $w;

sub validate_grammar
{
  my $self = shift;
  my ($grammar, $items, $all) = @_;
  $I++;
  my $min = $grammar->min;
  my $max = $grammar->max;
  $all++ unless $max;
  my $matches = 0;
  my $warn = "";
  my $value = $grammar->{tag};
  print "  " x $I, " looking for ", $all == 1 ? "all" : $max if $D;
  if ($value)
  {
    print " $value, $min -> $max\n" if $D;
    for (my $c = 0;
         $c <= $#$items && ($all == 1 || !$max || $matches < $max);)
    {
      if ($items->[$c]{tag} eq $value)
      {
        my $w = $items->[$c]->validate_syntax2;
        $warn .= $w;
        splice @$items, $c, 1;
        $matches++;
      }
      else
      {
        $c++;
      }
    }
  }
  else
  {
    # TODO - require Data::Dumper
    die "What's a " . Data::Dumper->new([$grammar], ["grammar"])
      unless ($value) = $grammar->{value} =~ /<<(.*)>>/;
    die "Can't find $value in gedcom structures"
      unless my $s = $grammar->structure($value);
    $grammar->{structure} = $s;
    print " $value, $min -> $max\n" if $D;
    my ($m, $w);
    do
    {
      ($m, $w) = $self->validate_structure($s, $items, $all);
      if ($m)
      {
        $matches += $m;
        $warn .= $w;
      }
    } while $m && ($all == 1 || !$max || $matches < $max);
  }
  $I--;
  ($matches, $warn)
}

sub validate_structure
{
  my $self = shift;
  my ($structure, $items, $all) = @_;
  $all = 0 unless defined $all;
  $I++;
  print "  " x $I . "validate_structure($structure->{structure}, $all)\n" if $D;
  my $warn = "";
  my $total_matches = 0;
  for my $item (@{$structure->{items}})
  {
    my $min = $item->min;
    my $max = $item->max;
    my ($matches, $w) = $self->validate_grammar($item, $items, $all);
    $warn .= $w;
    my $file = $self->{gedcom}{record}{file};
    my $value = $item->{tag} || $item->{structure}{structure};
    my $msg = "$file:$self->{line}: $self->{tag}" .
              (defined $self->{xref} ? " $self->{xref} " : "") .
              " has $matches $value" . ($matches == 1 ? "" : "s");
    print "  " x $I . "$msg - minimum is $min maximum is $max\n" if $D;
    if ($structure->{selection})
    {
      if ($matches)
      {
        $warn .= "$msg - minimum is $min\n" if $matches < $min;
        $warn .= "$msg - maximum is $max\n" if $matches > $max && $max;
        $total_matches += $matches;                   # only one item is allowed
        last;
      }
    }
    else
    {
      $warn .= "$msg - minimum is $min\n" if $matches < $min;
      $warn .= "$msg - maximum is $max\n" if $matches > $max && $max;
      $total_matches = 1 if $matches;                   # all items are required
    }
  }
  print "  " x $I . "returning $total_matches matches\n" if $D;
  $I--;
  ($total_matches, $warn)
}

sub validate_syntax2
{
  my $self = shift;
  $self->{gedcom}{validate_callback}->($self)
    if defined $self->{gedcom}{validate_callback};
  my $items = [ @{$self->{items}} ];
  $I++;
  my $grammar = $self->{grammar};
  print "  " x $I . "validate_syntax2($grammar->{tag})\n" if $D;
  my $warn = "";
  my $file = $self->{gedcom}{record}{file};
  my $here = "$file:$self->{line}: $self->{tag}" .
             (defined $self->{xref} ? " $self->{xref}" : "");
  for my $item (@$items)
  {
    print "  " x $I . "level $item->{level} on $self->{level}\n" if $D;
    $warn .= "$here: Can't add level $item->{level} to $self->{level}\n"
      if $item->{level} > $self->{level} + 1;
  }
  for my $item (@{$grammar->{items}})
  {
    my $min = $item->min;
    my $max = $item->max;
    my ($matches, $w) = $self->validate_grammar($item, $items, 1);
    $warn .= $w;
    my $value = $item->{tag} || $item->{structure}{structure};
    my $msg = "$here has $matches $value" . ($matches == 1 ? "" : "s");
    print "  " x $I . "$msg - minimum is $min maximum is $max\n" if $D;
    $warn .= "$msg - minimum is $min\n" if $matches < $min;
    $warn .= "$msg - maximum is $max\n" if $matches > $max && $max;
  }
  if (@$items)
  {
    my %tags = map { $_ => 1 } $grammar->items;
    for my $c (@$items)
    {
      my $tag = $c->{tag};
      my $msg = exists $tags{$tag} ? "an extra" : "not a";
      $warn .= "$file:$c->{line}: $tag is $msg item of $self->{tag}\n"
        unless $tag eq "CONT" || $tag eq "CONC" || substr($tag, 0, 1) eq "_";
    }
  }
  $I--;
  $warn
}
=end
