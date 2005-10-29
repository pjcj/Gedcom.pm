# Copyright 1998-2005, Paul Johnson (pjcj@cpan.org)

# This software is free.  It is licensed under the same terms as Perl itself.

# The latest version of this software should be available from my homepage:
# http://www.pjcj.net

# documentation at __END__

use strict;

require 5.005;

package Gedcom::Family;

use Gedcom::Record 1.15;

use vars qw($VERSION @ISA);
$VERSION = "1.15";
@ISA     = qw( Gedcom::Record );

sub husband
{
  my $self = shift;
  my @a = $self->resolve($self->tag_value("HUSB"));
  wantarray ? @a : $a[0]
}

sub wife
{
  my $self = shift;
  my @a = $self->resolve($self->tag_value("WIFE"));
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
  my $nchi = $self->tag_value("NCHI");
  defined $nchi ? $nchi : ($#{[$self->children]} + 1)
}

sub children
{
  my $self = shift;
  my @a = $self->resolve($self->tag_value("CHIL"));
  wantarray ? @a : $a[0]
}

sub boys
{
  my $self = shift;
  my @a = grep { $_->tag_value("SEX") !~ /^F/i } $self->children;
  wantarray ? @a : $a[0]
}

sub girls
{
  my $self = shift;
  my @a = grep { $_->tag_value("SEX") !~ /^M/i } $self->children;
  wantarray ? @a : $a[0]
}

sub add_husband
{
  my $self = shift;
  my ($husband) = @_;
  $husband = $self->{gedcom}->get_individual($husband)
    unless UNIVERSAL::isa($husband, "Gedcom::Individual");
  $self->add("husband", $husband);
  $husband->add("fams", $self->{xref});
}

sub add_wife
{
  my $self = shift;
  my ($wife) = @_;
  $wife = $self->{gedcom}->get_individual($wife)
    unless UNIVERSAL::isa($wife, "Gedcom::Individual");
  $self->add("wife", $wife);
  $wife->add("fams", $self->{xref});
}

sub add_child
{
  my $self = shift;
  my ($child) = @_;
  $child = $self->{gedcom}->get_individual($child)
    unless UNIVERSAL::isa($child, "Gedcom::Individual");
  $self->add("child", $child);
  $child->add("famc", $self->{xref});
}

sub print
{
  my $self = shift;
  $self->_items if shift;
  $self->SUPER::print; $_->print for @{$self->{items}};
}

1;

__END__

=head1 NAME

Gedcom::Family - a module to manipulate Gedcom families

Version 1.15 - 3rd May 2005

=head1 SYNOPSIS

  use Gedcom::Family;

  my @rel = $f->husband;
  my @rel = $f->wife;
  my @rel = $f->parents;
  my $nch = $f->number_of_children;
  my @rel = $f->children;
  my @rel = $f->boys;
  my @rel = $f->girls;
  $f->add_husband($i);
  $f->add_wife($i);
  $f->add_child($i);

=head1 DESCRIPTION

A selection of subroutines to handle families in a gedcom file.

Derived from Gedcom::Record.

=head1 HASH MEMBERS

None.

=head1 METHODS

None yet.

=head2 Individual functions

  my @rel = $f->husband;
  my @rel = $f->wife;
  my @rel = $f->parents;
  my @rel = $f->children;
  my @rel = $f->boys;
  my @rel = $f->girls;

Return a list of individuals from family $f.

Each function, even those with a singular name such as husband(),
returns a list of individuals holding that releation in $f.

=head2 number_of_children

  my $nch = $f->number_of_children;

Return the number of children in the family, as specified or from
counting.

=head2 Add functions

  $f->add_husband($i);
  $f->add_wife($i);
  $f->add_child($i);

Add the specified individual to the family in the appropriate position.

These functions also take care of the references from the individual
back to the family, and are to be prefered to the low level addition
functions which do not do this.

=cut
