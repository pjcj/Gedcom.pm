# Copyright 1999-2019, Paul Johnson (paul@pjcj.net)

# This software is free.  It is licensed under the same terms as Perl itself.

# The latest version of this software should be available from my homepage:
# http://www.pjcj.net

# documentation at __END__

use strict;

require 5.005;

package Gedcom::Individual;

use Gedcom::Record 1.21;

use vars qw($VERSION @ISA);
$VERSION = "1.21";
@ISA     = qw( Gedcom::Record );

sub name {
    my $self = shift;
    my $name = $self->tag_value("NAME");
    return "" unless defined $name;
    $name =~ s/\s+/ /g;
    $name =~ s| ?/ ?(.*?) ?/ ?| /$1/ |;
    $name =~ s/^\s+//g;
    $name =~ s/\s+$//g;
    $name
}

sub cased_name {
    my $self = shift;
    my $name = $self->name;
    $name =~ s|/([^/]*)/?|uc $1|e;
    $name
}

sub surname {
    my $self = shift;
    my ($surname) = $self->name =~ m|/([^/]*)/?|;
    $surname || ""
}

sub given_names {
    my $self = shift;
    my $name = $self->name;
    $name =~ s|/([^/]*)/?| |;
    $name =~ s|^\s+||;
    $name =~ s|\s+$||;
    $name =~ s|\s+| |g;
    $name
}

sub soundex { my $self = shift;
    unless ($INC{"Text/Soundex.pm"}) {
        warn "Text::Soundex.pm is required to use soundex()";
        return undef
    }
    Gedcom::soundex($self->surname)
}

sub sex {
  my $self = shift;
  my $sex = $self->tag_value("SEX");
  defined $sex
      ? $sex =~ /^F/i ? "F" : $sex =~ /^M/i ? "M" : "U"
      : "U"
}

sub father {
    my $self = shift;
    my @a = map { $_->husband } $self->famc;
    wantarray ? @a : $a[0]
}

sub mother {
    my $self = shift;
    my @a = map { $_->wife } $self->famc;
    wantarray ? @a : $a[0]
}

sub parents {
    my $self = shift;
    ($self->father, $self->mother)
}

sub husband {
    my $self = shift;
    my @a = grep { $_->{xref} ne $self->{xref} }
            map { $_->husband } $self->fams;
    wantarray ? @a : $a[0]
}

sub wife {
    my $self = shift;
    my @a = grep { $_->{xref} ne $self->{xref} }
            map { $_->wife } $self->fams;
    wantarray ? @a : $a[0]
}

sub spouse {
    my $self = shift;
    my @a = ($self->husband, $self->wife);
    wantarray ? @a : $a[0]
}

sub siblings {
    my $self = shift;
    my @a = grep { $_->{xref} ne $self->{xref} }
            map { $_->children } $self->famc;
    wantarray ? @a : $a[0]
}

sub half_siblings {
    my $self = shift;
    my @all_siblings_multiple =
        map { $_->children } map { $_->fams } $self->parents;
    my @excludelist = ($self, $self->siblings);
    my @a = grep {
        my $cur = $_;
        my $half_sibling = 1;
        for my $test (@excludelist) {
            if ($cur->{xref} eq $test->{xref} ) {
                $half_sibling = 0;
                last;
            }
        }
        push @excludelist, $cur if $half_sibling; # to avoid multiple output
        $half_sibling;
    } @all_siblings_multiple;
    wantarray ? @a : $a[0]
}

sub older_siblings {
    my $self = shift;
    my @a = map { $_->children } $self->famc;
    my $i;
    for ($i = 0; $i <= $#a; $i++) {
        last if $a[$i]->{xref} eq $self->{xref}
    }
    splice @a, $i;
    wantarray ? @a : $a[-1]
}

sub younger_siblings {
    my $self = shift;
    my @a = map { $_->children } $self->famc;
    my $i;
    for ($i = 0; $i <= $#a; $i++) {
        last if $a[$i]->{xref} eq $self->{xref}
    }
    splice @a, 0, $i + 1;
    wantarray ? @a : $a[0]
}

sub brothers {
    my $self = shift;
    my @a = grep { $_->tag_value("SEX") !~ /^F/i } $self->siblings;
    wantarray ? @a : $a[0]
}

sub half_brothers {
    my $self = shift;
    my @a = grep { $_->tag_value("SEX") !~ /^F/i } $self->half_siblings;
    wantarray ? @a : $a[0]
}

sub sisters {
    my $self = shift;
    my @a = grep { $_->tag_value("SEX") !~ /^M/i } $self->siblings;
    wantarray ? @a : $a[0]
}

sub half_sisters {
    my $self = shift;
    my @a = grep { $_->tag_value("SEX") !~ /^M/i } $self->half_siblings;
    wantarray ? @a : $a[0]
}

sub children {
    my $self = shift;
    my @a = map { $_->children } $self->fams;
    wantarray ? @a : $a[0]
}

sub sons {
    my $self = shift;
    my @a = grep { $_->tag_value("SEX") !~ /^F/i } $self->children;
    wantarray ? @a : $a[0]
}

sub daughters {
    my $self = shift;
    my @a = grep { $_->tag_value("SEX") !~ /^M/i } $self->children;
    wantarray ? @a : $a[0]
}

sub descendents {
    my $self = shift;
    my @d;
    my @c = $self->children;
    while (@c) {
        push @d, @c;
        @c = map { $_->children } @c;
    }
    @d
}

sub ancestors {
    my $self = shift;
    my @d;
    my @c = $self->parents;
    while (@c) {
        push @d, @c;
        @c = map { $_->parents } @c;
    }
    @d
}

sub delete {
    my $self = shift;
    my $xref = $self->{xref};
    my $ret = 1;
    for my $f ([ "(HUSB|WIFE)", [$self->fams] ], [ "CHIL", [$self->famc] ]) {
        for my $fam (@{$f->[1]}) {
            # print "deleting from $fam->{xref}\n";
            for my $record (@{$fam->_items}) {
                # print "looking at $record->{tag} $record->{value}\n";
                if (($record->{tag} =~ /$f->[0]/) &&
                    $self->resolve($record->{value})->{xref} eq $xref) {
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
    $_[0] = undef if $ret;  # Can't reuse a deleted person
    $ret
}

sub print {
    my $self = shift;
    $self->_items if shift;
    $self->SUPER::print; $_->print for @{$self->{items}};
    # print "fams:\n"; $_->print for $self->fams;
    # print "famc:\n"; $_->print for $self->famc;
}

sub print_generations {
    my $self = shift;
    my ($generations, $indent) = @_;
    $generations = 0 unless $generations;
    $indent      = 0 unless $indent;
    return unless $generations > 0;
    my $i = "  " x $indent;
    print "$i$self->{xref} (", $self->rin, ") ", $self->name, "\n"
        unless $indent;
    $self->print;
    for my $fam ($self->fams) {
        # $fam->print;
        for my $spouse ($fam->parents) {
            next unless $spouse;
            # print "[$spouse]\n";
            next if $self->xref eq $spouse->xref;
            print "$i= $spouse->{xref} (", $spouse->rin, ") ",
                  $spouse->name, "\n";
        }
        for my $child ($fam->children) {
            print "$i> $child->{xref} (", $child->rin, ") ",
                  $child->name, "\n";
            $child->print_generations($generations - 1, $indent + 1);
        }
    }
}

sub famc {
    my $self = shift;
    my @a = $self->resolve($self->tag_value("FAMC"));
    wantarray ? @a : $a[0]
}

sub fams {
    my $self = shift;
    my @a = $self->resolve($self->tag_value("FAMS"));
    wantarray ? @a : $a[0]
}

# FIXME: currently only finds ancestors
# TODO: find in-laws
# See http://www.myrelative.com/html/relationship.html for inspiration

sub relationship {
    my $self = shift;
    my ($other) = @_;

    my @ancestors = $self->ancestors() or return;

    my $sex = $self->sex;
    die $self->name, ": unknown sex\n" if $sex eq "U";

    for my $person1 (@ancestors) {
        if ($person1 eq $other) {
            # Direct ancestor
            my $steps = $self->_stepsabove($other, 0);
            my $title = $sex eq "M" ? "father" : "mother";
            if ($steps >= 5) {
                $steps -= 2;
                return "$steps times great-grand$title";
            } elsif ($steps == 1) {
                return $title;
            } elsif ($steps == 2) {
                return "grand$title";
            } elsif ($steps == 3) {
                return "great-grand$title";
            } elsif ($steps == 4) {
                return "great-great-grand$title";
            } elsif ($steps <= 0) {
                if (my $spouse = $other->spouse) {
                    if ($self->_stepsabove($spouse, 0)) {
                        # The caller should now check
                        # the spouse's relationship
                        return;
                    }
                }
                die $other->name,
                    ": BUG - not a direct ancestor, steps = $steps";
            }
        }
    }

    my @ancestors2 = $other->ancestors or return;

    for my $person1 (@ancestors) {
        for my $person2 (@ancestors2) {
            # print $person1->name, '->', $person2->name, "\n";
            # G::C is noisy
            # TODO - apparently fixed in Github, awaiting new version on CPAN
            # my $c = Gedcom::Comparison->new($person1, $person2);
            # if($c->identical($person2)) {
                # die 'match found';
            # }
            if ($person1 eq $person2) {
                # Common ancestor is $person2
                my $steps1 = $self->_stepsabove($person1, 0);
                return if $steps1 > 7;
                my $steps2 = $other->_stepsabove($person2, 0);
                return if $steps2 > 7;

                # It would be nice to do this as an algorithm, but this will do
                # e.g. 2, 1 is uncle
                my $rel = {
                    2 << 8 | 2 => "cousin",
                    2 << 8 | 3 => "first cousin once-removed",
                    3 << 8 | 2 => "first cousin once-removed",
                    2 << 8 | 4 => "first cousin twice-removed",
                    3 << 8 | 3 => "second cousin",
                    3 << 8 | 4 => "second cousin once-removed",
                    4 << 8 | 2 => "first cousin twice-removed",
                    5 << 8 | 2 => "first cousin three-times-removed",
                    5 << 8 | 3 => "second cousin twice-removed",
                    6 << 8 | 3 => "second cousin three-times-removed",
                    6 << 8 | 4 => "third cousin twice-removed",
                    6 << 8 | 5 => "fourth cousin once-removed",
                    7 << 8 | 5 => "fourth cousin twice-removed",
                };
                my $m_rel = {
                    1 << 8 | 1 => "brother",
                    1 << 8 | 2 => "nephew",
                    2 << 8 | 1 => "uncle",
                    3 << 8 | 1 => "great-uncle",
                    4 << 8 | 1 => "great-great-uncle",
                };
                my $f_rel = {
                    1 << 8 | 1 => "sister",
                    1 << 8 | 2 => "niece",
                    2 << 8 | 1 => "aunt",
                    3 << 8 | 1 => "great-aunt",
                    4 << 8 | 1 => "great-great-aunt",
                };

                my $n = ($steps1 << 8) | $steps2;
                my $rc = $rel->{$n} || ($sex eq "M" ? $m_rel : $f_rel)->{$n};
                if ($rc && $rc =~ /cousin/) {
                    my $father = $self->father;
                    my $mother = $self->mother;
                    if ($father && ($father->_stepsabove($person2, 0) > 0)) {
                        $rc .= " on your father's side";
                    } elsif ($mother && ($mother->_stepsabove($person2, 0) > 0)) {
                        $rc .= " on your mother's side";
                    }
                }
                # print "$steps1, $steps2\n" if(!defined($rc));

                return $rc;
            }
        }
    }
}

sub _stepsabove {
    my $self = shift;
    my ($target, $count) = @_;

    return -1 if $count == -1;

    return $count if $self eq $target;

    my $father = $self->father;
    if ($father) {
        my $rc = $father->_stepsabove($target, $count + 1);
        return $rc unless $rc == -1;
    }

    my $mother = $self->mother;
    if ($mother) {
        return $mother->_stepsabove($target, $count + 1);
    }

    -1
}

1

__END__

=head1 NAME

Gedcom::Individual - a module to manipulate GEDCOM individuals

Version 1.21 - 14th November 2019

=head1 SYNOPSIS

  use Gedcom::Individual;

  my $name = $i->name;
  my $cased_name = $i->cased_name;
  my $surname = $i->surname;
  my $given_names = $i->given_names;
  my $soundex = $i->soundex;
  my $sex = $i->sex;
  my @rel = $i->father;
  my @rel = $i->mother;
  my @rel = $i->parents;
  my @rel = $i->husband;
  my @rel = $i->wife;
  my @rel = $i->spouse;
  my @rel = $i->siblings;
  my @rel = $i->half_siblings;
  my @rel = $i->brothers;
  my @rel = $i->half_brothers;
  my @rel = $i->sisters;
  my @rel = $i->half_sisters;
  my @rel = $i->children;
  my @rel = $i->sons;
  my @rel = $i->daughters;
  my @rel = $i->descendents;
  my @rel = $i->ancestors;
  my $ok  = $i->delete;

  my @fam = $i->famc;
  my @fam = $i->fams;

=head1 DESCRIPTION

A selection of subroutines to handle individuals in a GEDCOM file.

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
  my @rel = $i->half_siblings;
  my @rel = $i->older_siblings;
  my @rel = $i->younger_siblings;
  my @rel = $i->brothers;
  my @rel = $i->half_brothers;
  my @rel = $i->sisters;
  my @rel = $i->half_sisters;
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

Returns true if $i was successfully deleted.

=head2 Family functions

  my @fam = $i->famc;
  my @fam = $i->fams;

Return a list of families to which $i belongs.

famc() returns those families in which $i is a child.
fams() returns those families in which $i is a spouse.

=cut
