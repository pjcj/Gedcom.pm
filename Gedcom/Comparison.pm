# Copyright 2003, Paul Johnson (pjcj@cpan.org)

# This software is free.  It is licensed under the same terms as Perl itself.

# The latest version of this software should be available from my homepage:
# http://www.pjcj.net

# documentation at __END__

use strict;

require 5.005;

package Gedcom::Comparison;

use vars qw($VERSION);
$VERSION = "1.13";

use Gedcom::Item 1.13;

sub DESTROY {}

sub new
{
  my $proto     = shift;
  my ($r1, $r2) = @_;

  my $class = ref($proto) || $proto;

  my $self =
  {
    record1 => $r1,
    record2 => $r2,
  };

  bless $self, $class;

  $self->compare
}


sub compare
{
  my $self = shift;

  $self->{$_} = [] for qw( identical conflict only1 only2 );

  my $r1 = $self->{record1};
  my $r2 = $self->{record2};

  my ($v1, $v2) = ($r1->{value}, $r2->{value});
  $self->{value_match} = !(defined $v1 ^ defined $v2);
  $self->{value_match} &&= $v1 eq $v2 if defined $v1;
  # $self->{value_match} = defined $r1->{value}
                         # ? defined $r2->{value}
                           # ? r1->value eq $r2->value
                           # : 0
                         # : !defined $r2->{value};

  my @r1 = $r1->items;
  my %r2 = map { $_->tag => $_ } $r2->items;

  TAG1:
  for my $i1 (@r1)
  {
    my $tag = $i1->tag;
    for my $i2 (keys %r2)
    {
      if ($i2 eq $tag)
      {
        my $comp = Gedcom::Comparison->new($i1, delete $r2{$i2});
        push @{$self->{$comp->identical ? "identical" : "conflict"}}, $comp;
        next TAG1
      }
    }
    push @{$self->{only1}}, $i1;
  }

  $self->{only2} = [ values %r2 ];

  $self
}


sub identical
{
  my $self = shift;
  $self->{value_match} &&
  !@{$self->{only1}}   &&
  !@{$self->{only2}}   &&
  !@{$self->{conflict}}
}

sub print
{
  my $self = shift;

  print $self->identical ? "" : "not ";
  print "identical\n";

  printf "value match: %d\n", $self->{value_match};
  printf "identical:   %d\n", scalar @{$self->{identical}};
  printf "conflict:    %d\n", scalar @{$self->{conflict}};
  printf "only1:       %d\n", scalar @{$self->{only1}};
  printf "only2:       %d\n", scalar @{$self->{only2}};

  $self->{record1}->print;
  $self->{record2}->print;

  $_->print for @{$self->{conflict}};
}

1;

__END__

=head1 NAME

Gedcom::Comparison - a module to compare Gedcom records

Version 1.13 - 6th December 2003

=head1 SYNOPSIS

  use Gedcom::Comparison;

=head1 DESCRIPTION

=head1 METHODS

=end
