# Copyright 1998-2005, Paul Johnson (pjcj@cpan.org)

# This software is free.  It is licensed under the same terms as Perl itself.

# The latest version of this software should be available from my homepage:
# http://www.pjcj.net

# documentation at __END__

use strict;

require 5.005;

package Gedcom::Individual;

use Gedcom::Record 1.15;

use vars qw($VERSION @ISA);
$VERSION = "1.15";
@ISA     = qw( Gedcom::Record );

sub name
{
  my $self = shift;
  my $name = $self->tag_value("NAME");
  return "" unless defined $name;
  $name =~ s/\s+/ /g;
  $name =~ s| ?/ ?(.*?) ?/ ?| /$1/ |;
  $name =~ s/^\s+//g;
  $name =~ s/\s+$//g;
  $name
}

sub cased_name
{
  my $self = shift;
  my $name = $self->name;
  $name =~ s|/([^/]*)/?|uc $1|e;
  $name
}

sub surname
{
  my $self = shift;
  my ($surname) = $self->name =~ m|/([^/]*)/?|;
  $surname || ""
}

sub given_names
{
  my $self = shift;
  my $name = $self->name;
  $name =~ s|/([^/]*)/?| |;
  $name =~ s|^\s+||;
  $name =~ s|\s+$||;
  $name =~ s|\s+| |g;
  $name
}

sub soundex
{
  my $self = shift;
  unless ($INC{"Text/Soundex.pm"})
  {
    warn "Text::Soundex.pm is required to use soundex()";
    return undef
  }
  Gedcom::soundex($self->surname)
}

sub sex
{
  my $self = shift;
  my $sex = $self->tag_value("SEX");
  $sex =~ /^F/i ? "F" : $sex =~ /^M/i ? "M" : "U";
}

sub father
{
  my $self = shift;
  my @a = map { $_->husband } $self->famc;
  wantarray ? @a : $a[0]
}

sub mother
{
  my $self = shift;
  my @a = map { $_->wife } $self->famc;
  wantarray ? @a : $a[0]
}

sub parents
{
  my $self = shift;
  ($self->father, $self->mother)
}

sub husband
{
  my $self = shift;
  my @a = grep { $_->{xref} ne $self->{xref} } map { $_->husband } $self->fams;
  wantarray ? @a : $a[0]
}

sub wife
{
  my $self = shift;
  my @a = grep { $_->{xref} ne $self->{xref} } map { $_->wife } $self->fams;
  wantarray ? @a : $a[0]
}

sub spouse
{
  my $self = shift;
  my @a = ($self->husband, $self->wife);
  wantarray ? @a : $a[0]
}

sub siblings
{
  my $self = shift;
  my @a = grep { $_->{xref} ne $self->{xref} } map { $_->children } $self->famc;
  wantarray ? @a : $a[0]
}

sub older_siblings
{
  my $self = shift;
  my @a = map { $_->children } $self->famc;
  my $i;
  for ($i = 0; $i <= $#a; $i++)
  {
    last if $a[$i]->{xref} eq $self->{xref}
  }
  splice @a, $i;
  wantarray ? @a : $a[-1]
}

sub younger_siblings
{
  my $self = shift;
  my @a = map { $_->children } $self->famc;
  my $i;
  for ($i = 0; $i <= $#a; $i++)
  {
    last if $a[$i]->{xref} eq $self->{xref}
  }
  splice @a, 0, $i + 1;
  wantarray ? @a : $a[0]
}

sub brothers
{
  my $self = shift;
  my @a = grep { $_->tag_value("SEX") !~ /^F/i } $self->siblings;
  wantarray ? @a : $a[0]
}

sub sisters
{
  my $self = shift;
  my @a = grep { $_->tag_value("SEX") !~ /^M/i } $self->siblings;
  wantarray ? @a : $a[0]
}

sub children
{
  my $self = shift;
  my @a = map { $_->children } $self->fams;
  wantarray ? @a : $a[0]
}

sub sons
{
  my $self = shift;
  my @a = grep { $_->tag_value("SEX") !~ /^F/i } $self->children;
  wantarray ? @a : $a[0]
}

sub daughters
{
  my $self = shift;
  my @a = grep { $_->tag_value("SEX") !~ /^M/i } $self->children;
  wantarray ? @a : $a[0]
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
      for my $record (@{$fam->_items})
      {
        # print "looking at $record->{tag} $record->{value}\n";
        if (($record->{tag} =~ /$f->[0]/) &&
            $self->resolve($record->{value})->{xref} eq $xref)
        {
          $ret = 0 unless $fam->delete_record($record);
        }
      }
      $self->{gedcom}{record}->delete_record($fam)
        unless $fam->tag_value("HUSB") ||
               $fam->tag_value("WIFE") ||
               $fam->tag_value("CHIL");
      # TODO - write Family::delete ?
      #      - delete associated notes?
    }
  }
  $ret = 0 unless $self->{gedcom}{record}->delete_record($self);
  $_[0] = undef if $ret;                          # Can't reuse a deleted person
  $ret
}

sub print
{
  my $self = shift;
  $self->_items if shift;
  $self->SUPER::print; $_->print for @{$self->{items}};
# print "fams:\n"; $_->print for $self->fams;
# print "famc:\n"; $_->print for $self->famc;
}

sub print_generations
{
  my $self = shift;
  my ($generations, $indent) = @_;
  $generations = 0 unless $generations;
  $indent      = 0 unless $indent;
  return unless $generations > 0;
  my $i = "  " x $indent;
  print "$i$self->{xref} (", $self->rin, ") ", $self->name, "\n" unless $indent;
  $self->print;
  for my $fam ($self->fams)
  {
    # $fam->print;
    for my $spouse ($fam->parents)
    {
      next unless $spouse;
      # print "[$spouse]\n";
      next if $self->xref eq $spouse->xref;
      print "$i= $spouse->{xref} (", $spouse->rin, ") ", $spouse->name, "\n";
    }
    for my $child ($fam->children)
    {
      print "$i> $child->{xref} (", $child->rin, ") ", $child->name, "\n";
      $child->print_generations($generations - 1, $indent + 1);
    }
  }
}

sub famc
{
  my $self = shift;
  my @a = $self->resolve($self->tag_value("FAMC"));
  wantarray ? @a : $a[0]
}

sub fams
{
  my $self = shift;
  my @a = $self->resolve($self->tag_value("FAMS"));
  wantarray ? @a : $a[0]
}

1;

__END__

=head1 NAME

Gedcom::Individual - a module to manipulate Gedcom individuals

Version 1.15 - 3rd May 2005

=head1 SYNOPSIS

  use Gedcom::Individual;

  my $name = $i->name;
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

  my @fam = $i->famc;
  my @fam = $i->fams;

=head1 DESCRIPTION

A selection of subroutines to handle individuals in a gedcom file.

Derived from Gedcom::Record.

=head1 HASH MEMBERS

None.

=head1 METHODS

=head2 name

  my $name = $i->name;

Return the name of the individual, with spaces normalised.

=head2 cased_name

  my $cased_name = $i->cased_name;

Return the name of the individual, with spaces normalised, and surname
in upper case.

=head2 surname

  my $surname = $i->surname;

Return the surname of the individual.

=head2 given_names

  my $given_names = $i->given_names;

Return the given names of the individual, with spaces normalised.

=head2 soundex

  my $soundex = $i->soundex;

Return the soundex code of the individual.  This function is only
available if I<Text::Soundex.pm> is available.

=head2 sex

  my $sex = $i->sex;

Return the sex of the individual, "M", "F" or "U".

=head2 Individual functions

  my @rel = $i->father;
  my @rel = $i->mother;
  my @rel = $i->parents;
  my @rel = $i->husband;
  my @rel = $i->wife;
  my @rel = $i->spouse;
  my @rel = $i->siblings;
  my @rel = $i->older_siblings;
  my @rel = $i->younger_siblings;
  my @rel = $i->brothers;
  my @rel = $i->sisters;
  my @rel = $i->children;
  my @rel = $i->sons;
  my @rel = $i->daughters;
  my @rel = $i->descendents;
  my @rel = $i->ancestors;

Return a list of individuals related to $i.

Each function, even those with a singular name such as father(), returns
a list of individuals holding that relation to $i.

More complex relationships can easily be found using the map function.
eg:

  my @grandparents = map { $_->parents } $i->parents;

=head2 delete

  my $ok  = $i->delete;

Delete $i from the data structure.

This function will also set $i to undef.  This is to remind you that the
individual cannot be used again.

Returns true iff $i was successfully deleted.

=head2 Family functions

  my @fam = $i->famc;
  my @fam = $i->fams;

Return a list of families to which $i belongs.

famc() returns those families in which $i is a child.
fams() returns those families in which $i is a spouse.

=cut
