# Copyright 1998-1999, Paul Johnson (pjcj@transeda.com)

# This software is free.  It is licensed under the same terms as Perl itself.

# The latest version of this software should be available from my homepage:
# http://www.transeda.com/pjcj

# documentation at __END__

use strict;

require 5.004;

package Gedcom::Grammar;

use Data::Dumper;
$Data::Dumper::Indent = 1;
use Carp;

use Gedcom::Item 1.00;

BEGIN
{
  use vars qw($VERSION @ISA);
  $VERSION = "1.00";
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

Version 1.00 - 8th March 1999

=head1 SYNOPSIS

use Gedcom::Grammar;

=head1 DESCRIPTION

To be written...

=cut
