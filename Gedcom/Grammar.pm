# Copyright 1998-1999, Paul Johnson (pjcj@transeda.com)

# This software is free.  It is licensed under the same terms as Perl itself.

# The latest version of this software should be available from my homepage:
# http://www.transeda.com/pjcj

# documentation at __END__

use strict;

require 5.004;

package Gedcom::Grammar;

use Carp;
use Data::Dumper;

use Gedcom::Item 1.01;

BEGIN
{
  use vars qw($VERSION @ISA);
  $VERSION = "1.01";
  @ISA = qw( Gedcom::Item );
}

sub structures
{
  my $self = shift;
  return { map { $_->{structure} ? ($_->{structure}, $_) : () }
           @{$self->{children}} }
}

sub valid_children
{
  my $self = shift;
  my $structures = shift;
  my @children;
  for my $child (@{$self->{children}})
  {
    if (my $tag = $child->{tag})
    {
      push @children, $child;
    }
    else
    {
      if (my ($value) = $child->{value} =~ /<<(.*)>>/)
      {
        if (defined $structures->{$value})
        {
          push @children, $structures->{$value}->valid_children($structures);
        }
        else
        {
          confess "Can't find $value in ", join(" ", keys %{$structures});
        }
      }
      else
      {
        local $Data::Dumper::Indent = 1;
        confess "What's a " . Dumper $child;
      }
    }
  }
  @children;
}

1;

__END__

=head1 NAME

Gedcom::Grammar - a class to manipulate Gedcom grammars

Version 1.01 - 27th April 1999

=head1 SYNOPSIS

  use Gedcom::Grammar;

  my $structures = $grammar->structures()
  my @children = $grammar->valid_children($structures)

=head1 DESCRIPTION

A selection of subroutines to handle the grammar of a gedcom file.

Derived from Gedcom::Item.

=head1 HASH MEMBERS

Some of the more important hash members are:

=head2 $grammar->{structure}

The name of the grammar structure.

=head1 METHODS

=head2 structures

  my $structures = $grammar->structures()

Return a reference to a hash mapping the names of all child structures
to the grammar objects.

=head2 valid_children

  my @children = $grammar->valid_children($structures)

Return an array of all the valid children of the grammar item.

=cut
