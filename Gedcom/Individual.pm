# Copyright 1998-1999, Paul Johnson (pjcj@transeda.com)

# This software is free.  It is licensed under the same terms as Perl itself.

# The latest version of this software should be available from my homepage:
# http://www.transeda.com/pjcj

# documentation at __END__

use strict;

require 5.004;

package Gedcom::Individual;

use Gedcom::Record 1.02;

use vars qw($VERSION @ISA);
$VERSION = "1.02";
@ISA     = qw( Gedcom::Record );

sub famc
{
  my $self = shift;
  $self->resolve($self->child_values("FAMC"))
}

sub fams
{
  my $self = shift;
  $self->resolve($self->child_values("FAMS"))
}

sub father
{
  my $self = shift;
  map { $_->husband } $self->famc
}

sub mother
{
  my $self = shift;
  map { $_->wife } $self->famc
}

sub parents
{
  my $self = shift;
  ($self->father, $self->mother)
}

sub husband
{
  my $self = shift;
  grep { $_->{xref} ne $self->{xref} } map { $_->husband } $self->fams
}

sub wife
{
  my $self = shift;
  grep { $_->{xref} ne $self->{xref} } map { $_->wife } $self->fams
}

sub spouse
{
  my $self = shift;
  ($self->husband, $self->wife)
}

sub siblings
{
  my $self = shift;
  grep { $_->{xref} ne $self->{xref} } map { $_->children } $self->famc
}

sub brothers
{
  my $self = shift;
  grep { $_->child_value("SEX") !~ /^F/i } $self->siblings
}

sub sisters
{
  my $self = shift;
  grep { $_->child_value("SEX") !~ /^M/i } $self->siblings
}

sub children
{
  my $self = shift;
  grep { $_->{xref} ne $self->{xref} } map { $_->children } $self->fams
}

sub sons
{
  my $self = shift;
  grep { $_->child_value("SEX") !~ /^F/i } $self->children
}

sub daughters
{
  my $self = shift;
  grep { $_->child_value("SEX") !~ /^M/i } $self->children
}

sub descendents
{
  my $self = shift;
  my @d;
  my @c = $self->children;
  while (@c)
  {
    push @d, @c;
    @c = map { $_->children } @c;
  }
  @d
}

sub ancestors
{
  my $self = shift;
  my @d;
  my @c = $self->parents;
  while (@c)
  {
    push @d, @c;
    @c = map { $_->parents } @c;
  }
  @d
}

sub delete
{
  my $self = shift;
  my $xref = $self->{xref};
  my $ret = 1;
  for my $f ( [ "(HUSB|WIFE)", [$self->fams] ], [ "CHIL", [$self->famc] ] )
  {
    for my $fam (@{$f->[1]})
    {
      # print "deleting from $fam->{xref}\n";
      for my $child (@{$fam->{children}})
      {
        # print "looking at $child->{tag} $child->{value}\n";
        if (($child->{tag} =~ /$f->[0]/) &&
            $self->resolve($child->{value})->{xref} eq $xref)
        {
          $ret = 0 unless $fam->delete_child($child);
        }
      }
      $self->{gedcom}{record}->delete_child($fam)
        unless $fam->child_values("HUSB") ||
               $fam->child_values("WIFE") ||
               $fam->child_values("CHIL");
      # TODO - write Family::delete
      #      - delete associated notes?
    }
  }
  $ret = 0 unless $self->{gedcom}{record}->delete_child($self);
  delete $self->{gedcom}{xrefs}{$xref};
  $ret;
}

1;

__END__

=head1 NAME

Gedcom::Individual - a class to manipulate Gedcom individuals

Version 1.02 - 5th May 1999

=head1 SYNOPSIS

  use Gedcom::Individual;

  my @fam = $i->famc;
  my @fam = $i->fams;
  my @rel = $i->father;
  my @rel = $i->mother;
  my @rel = $i->parents;
  my @rel = $i->husband;
  my @rel = $i->wife;
  my @rel = $i->spouse;
  my @rel = $i->siblings;
  my @rel = $i->brothers;
  my @rel = $i->sisters;
  my @rel = $i->children;
  my @rel = $i->sons;
  my @rel = $i->daughters;
  my @rel = $i->descendents;
  my @rel = $i->ancestors;
  my $ok  = $i->delete;

=head1 DESCRIPTION

A selection of subroutines to handle individuals in a gedcom file.

Derived from Gedcom::Record.

=head1 HASH MEMBERS

None.

=head1 METHODS

=head2 Family functions

  my @fam = $i->famc;
  my @fam = $i->fams;

Return a list of families to which $i belongs.

famc() returns those families in which $i is a child.
fams() returns those families in which $i is a spouse.

=head2 Individual functions

  my @rel = $i->father;
  my @rel = $i->mother;
  my @rel = $i->parents;
  my @rel = $i->husband;
  my @rel = $i->wife;
  my @rel = $i->spouse;
  my @rel = $i->siblings;
  my @rel = $i->brothers;
  my @rel = $i->sisters;
  my @rel = $i->children;
  my @rel = $i->sons;
  my @rel = $i->daughters;
  my @rel = $i->descendents;
  my @rel = $i->ancestors;

Return a list of individuals retaled to $i.

Each function, even those with a singular name such as father(), returns
a list of individuals holding that releation to $i.

More complex relationships can easily be found using the map function.
eg:

  my @grandparents = map { $_->parents } $i->parents;

=head2 delete

  my $ok  = $i->delete;

Delete $i from the data structure.

Returns true iff $i was successfully deleted.

=cut
