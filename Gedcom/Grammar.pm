# Copyright 1998-1999, Paul Johnson (pjcj@transeda.com)

# This software is free.  It is licensed under the same terms as Perl itself.

# The latest version of this software should be available from my homepage:
# http://www.transeda.com/pjcj

# documentation at __END__

use strict;

require 5.004;

package Gedcom::Grammar;

use Data::Dumper;

use Gedcom::Item 1.03;

use vars qw($VERSION @ISA);
$VERSION = "1.03";
@ISA     = qw( Gedcom::Item );

sub structure
{
  my $self = shift;
  my ($struct) = @_;
  unless (exists $self->{top}{structures})
  {
    $self->{top}{structures} =
      { map { $_->{structure} ? ($_->{structure} => $_) : () }
            @{$self->{top}{children}} };
  }
  $self->{top}{structures}{$struct}
}

sub child
{
  my $self = shift;
  my ($tag) = @_;
  return undef unless defined $tag;
  my $valid_children = $self->valid_children;
  exists $valid_children->{$tag} ? $valid_children->{$tag}{grammar} : undef
}

sub min
{
  my $self = shift;
  exists $self->{min} ? $self->{min} : 1
}

sub max
{
  my $self = shift;
  exists $self->{max} ? $self->{max} eq "M" ? 0 : $self->{max} : 1
}

sub children
{
  my $self = shift;
  keys %{$self->valid_children}
}

sub valid_children
{
  my $self = shift;
  unless (exists $self->{_valid_children})
  {
    my %valid_children;
    for my $child (@{$self->{children}})
    {
      my $min = $child->min;
      my $max = $child->max;
      if ($child->{tag})
      {
        $valid_children{$child->{tag}} =
        {
          grammar => $child,
          min     => $min,
          max     => $max
        };
      }
      else
      {
        die "What's a " . Data::Dumper->new([$child], ["grammar"])
          unless my ($value) = $child->{value} =~ /<<(.*)>>/;
        die "Can't find $value in gedcom structures"
          unless my $structure = $self->structure($value);
        $child->{structure} = $structure;
        while (my($tag, $g) = each %{$structure->valid_children})
        {
          $valid_children{$tag} =
          {
            grammar => $g->{grammar},
            # min and max can be calculated by multiplication because
            # the grammar always permits multiple selection records, and
            # selection records never have compulsory records.  This may
            # change in future grammars, but I would not expect it to -
            # such a grammar would seem to have little practical use.
            min     => $g->{min} * $min,
            max     => $g->{max} * $max
          };
        }
      }
    }
    $self->{_valid_children} = \%valid_children;
  }
  $self->{_valid_children}
}

1;

__END__

=head1 NAME

Gedcom::Grammar - a class to manipulate Gedcom grammars

Version 1.03 - 13th May 1999

=head1 SYNOPSIS

  use Gedcom::Grammar;

  my $st = $grammar->structures("GEDCOM")
  my $sgr = $grammar->child("DATE")
  my @children = $grammar->valid_children

=head1 DESCRIPTION

A selection of subroutines to handle the grammar of a gedcom file.

Derived from Gedcom::Item.

=head1 HASH MEMBERS

Some of the more important hash members are:

=head2 $grammar->{top}

The top of the grammar tree.

=head2 $grammar->{top}{structures}

A reference to a hash mapping the names of all structures to the grammar
objects.

=head1 METHODS

=head2 structures

  my $st = $grammar->structures("GEDCOM")

Return the grammar item of the specified structure, if it exists, or undef.

=head2 child

  my $sgr = $grammar->child("DATE")

Return the grammar item of the specified child, if it exists, or undef.

=head2 min

  my $min = $grammar->min

Return the minimum permissible number of $grammar items

=head2 max

  my $max = $grammar->max

Return the maximum permissible number of $grammar items

=head2 children

  my @children = $grammar->children

Return a list of tags of the grammar's children

=head2 valid_children

  my @children = $grammar->valid_children

Return a hash detailing all the valid children of the grammar item.  The
key is the tag of the child and the value is another hash with three
members:

  grammar => the child grammar
  min     => the minimum permissible number of these children
  max     => the maximum permissible number of these children

=cut
