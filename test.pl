#!/usr/local/bin/perl -w

# Copyright 1998-1999, Paul Johnson (pjcj@transeda.com)

# This software is free.  It is licensed under the same terms as Perl itself.

# The latest version of this software should be available from my homepage:
# http://www.transeda.com/pjcj

# Version 1.01 - 27th April 1999

use strict;

require 5.004;

my $Test = 0;

sub check ($;$)
{
  my $pass = shift;
  my $test = shift || ++$Test;
  print $pass ? "" : "not ", "ok $test\n";
}

my $Loaded = 0;

BEGIN { $| = 1; print "1..30\n"; }
END   { print "not ok 1\n" unless $Loaded; }

use Gedcom 1.01;

check $Loaded = 1;

eval "use Date::Manip";
Date_Init("DateFormat=UK") if $INC{"Date/Manip.pm"};

main();

sub xrefs (@)
{
  join " ", map { $_->{xref} =~ /I(\d+)/; $1 } @_
}

sub i (@) { "@_" }

sub main()
{
  my $gedcom_file = "royal.ged";
  my $ged = Gedcom->new(grammar_file => "gedcom-5.5.grammar",
                        gedcom_file  => $gedcom_file);
  check $ged;
  check $ged->validate;
  $ged->normalise_dates;
  check $ged->validate;
  $ged->renumber;
  check $ged->validate;
  $ged->order;
  check $ged->validate;
  check xrefs($ged->individuals) eq i 1 .. 91;
  my ($i) = $ged->get_individual("Elizabeth II");
  check $i;

# This is the section for generating the relations
# for my $s (qw( father mother parents husband wife spouse siblings brothers
#                sisters children sons daughters descendents ancestors))
# {
#   print "$s => [ qw( ", xrefs($i->$s()), " ) ],\n";
# }

  my %relations =
  (
    ancestors   => [ qw( 7 8 3 4 1 2 ) ],
    brothers    => [ qw(  ) ],
    children    => [ qw( 11 15 19 23 ) ],
    daughters   => [ qw( 15 ) ],
    descendents => [ qw( 11 15 19 23 13 14 17 18 21 22 ) ],
    father      => [ qw( 7 ) ],
    husband     => [ qw( 10 ) ],
    mother      => [ qw( 8 ) ],
    parents     => [ qw( 7 8 ) ],
    siblings    => [ qw( 24 ) ],
    sisters     => [ qw( 24 ) ],
    sons        => [ qw( 11 19 23 ) ],
    spouse      => [ qw( 10 ) ],
    wife        => [ qw(  ) ],
  );

  for my $r (sort keys %relations)
  {
    check xrefs($i->$r()) eq i @{$relations{$r}};
  }

  my %individuals =
  (
    "B1 C1" => [ 82 ],                                             # exact match
    "B2 C2" => [ 83, 84, 85 ],                             # use word boundaries
    "B3 C3" => [ 86, 87, 88 ],                                  # match anywhere
    "B3 c3" => [ 86, 87, 88, 89 ],                    # match anywhere, any case
    "B4 C4" => [ 90 ],                                      # match in any order
    "B4 c4" => [ 90, 91 ],        # match in any order, any case (order correct)
    "c4 B4" => [ 90, 91 ],       # match in any order, any case (order reversed)
  );

  for my $r (sort keys %individuals)
  {
    check xrefs($ged->get_individual($r)) eq i @{$individuals{$r}};
  }

  check $ged->validate;
# $ged->write("new.ged");
}
