# Copyright 1998-1999, Paul Johnson (pjcj@transeda.com)

# This software is free.  It is licensed under the same terms as Perl itself.

# The latest version of this software should be available from my homepage:
# http://www.transeda.com/pjcj

# documentation at __END__

use strict;

require 5.005;

package Gedcom::Record;

use Carp;
BEGIN { eval "use Date::Manip" }             # We'll use this if it is available

use Gedcom::Item 1.05;

use vars qw($VERSION @ISA $AUTOLOAD);
$VERSION = "1.05";
@ISA     = qw( Gedcom::Item );

my %Funcs;
BEGIN
{
  while (my($tag, $name) = each(%$Gedcom::Tags))
  {
    # print "looking at tag $tag <$name>\n";
    $Funcs{$tag} = $Funcs{lc $tag} = $tag;
    if ($name)
    {
      $name =~ s/ /_/g;
      $name = lc $name;
      $Funcs{lc $name} = $tag;
    }
  }
  # use Data::Dumper;
  # print "Funcs are ", Dumper(\%Funcs);
  use subs keys %Funcs;
}

sub AUTOLOAD
{
  my $self = shift;
  return if $AUTOLOAD =~ /::DESTROY$/;
  my $func = $AUTOLOAD;
  # print "autoloading $func\n";
  $func =~ s/^.*:://;
  my $child = $Funcs{lc $func};
  croak "Undefined subroutine $func called" unless $child;
  if (wantarray)
  {
    my @c = $self->get_children($child);
    return map { $_ && $_->{value} ? $_->{value} : $_ } @c;
  }
  else
  {
    my $c = $self->get_child($child);
    return $c && $c->{value} ? $c->{value} : $c;
  }
}

sub parse
{
  my $self = shift;
  my ($record, $grammar) = @_;
  # print "checking "; $self->print();
  # print "against ";  $grammar->print();
  my $t = $record->{tag};
  my $g = $grammar->{tag};
  die "Can't match $t with $g" if $t && $t ne $g;               # internal error
  $record->{grammar} = $grammar;
  my $class = $record->{gedcom}{types}{$t};
# print "$t is a $class\n" if $class;
  bless $record, "Gedcom::$class" if $class;
  for my $child (@{$record->{children}})
  {
    my $tag = $child->{tag};
    if (my $gc = $grammar->child($tag))
    {
      $self->parse($child, $gc);
    }
    else
    {
      warn "$self->{file}:$child->{line}: $tag is not a child of $t\n"
        unless substr($tag, 0, 1) eq "_";
        # unless $tag eq "CONT" || $tag eq "CONC" || substr($tag, 0, 1) eq "_";
        # TODO - should CONT and CONC be allowed anywhere?
    }
  }
}

sub collect_xrefs
{
  my $self = shift;
  my ($callback) = @_;;
  $self->{gedcom}{xrefs}{$self->{xref}} = $self if defined $self->{xref};
  $_->collect_xrefs($callback) for @{$self->{children}};
  $self
}

sub resolve_xref
{
  shift->{gedcom}->resolve_xref(@_);
}

sub resolve
{
  my $self = shift;
  my @x = map { ref($_) ? $_ : $self->resolve_xref($_) } @_;
  wantarray ? @x : $x[0];
}

sub resolve_xrefs
{
  my $self = shift;;
  my ($callback) = @_;
  if (my $xref = $self->resolve_xref($self->{value}))
  {
    $self->{value} = $xref;
  }
  $_->resolve_xrefs($callback) for @{$self->{children}};
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
  $_->unresolve_xrefs($callback) for @{$self->{children}};
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
  print "  " x $I . "validate_syntax($grammar->{tag})\n" if $D;
  my $file = $self->{gedcom}{record}{file};
  my $here = "$file:$self->{line}: $self->{tag}" .
             (defined $self->{xref} ? " $self->{xref}" : "");
  my %counts;
  for my $child (@{$self->{children}})
  {
    print "  " x $I . "level $child->{level} on $self->{level}\n" if $D;
    $ok = 0, warn "$here: Can't add level $child->{level} to $self->{level}\n"
      if $child->{level} > $self->{level} + 1;
    $counts{$child->{tag}}++;
    $ok = 0 unless $child->validate_syntax;
  }
  my $valid_children = $grammar->valid_children;
  for my $tag (sort keys %$valid_children)
  {
    my $g = $valid_children->{$tag};
    my $min = $g->{min};
    my $max = $g->{max};
    my $matches = delete $counts{$tag} || 0;
    my $msg = "$here has $matches $tag" . ($matches == 1 ? "" : "s");
    print "  " x $I . "$msg - min is $min max is $max\n" if $D;
    $ok = 0, warn "$msg - minimum is $min\n" if $matches < $min;
    $ok = 0, warn "$msg - maximum is $max\n" if $matches > $max && $max;
  }
  for my $tag (keys %counts)
  {
    for my $c ($self->get_children($tag))
    {
      $ok = 0, warn "$file:$c->{line}: $tag is not a child of $self->{tag}\n"
        unless substr($tag, 0, 1) eq "_";
        # unless $tag eq "CONT" || $tag eq "CONC" || substr($tag, 0, 1) eq "_";
        # TODO - should CONT and CONC be allowed anywhere?
    }
  }
  $I--;
  $ok;
}

sub validate_semantics
{
  my $self = shift;
  return 1 unless $self->{tag} eq "INDI" || $self->{tag} eq "FAM";
  # print "validating: "; $self->print; print $self->summary, "\n";
  my $ok = 1;
  my $file = $self->{gedcom}{record}{file};
  my $xrefs = $self->{gedcom}{xrefs};
  my $found;
  my $child;
  my $check =
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
  my $chk = $check->{$self->{tag}};
  for my $f (keys %$chk)
  {
    $found = 1;
    CHILD:
    for $child ($self->child_values($f))
    {
      $found = 0;
      $child = $xrefs->{$child} unless ref $child;
      if ($child)
      {
        for my $back (@{$chk->{$f}})
        {
          # print "back $back\n";
          for my $ch ($child->child_values($back))
          {
            # print "child is $ch\n";
            $ch = $xrefs->{$ch} unless ref $ch;
            if ($ch)
            {
              if ($ch->{xref} eq $self->{xref})
              {
                $found = 1;
                # print "found...\n";
                next CHILD;
              }
            }
          }
        }
        unless ($found)
        {
          # TODO - use the line of the offending child
          $ok = 0;
          warn "$file:$self->{line}: $f $child->{xref} " .
               "does not reference $self->{tag} $self->{xref}. Add the line:\n".
               "$file:" . ($child->{line} + 1) . ": 1   " .
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
    warn "Date::Manip is required to use normalise_dates()";
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
  $_->normalise_dates($format) for @{$self->{children}};
}

sub renumber
{
  my $self = shift;
  my ($args, $recurse) = @_;
  # TODO - add the xref if there is supposed to be one
  return if exists $self->{recursed} or not defined $self->{xref};
  # we can't actaully change the xrefs until the end
  $self->{new_xref} = substr($self->{tag}, 0, 1). ++$args->{$self->{tag}}
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
  my $self = shift;;
  my ($child) = @_;
  my $c = $self->get_child($child);
  $c ? $c->{value} : undef;
}

sub child_values
{
  my $self = shift;;
  my ($child) = @_;
  map { $_->{value} } $self->get_children($child);
}

sub summary
{
  my $self = shift;
  my $s = "";
  $s .= sprintf("%-5s", $self->{xref});
  my $child = $self->get_child("NAME");
  $s .= sprintf(" %-40s", $child ? $child->{value} : "");
  $child = $self->get_child("SEX");
  $s .= sprintf(" %1s", $child ? $child->{value} : "");
  my $d = "";
  if ($child   = $self->get_child("BIRT") and
      my $date = $child->get_child("DATE"))
  {
    $d = $date->{value};
  }
  $s .= sprintf(" %16s", $d);
  $s;
}

1;

__END__

=head1 NAME

Gedcom::Record - a class to manipulate Gedcom records

Version 1.05 - 20th July 1999

=head1 SYNOPSIS

  use Gedcom::Record;

  $self->parse($record, $grammar)
  $record->collect_xrefs($callback)
  my $xref = $self->resolve_xref($self->{value})
  my @famc = $self->resolve($self->child_values("FAMC"))
  $record->resolve_xrefs($callback)
  $record->unresolve_xrefs($callback)
  return 0 unless $child->validate_semantics
  $record->normalise_dates($format)
  $record->renumber($args)
  my $child = $record->child_value("NAME")
  my @children = $record->child_values("CHIL")
  print $record->summary, "\n"

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

=head2 parse

  $self->parse($record, $grammar)

Parse a Gedcom record.

Match a Gedcom::Record against a Gedcom::Grammar.  Warn of any
mismatches, and associate the Gedcom::Grammar with the Gedcom::Record as
$self->{grammar}.  Do this recursively.

=head2 collect_xrefs

  $record->collect_xrefs($callback)

Recursively collect all the xrefs.  Called by Gedcom::collect_xrefs.
$callback is not used yet.

=head2 resolve_xref

  my $xref = $self->resolve_xref($value)

See Gedcom::resolve_xrefs()

=head2 resolve

  my @famc = $self->resolve $self->child_values("FAMC")

For each argument, either return it or, if it an xref, return the
referenced record.

=head2 resolve_xrefs

  $record->resolve_xrefs($callback)

See Gedcom::resolve_xrefs()

=head2 unresolve_xrefs

  $record->unresolve_xrefs($callback)

See Gedcom::unresolve_xrefs()

=head2 validate_semantics

  return 0 unless $child->validate_semantics

Validate the semantics of the Gedcom::Record.  This performs a number of
consistency checks, but could do even more.

Returns true iff the Record is valid.

=head2 normalise_dates

  $record->normalise_dates($format)

Change the format of all dates in the record.

See the documentation for Gedcom::normalise_dates

=head2 renumber

  $record->renumber($args)

Renumber the record.

See Gedcom::renumber().

=head2 child_value

  my $child = $record->child_value("NAME")

Return the value of the specified child, or undef if the child could not
be found.  Calls get_child().

=head2 child_values

  my @children = $record->child_values("CHIL")

Return a list of the values of the specified children.  Calls
get_children().

=head2 summary

  print $record->summary, "\n"

Return a line of text summarising the record.

=head2 Access functions

All the Gedcom tag names can be used as function names.  Depending on
the context in which they are called, the functions return either an
array of the specified children, or the first specified child.

The descriptions of the tags, with spaces replaced by underscores, can
also be used as function names.  The function names can be of either, or
mixed case.  Unless you use the tag name, in either case, or the
description in lower case, the function will not be pre-declared and you
will need to qualify it or C<use subs>.

=cut

=begin if we cannot make the min/max assumptions specified in
       Gedcom::Grammar::valid_children

use as:
  my @children = @{$ged->{record}{children}};
  my ($m, $w) =
   $ged->{record}->validate_structure($ged->{record}{grammar}, \@children, 1);
  warn $w if $w;

sub validate_grammar
{
  my $self = shift;
  my ($grammar, $children, $all) = @_;
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
         $c <= $#$children && ($all == 1 || !$max || $matches < $max);)
    {
      if ($children->[$c]{tag} eq $value)
      {
        my $w = $children->[$c]->validate_syntax2;
        $warn .= $w;
        splice @$children, $c, 1;
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
    die "What's a " . Data::Dumper->new([$grammar], ["grammar"])
      unless ($value) = $grammar->{value} =~ /<<(.*)>>/;
    die "Can't find $value in gedcom structures"
      unless my $s = $grammar->structure($value);
    $grammar->{structure} = $s;
    print " $value, $min -> $max\n" if $D;
    my ($m, $w);
    do
    {
      ($m, $w) = $self->validate_structure($s, $children, $all);
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
  my ($structure, $children, $all) = @_;
  $all = 0 unless defined $all;
  $I++;
  print "  " x $I . "validate_structure($structure->{structure}, $all)\n" if $D;
  my $warn = "";
  my $total_matches = 0;
  for my $child (@{$structure->{children}})
  {
    my $min = $child->min;
    my $max = $child->max;
    my ($matches, $w) = $self->validate_grammar($child, $children, $all);
    $warn .= $w;
    my $file = $self->{gedcom}{record}{file};
    my $value = $child->{tag} || $child->{structure}{structure};
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
        $total_matches += $matches;                  # only one child is allowed
        last;
      }
    }
    else
    {
      $warn .= "$msg - minimum is $min\n" if $matches < $min;
      $warn .= "$msg - maximum is $max\n" if $matches > $max && $max;
      $total_matches = 1 if $matches;                # all children are required
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
  my $children = [ @{$self->{children}} ];
  $I++;
  my $grammar = $self->{grammar};
  print "  " x $I . "validate_syntax2($grammar->{tag})\n" if $D;
  my $warn = "";
  my $file = $self->{gedcom}{record}{file};
  my $here = "$file:$self->{line}: $self->{tag}" .
             (defined $self->{xref} ? " $self->{xref}" : "");
  for my $child (@$children)
  {
    print "  " x $I . "level $child->{level} on $self->{level}\n" if $D;
    $warn .= "$here: Can't add level $child->{level} to $self->{level}\n"
      if $child->{level} > $self->{level} + 1;
  }
  for my $child (@{$grammar->{children}})
  {
    my $min = $child->min;
    my $max = $child->max;
    my ($matches, $w) = $self->validate_grammar($child, $children, 1);
    $warn .= $w;
    my $value = $child->{tag} || $child->{structure}{structure};
    my $msg = "$here has $matches $value" . ($matches == 1 ? "" : "s");
    print "  " x $I . "$msg - minimum is $min maximum is $max\n" if $D;
    $warn .= "$msg - minimum is $min\n" if $matches < $min;
    $warn .= "$msg - maximum is $max\n" if $matches > $max && $max;
  }
  if (@$children)
  {
    my %tags = map { $_ => 1 } $grammar->children;
    for my $c (@$children)
    {
      my $tag = $c->{tag};
      my $msg = exists $tags{$tag} ? "an extra" : "not a";
      $warn .= "$file:$c->{line}: $tag is $msg child of $self->{tag}\n"
        unless $tag eq "CONT" || $tag eq "CONC" || substr($tag, 0, 1) eq "_";
    }
  }
  $I--;
  $warn
}
=end
