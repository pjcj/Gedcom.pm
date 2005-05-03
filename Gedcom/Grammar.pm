# Copyright 1998-2005, Paul Johnson (pjcj@cpan.org)

# This software is free.  It is licensed under the same terms as Perl itself.

# The latest version of this software should be available from my homepage:
# http://www.pjcj.net

# documentation at __END__

use strict;

require 5.005;

package Gedcom::Grammar;

use Data::Dumper;

use Gedcom::Item 1.15;

use vars qw($VERSION @ISA);
$VERSION = "1.15";
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
  # print Dumper $self->{top}{structures};
  $self->{top}{structures}{$struct}
}

sub item
{
  my $self = shift;
  my ($tag) = @_;
  return unless defined $tag;
  my $valid_items = $self->valid_items;
  return unless exists $valid_items->{$tag};
  map { $_->{grammar} } @{$valid_items->{$tag}}
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

sub _valid_items
{
  my $self = shift;
  my %valid_items;
  for my $item (@{$self->{items}})
  {
    my $min = $item->min;
    my $max = $item->max;
    if ($item->{tag})
    {
      push @{$valid_items{$item->{tag}}},
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
        push @{$valid_items{$tag}},
        map {
              grammar => $_->{grammar},
              # min and max can be calculated by multiplication because
              # the grammar always permits multiple selection records, and
              # selection records never have compulsory records.  This may
              # change in future grammars, but I would not expect it to -
              # such a grammar would seem to have little practical use.
              min     => $_->{min} * $min,
              max     => $_->{max} * $max
            }, @$g;
      }
      if (exists $item->{items} && @{$item->{items}})
      {
        my $extra_items = $item->_valid_items;
        while (my ($sub_item, $sub_grammars) = each %valid_items)
        {
          for my $sub_grammar (@$sub_grammars)
          {
              $sub_grammar->{grammar}->valid_items;
              while (my ($i, $g) = each %$extra_items)
              {
                # print "adding $i to $sub_item\n";
                $sub_grammar->{grammar}{_valid_items}{$i} = $g;
              }
          }
          # print "giving @{[keys %{$sub_grammar->{grammar}->valid_items}]}\n";
        }
      }
    }
  }
  # print "valid items are @{[keys %valid_items]}\n";
  \%valid_items
}

sub valid_items
{
  my $self = shift;
  $self->{_valid_items} ||= $self->_valid_items
}

1;

__END__

=head1 NAME

Gedcom::Grammar - a module to manipulate Gedcom grammars

Version 1.15 - 3rd May 2005

=head1 SYNOPSIS

  use Gedcom::Grammar;

  my $st = $grammar->structure("GEDCOM");
  my @sgr = $grammar->item("DATE");
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

  my $st = $grammar->structure("GEDCOM");

Return the grammar item of the specified structure, if it exists, or undef.

=head2 item

  my @sgr = $grammar->item("DATE");

Return a list of the possible grammar items of the specified sub-item,
if it exists.

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

Return a hash detailing all the valid sub-items of the grammar item.
The key is the tag of the sub-item and the value is an array of hashes
with three members:

  grammar => the sub-item grammar
  min     => the minimum permissible number of these sub-items
  max     => the maximum permissible number of these sub-items

=cut
