# Copyright 1998-1999, Paul Johnson (pjcj@transeda.com)

# This software is free.  It is licensed under the same terms as Perl itself.

# The latest version of this software should be available from my homepage:
# http://www.transeda.com/pjcj

# documentation at __END__

use strict;

require 5.005;

package Gedcom::Family;

use Gedcom::Record 1.05;

use vars qw($VERSION @ISA);
$VERSION = "1.05";
@ISA     = qw( Gedcom::Record );

sub husband
{
  my $self = shift;
  my @a = $self->resolve($self->child_values("HUSB"));
  wantarray ? @a : $a[0]
}

sub wife
{
  my $self = shift;
  my @a = $self->resolve($self->child_values("WIFE"));
  wantarray ? @a : $a[0]
}

sub parents
{
  my $self = shift;
  ($self->husband, $self->wife)
}

sub number_of_children
{
  my ($self) = @_;
  $self->child_value("NCHI") || $#{[$self->children]}
}

sub children
{
  my $self = shift;
  my @a = $self->resolve($self->child_values("CHIL"));
  wantarray ? @a : $a[0]
}

sub boys
{
  my $self = shift;
  my @a = grep { $_->child_value("SEX") !~ /^F/i } $self->children;
  wantarray ? @a : $a[0]
}

sub girls
{
  my $self = shift;
  my @a = grep { $_->child_value("SEX") !~ /^M/i } $self->children;
  wantarray ? @a : $a[0]
}

sub print
{
  my $self = shift;
  $self->SUPER::print; $_->print for @{$self->{children}};
}

1;

__END__

=head1 NAME

Gedcom::Family - a class to manipulate Gedcom families

Version 1.05 - 20th July 1999

=head1 SYNOPSIS

  use Gedcom::Family;

  my @rel = $f->husband
  my @rel = $f->wife
  my @rel = $f->parents
  my $nch = $f->number_of_children
  my @rel = $f->children
  my @rel = $f->boys
  my @rel = $f->girls

=head1 DESCRIPTION

A selection of subroutines to handle families in a gedcom file.

Derived from Gedcom::Record.

=head1 HASH MEMBERS

None.

=head1 METHODS

None yet.

=head2 Individual functions

  my @rel = $f->husband
  my @rel = $f->wife
  my @rel = $f->parents
  my @rel = $f->children
  my @rel = $f->boys
  my @rel = $f->girls

Return a list of individuals from family $f.

Each function, even those with a singular name such as husband(),
returns a list of individuals holding that releation in $f.

=head2 number_of_children

  my $nch = $f->number_of_children

Return the number of children in the family, as specified or from
counting.

=cut
