# Copyright 1998-2000, Paul Johnson (pjcj@cpan.org)

# This software is free.  It is licensed under the same terms as Perl itself.

# The latest version of this software should be available from my homepage:
# http://www.pjcj.fsnet.co.uk

# documentation at __END__

use strict;

require 5.005;

package Gedcom::Grammar;

use Data::Dumper;

use Gedcom::Item 1.07;

use vars qw($VERSION @ISA);
$VERSION = "1.07";
@ISA     = qw( Gedcom::Item );

sub structure
{
  my $self = shift;
  my ($struct) = @_;
  unless (exists $self->{top}{structures})
  {
    $self->{top}{structures} =
      { map { $_->{structure} ? ($_->{structure} => $_) : () }
            @{$self->{top}{items}} };
  }
  $self->{top}{structures}{$struct}
}

sub item
{
  my $self = shift;
  my ($tag) = @_;
  return undef unless defined $tag;
  my $valid_items = $self->valid_items;
  exists $valid_items->{$tag} ? $valid_items->{$tag}{grammar} : undef
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

sub items
{
  my $self = shift;
  keys %{$self->valid_items}
}

sub valid_items
{
  my $self = shift;
  unless (exists $self->{_valid_items})
  {
    my %valid_items;
    for my $item (@{$self->{items}})
    {
      my $min = $item->min;
      my $max = $item->max;
      if ($item->{tag})
      {
        $valid_items{$item->{tag}} =
        {
          grammar => $item,
          min     => $min,
          max     => $max
        };
      }
      else
      {
        die "What's a " . Data::Dumper->new([$item], ["grammar"])
          unless my ($value) = $item->{value} =~ /<<(.*)>>/;
        die "Can't find $value in gedcom structures"
          unless my $structure = $self->structure($value);
        $item->{structure} = $structure;
        while (my($tag, $g) = each %{$structure->valid_items})
        {
          $valid_items{$tag} =
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
    $self->{_valid_items} = \%valid_items;
  }
  $self->{_valid_items}
}

1;

__END__

=head1 NAME

Gedcom::Grammar - a module to manipulate Gedcom grammars

Version 1.07 - 14th March 2000

=head1 SYNOPSIS

  use Gedcom::Grammar;

  my $st = $grammar->structures("GEDCOM");
  my $sgr = $grammar->item("DATE");
  my @items = $grammar->valid_items;
  my $min = $grammar->min;
  my $max = $grammar->max;
  my @items = $grammar->items;

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

  my $st = $grammar->structures("GEDCOM");

Return the grammar item of the specified structure, if it exists, or undef.

=head2 item

  my $sgr = $grammar->item("DATE");

Return the grammar item of the specified sub-item, if it exists, or undef.

=head2 min

  my $min = $grammar->min;

Return the minimum permissible number of $grammar items

=head2 max

  my $max = $grammar->max;

Return the maximum permissible number of $grammar items

=head2 items

  my @items = $grammar->items;

Return a list of tags of the grammar's sub-items

=head2 valid_items

  my @items = $grammar->valid_items;

Return a hash detailing all the valid sub-items of the grammar item.  The
key is the tag of the sub-item and the value is another hash with three
members:

  grammar => the sub-item grammar
  min     => the minimum permissible number of these sub-items
  max     => the maximum permissible number of these sub-items

=cut
