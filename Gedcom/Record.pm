# Copyright 1998-1999, Paul Johnson (pjcj@transeda.com)

# This software is free.  It is licensed under the same terms as Perl itself.

# The latest version of this software should be available from my homepage:
# http://www.transeda.com/pjcj

# documentation at __END__

use strict;

require 5.004;

package Gedcom::Record;

use Data::Dumper;

use Gedcom::Item 1.02;

use vars qw($VERSION @ISA);
$VERSION = "1.02";
@ISA     = qw( Gedcom::Item );

sub parse
{
  my $self = shift;
  my ($record, $structures, $grammar, $callback) = @_;
# print "checking "; $self->print();
# print "against ";  $grammar->print();
  my $t = $record->{tag};
  my $g = $grammar->{tag};
  die "Can't match $t with $g" if $t && $t ne $g;               # internal error
  $record->{grammar} = $grammar;
  my %children = map { $_->{tag} => $_ } $grammar->valid_children($structures);
# print "valid children are: ", join(", ", keys %children), "\n";
  for my $child (@{$record->{children}})
  {
    my $tag = $child->{tag};
    if (defined $children{$tag})
    {
      return 0
        unless $self->parse($child, $structures, $children{$tag}, $callback);
    }
    else
    {
      warn "$self->{file}:$child->{line}: " .
           "$tag does not appear to be a child of $t\n"
        unless $tag eq "CONT" || $tag eq "CONC" || substr($tag, 0, 1) eq "_";
        # TODO - should CONT and CONC be allowed anywhere?
    }
  }
  1;                                          # do we ever want to return false?
}

sub collect_xrefs
{
  my $self = shift;
  my ($callback) = @_;;
  $self->{gedcom}{xrefs}{$self->{xref}} = $self if defined $self->{xref};
  $_->collect_xrefs($callback) for (@{$self->{children}})
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
  $_->resolve_xrefs($callback) for (@{$self->{children}});
  $self;
}

sub unresolve_xrefs
{
  my $self = shift;;
  my ($callback) = @_;
  $self->{value} = $self->{value}{xref}
    if defined $self->{value}
       and UNIVERSAL::isa $self->{value}, "Gedcom::Record"
       and exists $self->{value}{xref};
  $_->unresolve_xrefs($callback) for (@{$self->{children}});
  $self;
}

sub validate
{
  my $self = shift;
  my ($record, $callback) = @_;
  # print "tag is $self->{tag}\n";
  return 1 unless $self->{tag} eq "INDI" || $self->{tag} eq "FAM";
  return 1 if exists $self->{validated};
  $self->{validated} = 1;
  # print "validating: "; $self->print; print $self->summary, "\n";
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
          warn "$f $child->{xref} " .
               "does not reference $self->{tag} $self->{xref} at " .
               "$record->{file} line $self->{line}\n" .
               "$record->{file}:" . ($child->{line} + 1) . ": 1   " .
               join(", ", @{$chk->{$f}}) .  " $self->{xref}\n";
        }
      }
    }
  }
  $self->{validated} = 2;
}

sub renumber
{
  my $self = shift;
  my ($args, $recurse) = @_;
  return if exists $self->{recursed} or not exists $self->{xref};
  $self->{xref} = substr($self->{tag}, 0, 1). ++$args->{$self->{tag}}
    unless exists $self->{renumbered};
  $self->{renumbered} = 1;
  return unless $recurse and not exists $self->{recursed};
  $self->{recursed} = 1;
  if ($self->{tag} eq "INDI")
  {
    my @r = map { $self->$_() } qw(fams famc spouse children parents siblings);
    $_->renumber($args, 0) for (@r);
    $_->renumber($args, 1) for (@r);
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

Version 1.02 - 5th May 1999

=head1 SYNOPSIS

  use Gedcom::Record;

  return 0 unless $self->parse($record, $structures, $grammar, $callback)
  $record->collect_xrefs($callback)
  my $xref = $self->resolve_xref($self->{value})
  my @famc = $self->resolve($self->child_values("FAMC"))
  $record->resolve_xrefs($callback)
  $record->unresolve_xrefs($callback)
  return 0 unless $child->validate($self->{record}, $callback);
  $record->renumber($args);
  my $child = $record->child_value("NAME");
  my @children = $record->child_values("CHIL");
  print $record->summary, "\n";

=head1 DESCRIPTION

A selection of subroutines to handle records in a gedcom file.

Derived from Gedcom::Item.

=head1 HASH MEMBERS

Some of the more important hash members are:

=head2 $record->{renumbered}

Used by renumber().

=head2 $record->{recursed}

Used by renumber().

=head1 METHODS

=head2 parse

  return 0 unless $self->parse($record, $structures, $grammar, $callback)

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

=head2 validate

  return 0 unless $child->validate($self->{record}, $callback);

Validate the Gedcom::Record.  This performs a number of consistency
checks, but could do even more.  $callback is not used yet.

Returns true iff the Record is valid.

=head2 renumber

  $record->renumber($args);

Renumber the record.

See Gedcom::renumber().

=head2 child_value

  my $child = $record->child_value("NAME");

Return the value of the specified child, or undef if the child could not
be found.  Calls get_child().

=head2 child_values

  my @children = $record->child_values("CHIL");

Return a list of the values of the specified children.  Calls
get_children().

=head2 summary

  print $record->summary, "\n";

Return a line of text summarising the record.

=cut
