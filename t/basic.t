#!/usr/local/bin/perl -w

# Copyright 1998-1999, Paul Johnson (pjcj@transeda.com)

# This software is free.  It is licensed under the same terms as Perl itself.

# The latest version of this software should be available from my homepage:
# http://www.transeda.com/pjcj

# Version 1.04 - 29th May 1999

use strict;
use Test;

require 5.004;

BEGIN { plan tests => 2930 }

use Gedcom 1.04;

eval "use Date::Manip";
Date_Init("DateFormat=UK") if $INC{"Date/Manip.pm"};

my @Ged_data = <DATA>;

loop(resolve => "resolve_xrefs");
loop(resolve => "unresolve_xrefs");

sub xrefs (@)
{
  join " ", map { $_->{xref} =~ /(\d+)/; $1 } @_
}

sub rins (@)
{
  join " ", map { $_->child_value("RIN") } @_
}

sub i (@) { "@_" }

sub loop (%)
{
  my (%args) = @_;
  my $resolve = $args{resolve};

  my $gedcom_file = "royal.ged";
  my $ged = Gedcom->new(gedcom_file => $gedcom_file);

  ok $ged;
  ok $ged->validate;

  $ged->$resolve();
# ok $ged->validate;

  $ged->normalise_dates if $INC{"Date/Manip.pm"};
# ok $ged->validate;

  my $fams = 47;
  my $inds = 91;
  my %xrefs;

  ok xrefs($ged->individuals), i(1 .. $inds);
  ok rins ($ged->individuals), i(2 .. $inds + 1);
  ok xrefs($ged->families   ), i(1 .. $fams);
  ok rins ($ged->families   ), i($inds + 2 .. $fams + $inds + 1);

  %xrefs = $ged->renumber;
# ok $ged->validate;

  $ged->$resolve();
# ok $ged->validate;

  ok $xrefs{INDI}, 91;
  ok $xrefs{FAM},  47;
  ok $xrefs{SUBM}, 1;

  $ged->order;
# ok $ged->validate;

  ok xrefs($ged->individuals), i(1 .. $inds);
  ok rins ($ged->individuals), "2 3 4 5 6 8 29 55 63 82 7 9 10 25 11 12 16 "   .
                               "20 24 13 14 15 17 19 18 21 22 23 26 27 28 30 " .
                               "31 49 32 47 33 39 43 48 34 35 36 37 38 40 41 " .
                               "42 44 45 46 50 53 51 54 52 56 57 58 59 61 62 " .
                               "60 64 65 71 78 67 69 70 68 66 72 73 75 74 77 " .
                               "76 79 80 81 83 84 85 86 87 88 89 90 91 92";
  ok xrefs($ged->families   ), i(1 .. $fams);
  ok rins ($ged->families   ), "94 93 116 95 111 104 106 107 115 96 112 98 "  .
                               "108 100 118 99 132 113 114 97 136 102 119 "   .
                               "121 139 126 127 128 138 120 122 130 103 125 " .
                               "105 101 117 110 133 134 135 129 109 137 131 " .
                               "123 124";

  ok $ged->next_xref("I"), "I" . ($inds + 1);
  ok $ged->next_xref("F"), "F" . ($fams + 1);
  ok $ged->next_xref("S"), "S2";

  my ($ind) = $ged->get_individual("Elizabeth II");
  ok $ind;

  my %rin_relations =
  (
    ancestors   => "8 9 4 5 2 3",
    brothers    => "",
    children    => "12 16 20 24",
    daughters   => "16",
    descendents => "12 16 20 24 14 15 18 19 22 23",
    father      => "8",
    husband     => "11",
    mother      => "9",
    parents     => "8 9",
    siblings    => "25",
    sisters     => "25",
    sons        => "12 20 24",
    spouse      => "11",
    wife        => "",
  );

  ok rins($ind->$_()), $rin_relations{$_} for sort keys %rin_relations;

  my %xref1_relations =
  (
    ancestors   => "6 12 3 4 1 2",
    brothers    => "",
    children    => "16 17 18 19",
    daughters   => "17",
    descendents => "16 17 18 19 21 22 25 24 27 28",
    father      => "6",
    husband     => "15",
    mother      => "12",
    parents     => "6 12",
    siblings    => "14",
    sisters     => "14",
    sons        => "16 18 19",
    spouse      => "15",
    wife        => "",
  );

  ok xrefs($ind->$_()), $xref1_relations{$_} for sort keys %xref1_relations;

  my $ind_xref = $ind->{xref};
  ok $ind_xref, "I13";
  ok rins($ged->resolve_xref($ind_xref)), "10";

  %xrefs = $ged->renumber(xrefs => [$ind_xref]);
# ok $ged->validate;

  $ged->$resolve();
# ok $ged->validate;

  ok $xrefs{INDI}, 91;
  ok $xrefs{FAM},  47;
  ok $xrefs{SUBM}, 1;
  ok rins($ged->resolve_xref($ind_xref)), "17";

  ok xrefs($ged->individuals), "29 30 19 20 21 7 28 22 23 24 31 8 1 9 2 3 4 "  .
                               "5 6 10 11 12 13 15 14 16 17 18 25 26 27 32 "   .
                               "33 34 35 36 37 38 39 40 41 42 43 44 45 46 47 " .
                               "48 49 50 51 52 53 54 55 56 57 58 59 60 62 63 " .
                               "61 64 65 66 67 69 70 71 72 68 73 74 75 76 78 " .
                               "77 79 80 81 82 83 84 85 86 87 88 89 90 91";
  ok rins ($ged->individuals), "2 3 4 5 6 8 29 55 63 82 7 9 10 25 11 12 16 "   .
                               "20 24 13 14 15 17 19 18 21 22 23 26 27 28 30 " .
                               "31 49 32 47 33 39 43 48 34 35 36 37 38 40 41 " .
                               "42 44 45 46 50 53 51 54 52 56 57 58 59 61 62 " .
                               "60 64 65 71 78 67 69 70 68 66 72 73 75 74 77 " .
                               "76 79 80 81 83 84 85 86 87 88 89 90 91 92";
  ok xrefs($ged->families   ), "14 46 47 10 15 16 17 18 19 2 11 1 3 4 5 6 7 "  .
                               "8 9 12 13 20 21 22 23 24 25 26 27 28 29 30 "   .
                               "31 32 33 34 35 36 38 39 40 37 41 42 43 44 45";
  ok rins ($ged->families   ), "94 93 116 95 111 104 106 107 115 96 112 98 "   .
                               "108 100 118 99 132 113 114 97 136 102 119 "    .
                               "121 139 126 127 128 138 120 122 130 103 125 "  .
                               "105 101 117 110 133 134 135 129 109 137 131 "  .
                               "123 124";

  ok $ged->next_xref("I"), "I" . ($inds + 1);
  ok $ged->next_xref("F"), "F" . ($fams + 1);
  ok $ged->next_xref("S"), "S2";

  ok rins($ind->$_()), $rin_relations{$_} for sort keys %rin_relations;

  my %xref2_relations =
  (
    ancestors   => "7 8 19 20 29 30",
    brothers    => "",
    children    => "3 4 5 6",
    daughters   => "4",
    descendents => "3 4 5 6 11 12 14 15 17 18",
    father      => "7",
    husband     => "2",
    mother      => "8",
    parents     => "7 8",
    siblings    => "9",
    sisters     => "9",
    sons        => "3 5 6",
    spouse      => "2",
    wife        => "",
  );

  ok xrefs($ind->$_()), $xref2_relations{$_} for sort keys %xref2_relations;

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

  ok xrefs($ged->get_individual($_)), i(@{$individuals{$_}})
    for sort keys %individuals;

# ok $ged->validate;

  my $f1 = $gedcom_file . "1";
  $ged->write($f1);
  ok $ged->validate;
  ok -e $f1;

  # check the gedcom file is correct
  ok open F1, $f1;
  ok <F1>, $_ for @Ged_data;
  ok eof;
  ok close F1;
  ok unlink $f1;
}

__DATA__
0 HEAD
1   SOUR PAF 2.2
1   DEST PAF
1   DATE Friday, 20th November 1992
1   FILE ROYALS.GED
1   CHAR ANSEL
1   GEDC
2     VERS 5.5
2     FORM LINEAGE-LINKED
1   SUBM @S1@
1   NOTE This Gedcom file should only be used as part of the testsuite
2     CONC for Gedcom.pm (http://www.transeda.com/pjcj).  I have removed a
2     CONC lot of data from the original, and changed a few bits, so you
2     CONC should use the original if you want royal genealogy.  Contact me
2     CONC if you cannot locate the original.
2     CONC
2     CONC Paul Johnson (pjcj@transeda.com)
2     CONC
2     CONC >> In a message to Cliff Manis (cmanis@csoftec.csf.com)
2     CONC >> Denis Reid wrote the following:
2     CONC >> Date: Fri, 25 Dec 92 14:12:32 -0500
2     CONC >> From: ah189@cleveland.Freenet.Edu (Denis Reid)
2     CONC >> Subject: THE ROYALS
2     CONC >> First of all,  MERRY CHRISTMAS!
2     CONC >>
2     CONC >> You may make this Royal GEDCOM available available to whomever.
2     CONC >> As you know this is a work in process and have received
2     CONC >> suggestions, corrections and additions from all over the planet...
2     CONC >> some even who claim to be descended from Charlemange, himself!
2     CONC >>
2     CONC >> The weakest part of the Royals is in the French and Spanish lines.
2     CONC >> I found that many of the French Kings had multiple mistresses
2     CONC >> whose descendants claimed noble titles, and the Throne itself in
2     CONC >> some cases.  I have had the hardest time finding good published
2     CONC >> sources for French and Spanish Royalty.
2     CONC >>
2     CONC >> If you do post it to a BBS or send it around, I would appreciate
2     CONC >> it if you'd append a message to the effect that I would welcome
2     CONC >> comments and suggestions and possible sources to improve the
2     CONC >> database.
2     CONC >>
2     CONC >> Since the Royals had so many names and many titles it was
2     CONC >> difficult to "fill in the blanks" with their name.  In the
2     CONC >> previous version, I included all their titles, names, monikers in
2     CONC >> the notes.
2     CONC >>
2     CONC >> Thanks for your interest.   Denis Reid

0 @S1@ SUBM
1   NAME Denis R. Reid
1   ADDR 149 Kimrose Lane
2     CONT Broadview Heights, Ohio 44147-1258
2     CONT Internet Email address:  ah189@cleveland.freenet.edu
1   PHON (216) 237-5364
1   RIN 1

0 @I29@ INDI
1   NAME Edward_VII  /Wettin/
1   TITL King of England
1   SEX M
1   BIRT
2     DATE Tuesday, 9th November 1841
2     PLAC Buckingham,Palace,London,England
1   DEAT
2     DATE Friday, 6th May 1910
2     PLAC Buckingham,Palace,London,England
1   BURI
2     DATE Friday, 20th May 1910
2     PLAC Windsor,Berkshire,England
1   FAMS @F14@
1   FAMC @F46@
1   RIN 2

0 @I30@ INDI
1   NAME Alexandra of_Denmark "Alix"//
1   TITL Princess
1   SEX F
1   BIRT
2     DATE Sunday, 1st December 1844
2     PLAC Yellow Palace,Copenhagen,Denmark
1   DEAT
2     DATE Friday, 20th November 1925
2     PLAC Sandringham,,Norfolk,England
1   BURI
2     PLAC St. George Chap.,Windsor,Berkshire,England
1   FAMS @F14@
1   FAMC @F47@
1   RIN 3

0 @I19@ INDI
1   NAME George_V  /Windsor/
1   TITL King of England
1   SEX M
1   BIRT
2     DATE Saturday, 3rd June 1865
2     PLAC Marlborough Hse,London,England
1   CHR
2     DATE Friday, 7th July 1865
1   DEAT
2     DATE Monday, 20th January 1936
2     PLAC Sandringham,Norfolk,England
1   BURI
2     DATE Tuesday, 28th January 1936
2     PLAC Windsor Castle,St. George Chap.,Berkshire,England
1   FAMS @F10@
1   FAMC @F14@
1   RIN 4

0 @I20@ INDI
1   NAME Mary_of_Teck (May) //
1   TITL Queen
1   SEX F
1   BIRT
2     DATE Sunday, 26th May 1867
2     PLAC Kensington,Palace,London,England
1   DEAT
2     DATE Tuesday, 24th March 1953
2     PLAC Marlborough Hse,London,England
1   BURI
2     DATE Tuesday, 31st March 1953
2     PLAC St. George's,Chapel,Windsor Castle,England
1   FAMS @F10@
1   FAMC @F15@
1   RIN 5

0 @I21@ INDI
1   NAME Edward_VIII  /Windsor/
1   TITL Duke of Windsor
1   SEX M
1   BIRT
2     DATE Saturday, 23rd June 1894
2     PLAC White Lodge,Richmond Park,Surrey,England
1   DEAT
2     DATE Sunday, 28th May 1972
2     PLAC Paris,,,France
1   BURI
2     PLAC Frogmore,Windsor,Berkshire,England
1   FAMS @F16@
1   FAMC @F10@
1   RIN 6

0 @I7@ INDI
1   NAME George_VI  /Windsor/
1   TITL King of England
1   SEX M
1   BIRT
2     DATE Saturday, 14th December 1895
2     PLAC York Cottage,Sandringham,Norfolk,England
1   DEAT
2     DATE Wednesday, 6th February 1952
2     PLAC Sandringham,Norfolk,England
1   BURI
2     DATE Tuesday, 11th March 1952
2     PLAC St. George Chap.,,Windsor,England
1   FAMS @F2@
1   FAMC @F10@
1   RIN 8

0 @I28@ INDI
1   NAME Mary  /Windsor/
1   TITL Princess Royal
1   SEX F
1   BIRT
2     DATE Sunday, 25th April 1897
2     PLAC York Cottage,Sandringham,Norfolk,England
1   DEAT
2     DATE Sunday, 28th March 1965
2     PLAC Harewood House,Yorkshire,,England
1   FAMS @F20@
1   FAMC @F10@
1   RIN 29

0 @I22@ INDI
1   NAME Henry William Frederick/Windsor/
1   TITL Duke
1   SEX M
1   BIRT
2     DATE Saturday, 31st March 1900
2     PLAC York Cottage,Sandringham,Norfolk,England
1   DEAT
2     DATE 1974
1   FAMS @F31@
1   FAMC @F10@
1   RIN 55

0 @I23@ INDI
1   NAME George Edward Alexander/Windsor/
1   TITL Duke of Kent
1   SEX M
1   BIRT
2     DATE Saturday, 20th December 1902
2     PLAC York Cottage,Sandringham,Norfolk,England
1   DEAT
2     DATE Tuesday, 25th August 1942
2     PLAC Morven,,,Scotland
1   FAMS @F34@
1   FAMC @F10@
1   RIN 63

0 @I24@ INDI
1   NAME John Charles Francis/Windsor/
1   TITL Prince
1   SEX M
1   BIRT
2     DATE Wednesday, 12th July 1905
2     PLAC York Cottage,Sandringham,Norfolk,England
1   DEAT
2     DATE Saturday, 18th January 1919
2     PLAC Wood Farm,Wolferton,Norfolk,England
1   BURI
2     PLAC Sandringham,Norfolk,,England
1   FAMC @F10@
1   RIN 82

0 @I31@ INDI
1   NAME Bessiewallis  /Warfield/
1   SEX F
1   BIRT
2     DATE 1896
2     PLAC ,,,U.S.A.
1   DEAT
2     DATE Thursday, 24th April 1986
2     PLAC Paris,,,France
1   BURI
2     PLAC Frogmore,Windsor,Berkshire,England
1   FAMS @F16@
1   FAMS @F17@
1   FAMS @F18@
1   FAMC @F19@
1   RIN 7

0 @I8@ INDI
1   NAME Elizabeth Angela Marguerite/Bowes-Lyon/
1   TITL Lady
1   SEX F
1   BIRT
2     DATE Saturday, 4th August 1900
2     PLAC ,,London,England
1   CHR
2     DATE Sunday, 23rd September 1900
1   FAMS @F2@
1   FAMC @F11@
1   RIN 9

0 @I1@ INDI
1   NAME Elizabeth_II Alexandra Mary/Windsor/
1   TITL Queen of England
1   SEX F
1   BIRT
2     DATE Wednesday, 21st April 1926
2     PLAC 17 Bruton St.,London,W1,England
1   FAMS @F1@
1   FAMC @F2@
1   RIN 10

0 @I9@ INDI
1   NAME Margaret Rose /Windsor/
1   TITL Princess
1   SEX F
1   BIRT
2     DATE Thursday, 21st August 1930
2     PLAC Glamis Castle,,Angus,Scotland
1   FAMS @F12@
1   FAMC @F2@
1   RIN 25

0 @I2@ INDI
1   NAME Philip  /Mountbatten/
1   TITL Prince
1   SEX M
1   BIRT
2     DATE Friday, 10th June 1921
2     PLAC Isle of Kerkira,Mon Repos,Corfu,Greece
1   FAMS @F1@
1   FAMC @F3@
1   RIN 11

0 @I3@ INDI
1   NAME Charles Philip Arthur/Windsor/
1   TITL Prince
1   SEX M
1   BIRT
2     DATE Sunday, 14th November 1948
2     PLAC Buckingham,Palace,London,England
1   CHR
2     DATE Wednesday, 15th December 1948
2     PLAC Buckingham,Palace,Music Room,England
1   FAMS @F4@
1   FAMC @F1@
1   RIN 12

0 @I4@ INDI
1   NAME Anne Elizabeth Alice/Windsor/
1   TITL Princess
1   SEX F
1   BIRT
2     DATE Tuesday, 15th August 1950
2     PLAC Clarence House,St. James,,England
1   CHR
2     DATE Saturday, 21st October 1950
2     PLAC ,,,England
1   FAMS @F6@
1   FAMC @F1@
1   RIN 16

0 @I5@ INDI
1   NAME Andrew Albert Christian/Windsor/
1   TITL Duke of York
1   SEX M
1   BIRT
2     DATE Friday, 19th February 1960
2     PLAC Belgian Suite,Buckingham,Palace,England
1   FAMS @F8@
1   FAMC @F1@
1   RIN 20

0 @I6@ INDI
1   NAME Edward Anthony Richard/Windsor/
1   TITL Prince
1   SEX M
1   BIRT
2     DATE Tuesday, 10th March 1964
2     PLAC Buckingham,Palace,London,England
1   CHR
2     DATE Saturday, 2nd May 1964
1   FAMC @F1@
1   RIN 24

0 @I10@ INDI
1   NAME Diana Frances /Spencer/
1   TITL Lady
1   SEX F
1   BIRT
2     DATE Saturday, 1st July 1961
2     PLAC Park House,Sandringham,Norfolk,England
1   CHR
2     PLAC Sandringham,Church,Norfolk,England
1   FAMS @F4@
1   FAMC @F5@
1   RIN 13

0 @I11@ INDI
1   NAME William Arthur Philip/Windsor/
1   TITL Prince
1   SEX M
1   BIRT
2     DATE Monday, 21st June 1982
2     PLAC St. Mary's Hosp.,Paddington,London,England
1   CHR
2     DATE Wednesday, 4th August 1982
2     PLAC Music Room,Buckingham,Palace,England
1   FAMC @F4@
1   RIN 14

0 @I12@ INDI
1   NAME Henry Charles Albert/Windsor/
1   TITL Prince
1   SEX M
1   BIRT
2     DATE Saturday, 15th September 1984
2     PLAC St. Mary's Hosp.,Paddington,London,England
1   FAMC @F4@
1   RIN 15

0 @I13@ INDI
1   NAME Mark Anthony Peter/Phillips/
1   TITL Captain
1   SEX M
1   BIRT
2     DATE Wednesday, 22nd September 1948
1   FAMS @F6@
1   FAMC @F7@
1   RIN 17

0 @I15@ INDI
1   NAME Zara Anne Elizabeth/Phillips/
1   SEX F
1   BIRT
2     DATE Friday, 15th May 1981
2     PLAC St. Marys Hosp.,Paddington,London,England
1   FAMC @F6@
1   RIN 19

0 @I14@ INDI
1   NAME Peter Mark Andrew/Phillips/
1   SEX M
1   BIRT
2     DATE Tuesday, 15th November 1977
2     PLAC St. Mary's Hosp.,Paddington,London,England
1   CHR
2     DATE Thursday, 22nd December 1977
2     PLAC Music Room,Buckingham,Palace,England
1   FAMC @F6@
1   RIN 18

0 @I16@ INDI
1   NAME Sarah Margaret /Ferguson/
1   TITL Duchess of York
1   SEX F
1   BIRT
2     DATE Thursday, 15th October 1959
2     PLAC 27 Welbech St.,Marylebone,London,England
1   FAMS @F8@
1   FAMC @F9@
1   RIN 21

0 @I17@ INDI
1   NAME Beatrice Elizabeth Mary/Windsor/
1   TITL Princess
1   SEX F
1   BIRT
2     DATE Monday, 8th August 1988
2     PLAC Portland Hosp.,,England
1   FAMC @F8@
1   RIN 22

0 @I18@ INDI
1   NAME Eugenie Victoria Helena/Windsor/
1   TITL Princess
1   SEX F
1   BIRT
2     DATE Friday, 23rd March 1990
2     PLAC London,England
1   CHR
2     DATE Sunday, 23rd December 1990
2     PLAC Sandringham,England
1   FAMC @F8@
1   RIN 23

0 @I25@ INDI
1   NAME Anthony Charles Robert/Armstrong-Jones/
1   TITL Earl of Snowdon
1   SEX M
1   BIRT
2     DATE Friday, 7th March 1930
1   FAMS @F12@
1   FAMS @F13@
1   RIN 26

0 @I26@ INDI
1   NAME David Albert Charles/Armstrong-Jones/
1   TITL Vicount Linley
1   SEX M
1   BIRT
2     DATE Friday, 3rd November 1961
1   FAMC @F12@
1   RIN 27

0 @I27@ INDI
1   NAME Sarah Frances Elizabeth/Armstrong-Jones/
1   TITL Lady
1   SEX F
1   BIRT
2     DATE Friday, 1st May 1964
1   FAMC @F12@
1   RIN 28

0 @I32@ INDI
1   NAME Henry George Charles/Lascelles/
1   TITL Viscount
1   SEX M
1   BIRT
2     DATE 1882
1   DEAT
2     DATE 1947
1   FAMS @F20@
1   RIN 30

0 @I33@ INDI
1   NAME George Earl_of_Harewood /Lascelles/
1   TITL Viscount
1   SEX M
1   BIRT
2     DATE 1923
1   FAMS @F21@
1   FAMS @F22@
1   FAMC @F20@
1   RIN 31

0 @I34@ INDI
1   NAME Gerald  /Lascelles/
1   TITL Hon.
1   SEX M
1   BIRT
2     DATE 1924
1   FAMS @F28@
1   FAMS @F29@
1   FAMC @F20@
1   RIN 49

0 @I35@ INDI
1   NAME Marion (Maria) Donata/Stein/
1   TITL Countess
1   SEX F
1   BIRT
2     DATE 1926
1   FAMS @F21@
1   FAMC @F23@
1   RIN 32

0 @I36@ INDI
1   NAME Patricia  /Tuckwell/
1   SEX F
1   BIRT
2     DATE 1923
1   FAMS @F22@
1   FAMS @F27@
1   RIN 47

0 @I37@ INDI
1   NAME David  /Lascelles/
1   TITL Viscount
1   SEX M
1   BIRT
2     DATE 1950
1   FAMS @F24@
1   FAMC @F21@
1   RIN 33

0 @I38@ INDI
1   NAME James  /Lascelles/
1   TITL Hon.
1   SEX M
1   BIRT
2     DATE 1953
1   FAMS @F25@
1   FAMC @F21@
1   RIN 39

0 @I39@ INDI
1   NAME Jeremy  /Lascelles/
1   TITL Hon.
1   SEX M
1   BIRT
2     DATE 1955
1   FAMS @F26@
1   FAMC @F21@
1   RIN 43

0 @I40@ INDI
1   NAME Mark  /Lascelles/
1   TITL Hon.
1   SEX M
1   BIRT
2     DATE 1964
1   FAMC @F22@
1   RIN 48

0 @I41@ INDI
1   NAME Margaret  /Messenger/
1   SEX F
1   FAMS @F24@
1   RIN 34

0 @I42@ INDI
1   NAME Emily  //
1   TITL Hon.
1   SEX F
1   BIRT
2     DATE 1976
1   FAMC @F24@
1   RIN 35

0 @I43@ INDI
1   NAME Benjamin  //
1   TITL Hon.
1   SEX M
1   BIRT
2     DATE 1978
1   FAMC @F24@
1   RIN 36

0 @I44@ INDI
1   NAME Alexander  /Lascelles/
1   TITL Hon.
1   SEX M
1   BIRT
2     DATE 1980
1   FAMC @F24@
1   RIN 37

0 @I45@ INDI
1   NAME Edward  /Lascelles/
1   SEX M
1   BIRT
2     DATE 1982
1   FAMC @F24@
1   RIN 38

0 @I46@ INDI
1   NAME Fredericka Ann /Duhrrson/
1   SEX F
1   FAMS @F25@
1   RIN 40

0 @I47@ INDI
1   NAME Sophie  /Lascelles/
1   SEX F
1   BIRT
2     DATE 1973
1   FAMC @F25@
1   RIN 41

0 @I48@ INDI
1   NAME Rowan  /Lascelles/
1   SEX M
1   BIRT
2     DATE 1977
1   FAMC @F25@
1   RIN 42

0 @I49@ INDI
1   NAME Julie  /Bayliss/
1   SEX F
1   FAMS @F26@
1   RIN 44

0 @I50@ INDI
1   NAME Thomas  /Lascelles/
1   SEX M
1   BIRT
2     DATE 1982
1   FAMC @F26@
1   RIN 45

0 @I51@ INDI
1   NAME Ellen  /Lascelles/
1   SEX F
1   BIRT
2     DATE 1984
1   FAMC @F26@
1   RIN 46

0 @I52@ INDI
1   NAME Angela  /Dowding/
1   SEX F
1   BIRT
2     DATE 1919
1   FAMS @F28@
1   RIN 50

0 @I53@ INDI
1   NAME Elizabeth Collingwood /Colvin/
1   SEX F
1   BIRT
2     DATE 1924
1   FAMS @F29@
1   RIN 53

0 @I54@ INDI
1   NAME Henry  /Lascelles/
1   SEX M
1   BIRT
2     DATE 1953
1   FAMS @F30@
1   FAMC @F28@
1   RIN 51

0 @I55@ INDI
1   NAME Martin  /Lascelles/
1   SEX M
1   BIRT
2     DATE 1963
1   FAMC @F29@
1   RIN 54

0 @I56@ INDI
1   NAME Alexandra  /Morton/
1   SEX F
1   FAMS @F30@
1   RIN 52

0 @I57@ INDI
1   NAME Alice Christabel /Montagu-Douglas/
1   TITL Lady
1   SEX F
1   BIRT
2     DATE Wednesday, 25th December 1901
2     PLAC London,England
1   FAMS @F31@
1   FAMC @F32@
1   RIN 56

0 @I58@ INDI
1   NAME William Henry Andrew/Windsor/
1   TITL Prince
1   SEX M
1   BIRT
2     DATE Thursday, 18th December 1941
2     PLAC Hadley Common,Hertfordshire,England
1   CHR
2     DATE Sunday, 22nd February 1942
2     PLAC Private Chapel,Windsor Castle,Berkshire,England
1   DEAT
2     DATE Monday, 28th August 1972
2     PLAC Near,Wolverhampton,England
1   FAMC @F31@
1   RIN 57

0 @I59@ INDI
1   NAME Richard Alexander Walter/Windsor/
1   TITL Prince
1   SEX M
1   BIRT
2     DATE Saturday, 26th August 1944
2     PLAC Hadley Common,Hertfordshire,England
1   CHR
2     DATE Friday, 20th October 1944
2     PLAC Private Chapel,Windsor Castle,Berkshire,England
1   FAMS @F33@
1   FAMC @F31@
1   RIN 58

0 @I60@ INDI
1   NAME Birgitte of_Denmark /von_Deurs/
1   TITL Duchess
1   SEX F
1   BIRT
2     DATE 1947
1   FAMS @F33@
1   RIN 59

0 @I62@ INDI
1   NAME Davina Elizabeth Alice/Windsor/
1   TITL Lady
1   SEX F
1   BIRT
2     DATE Saturday, 19th November 1977
1   CHR
2     PLAC Barnwell Church,,England
1   FAMC @F33@
1   RIN 61

0 @I63@ INDI
1   NAME Rose Victoria Birgitte/Windsor/
1   TITL Lady
1   SEX F
1   BIRT
2     DATE Saturday, 1st March 1980
2     PLAC St. Marys Hosp.,Paddington,England
1   CHR
2     DATE Sunday, 13th July 1980
2     PLAC Barnwell Church,,England
1   FAMC @F33@
1   RIN 62

0 @I61@ INDI
1   NAME Alexander Patrick Gregers//
1   TITL Earl of Ulster
1   SEX M
1   BIRT
2     DATE Thursday, 24th October 1974
2     PLAC St. Marys Hosp.,Paddington,London,England
1   CHR
2     DATE Sunday, 9th February 1975
2     PLAC Barnwell Church
1   FAMC @F33@
1   RIN 60

0 @I64@ INDI
1   NAME Marina of_Greece //
1   TITL Princess
1   SEX F
1   BIRT
2     DATE Friday, 30th November 1906
2     PLAC Athens,Greece
1   DEAT
2     DATE 1968
2     PLAC Kensington,Palace,,England
1   FAMS @F34@
1   FAMC @F35@
1   RIN 64

0 @I65@ INDI
1   NAME Edward George Nicholas/Windsor/
1   TITL Duke of Kent
1   SEX M
1   BIRT
2     DATE Monday, 9th September 1935
2     PLAC 3 Belgrave Sq.,,England
1   FAMS @F36@
1   FAMC @F34@
1   RIN 65

0 @I66@ INDI
1   NAME Alexandra  /Windsor/
1   TITL Princess
1   SEX F
1   BIRT
2     DATE Friday, 25th December 1936
1   FAMS @F41@
1   FAMC @F34@
1   RIN 71

0 @I67@ INDI
1   NAME Michael  /Windsor/
1   TITL Prince
1   SEX M
1   BIRT
2     DATE Saturday, 4th July 1942
2     PLAC Coppins,,England
1   FAMS @F44@
1   FAMC @F34@
1   RIN 78

0 @I69@ INDI
1   NAME George Philip of_St._Andrews/Windsor/
1   TITL Earl
1   SEX M
1   BIRT
2     DATE Tuesday, 26th June 1962
1   CHR
2     DATE Friday, 14th September 1962
2     PLAC Buckingham,Palace,Music Room,England
1   FAMS @F38@
1   FAMC @F36@
1   RIN 67

0 @I70@ INDI
1   NAME Helen Marina Lucy/Windsor/
1   TITL Lady
1   SEX F
1   BIRT
2     DATE Tuesday, 28th April 1964
1   CHR
2     DATE Tuesday, 12th May 1964
2     PLAC Private Chapel,Windsor Castle,Berkshire,England
1   FAMC @F36@
1   RIN 69

0 @I71@ INDI
1   NAME Nicholas Charles Edward/Windsor/
1   TITL Lord
1   SEX M
1   BIRT
2     DATE Saturday, 25th July 1970
2     PLAC Kings College,Hospital,Denmark Hill
1   CHR
2     PLAC Private Chapel,Windsor Castle,Berkshire,England
1   FAMC @F36@
1   RIN 70

0 @I72@ INDI
1   NAME Sylvana  /Tomaselli/
1   SEX F
1   BIRT
2     DATE ABT    1957
2     PLAC Canada
1   FAMS @F39@
1   FAMS @F38@
1   FAMC @F40@
1   RIN 68

0 @I68@ INDI
1   NAME Katharine  /Worsley/
1   TITL Duchess of Kent
1   SEX F
1   BIRT
2     DATE 1933
1   FAMS @F36@
1   FAMC @F37@
1   RIN 66

0 @I73@ INDI
1   NAME Angus  /Ogilvy/
1   TITL Hon.
1   SEX M
1   BIRT
2     DATE 1928
1   FAMS @F41@
1   RIN 72

0 @I74@ INDI
1   NAME James Robert Bruce/Ogilvy/
1   SEX M
1   BIRT
2     DATE Saturday, 29th February 1964
2     PLAC Thatched House,Lodge,,England
1   FAMS @F42@
1   FAMC @F41@
1   RIN 73

0 @I75@ INDI
1   NAME Marina Victoria Alexandra/Ogilvy/
1   SEX F
1   BIRT
2     DATE Sunday, 31st July 1966
2     PLAC Thatched House,Lodge,Richmond Park,England
1   FAMS @F43@
1   FAMC @F41@
1   RIN 75

0 @I76@ INDI
1   NAME Julia  /Rawlinson/
1   SEX F
1   FAMS @F42@
1   RIN 74

0 @I78@ INDI
1   NAME /Mowatt/
1   SEX F
1   BIRT
2     DATE Saturday, 26th May 1990
1   FAMC @F43@
1   RIN 77

0 @I77@ INDI
1   NAME Paul  /Mowatt/
1   SEX M
1   BIRT
2     DATE ABT    1962
1   FAMS @F43@
1   RIN 76

0 @I79@ INDI
1   NAME Marie-Christine  /von_Reibnitz/
1   TITL Baroness
1   SEX F
1   BIRT
2     DATE Monday, 15th January 1945
2     PLAC Czechoslovakia
1   FAMS @F45@
1   FAMS @F44@
1   RIN 79

0 @I80@ INDI
1   NAME Frederick  /Windsor/
1   TITL Lord
1   SEX M
1   BIRT
2     DATE Friday, 6th April 1979
2     PLAC St. Mary's Hosp.,Paddington,London,England
1   CHR
2     DATE Wednesday, 11th July 1979
2     PLAC Chapel Royal,St. James Palace,England
1   FAMC @F44@
1   RIN 80

0 @I81@ INDI
1   NAME Gabriella Marina Alexandra/Windsor/
1   TITL Lady
1   SEX F
1   BIRT
2     DATE Thursday, 23rd April 1981
2     PLAC ,,England
1   CHR
2     DATE Monday, 8th June 1981
2     PLAC Chapel Royal,St. James Palace,England
1   FAMC @F44@
1   RIN 81

0 @I82@ INDI
1   NAME B1 C1
1   RIN 83

0 @I83@ INDI
1   NAME A2 B2 C2
1   RIN 84

0 @I84@ INDI
1   NAME B2 C2 D2
1   RIN 85

0 @I85@ INDI
1   NAME A2 B2 C2 D2
1   RIN 86

0 @I86@ INDI
1   NAME A3B3 C3 D3
1   RIN 87

0 @I87@ INDI
1   NAME A3 B3 C3D3
1   RIN 88

0 @I88@ INDI
1   NAME A3B3 C3D3
1   RIN 89

0 @I89@ INDI
1   NAME a3b3 c3d3
1   RIN 90

0 @I90@ INDI
1   NAME A4B4C4D4
1   RIN 91

0 @I91@ INDI
1   NAME a4b4c4d4
1   RIN 92

0 @F14@ FAM
1   HUSB @I29@
1   WIFE @I30@
1   CHIL @I19@
1   MARR
2     DATE Tuesday, 10th March 1863
2     PLAC St. George Chap.,Windsor,,England
1   RIN 94

0 @F46@ FAM
1   CHIL @I29@
1   DIV N
1   MARR
2     DATE Monday, 10th February 1840
2     PLAC Chapel Royal,St. James Palace,England
1   RIN 93

0 @F47@ FAM
1   CHIL @I30@
1   MARR
2     DATE 1842
1   RIN 116

0 @F10@ FAM
1   HUSB @I19@
1   WIFE @I20@
1   CHIL @I21@
1   CHIL @I7@
1   CHIL @I28@
1   CHIL @I22@
1   CHIL @I23@
1   CHIL @I24@
1   MARR
2     DATE Thursday, 6th July 1893
2     PLAC Chapel Royal,St. James Palace
1   RIN 95

0 @F15@ FAM
1   CHIL @I20@
1   RIN 111

0 @F16@ FAM
1   HUSB @I21@
1   WIFE @I31@
1   DIV N
1   MARR
2     DATE Thursday, 3rd June 1937
2     PLAC Chateau de Cande,Monts,,France
1   RIN 104

0 @F17@ FAM
1   WIFE @I31@
1   DIV Y
1   MARR
2     DATE 1916
1   RIN 106

0 @F18@ FAM
1   WIFE @I31@
1   DIV Y
1   MARR
2     DATE 1928
1   RIN 107

0 @F19@ FAM
1   CHIL @I31@
1   RIN 115

0 @F2@ FAM
1   HUSB @I7@
1   WIFE @I8@
1   CHIL @I1@
1   CHIL @I9@
1   DIV N
1   MARR
2     DATE Thursday, 26th April 1923
1   RIN 96

0 @F11@ FAM
1   CHIL @I8@
1   RIN 112

0 @F1@ FAM
1   HUSB @I2@
1   WIFE @I1@
1   CHIL @I3@
1   CHIL @I4@
1   CHIL @I5@
1   CHIL @I6@
1   DIV N
1   MARR
2     DATE Thursday, 20th November 1947
2     PLAC Westminster,Abbey,London,England
1   RIN 98

0 @F3@ FAM
1   CHIL @I2@
1   MARR
2     DATE 1903
1   RIN 108

0 @F4@ FAM
1   HUSB @I3@
1   WIFE @I10@
1   CHIL @I11@
1   CHIL @I12@
1   DIV N
1   MARR
2     DATE Wednesday, 29th July 1981
2     PLAC St. Paul's,Cathedral,London,England
1   RIN 100

0 @F5@ FAM
1   CHIL @I10@
1   DIV Y
1   MARR
2     DATE 1954
2     PLAC Westminster,Abbey,London,England
1   RIN 118

0 @F6@ FAM
1   HUSB @I13@
1   WIFE @I4@
1   CHIL @I14@
1   CHIL @I15@
1   DIV N
1   MARR
2     DATE Wednesday, 14th November 1973
2     PLAC Westminster,Abbey,London,England
1   RIN 99

0 @F7@ FAM
1   CHIL @I13@
1   RIN 132

0 @F8@ FAM
1   HUSB @I5@
1   WIFE @I16@
1   CHIL @I17@
1   CHIL @I18@
1   MARR
2     DATE Wednesday, 23rd July 1986
2     PLAC Westminster,Abbey,London,England
1   RIN 113

0 @F9@ FAM
1   CHIL @I16@
1   DIV Y
1   MARR
2     DATE Thursday, 19th January 1956
2     PLAC St. Margarets,Westminster,England
1   RIN 114

0 @F12@ FAM
1   HUSB @I25@
1   WIFE @I9@
1   CHIL @I26@
1   CHIL @I27@
1   DIV Y
1   MARR
2     DATE Friday, 6th May 1960
2     PLAC Westminster,Cathedral,London,England
1   RIN 97

0 @F13@ FAM
1   HUSB @I25@
1   MARR
2     DATE Sunday, 17th December 1978
1   RIN 136

0 @F20@ FAM
1   HUSB @I32@
1   WIFE @I28@
1   CHIL @I33@
1   CHIL @I34@
1   MARR
2     DATE Tuesday, 28th February 1922
2     PLAC Westminster,Abbey,London,England
1   RIN 102

0 @F21@ FAM
1   HUSB @I33@
1   WIFE @I35@
1   CHIL @I37@
1   CHIL @I38@
1   CHIL @I39@
1   DIV Y
1   MARR
2     DATE 1949
1   RIN 119

0 @F22@ FAM
1   HUSB @I33@
1   WIFE @I36@
1   CHIL @I40@
1   MARR
2     DATE 1967
1   RIN 121

0 @F23@ FAM
1   CHIL @I35@
1   RIN 139

0 @F24@ FAM
1   HUSB @I37@
1   WIFE @I41@
1   CHIL @I42@
1   CHIL @I43@
1   CHIL @I44@
1   CHIL @I45@
1   MARR
2     DATE 1979
1   RIN 126

0 @F25@ FAM
1   HUSB @I38@
1   WIFE @I46@
1   CHIL @I47@
1   CHIL @I48@
1   MARR
2     DATE 1973
1   RIN 127

0 @F26@ FAM
1   HUSB @I39@
1   WIFE @I49@
1   CHIL @I50@
1   CHIL @I51@
1   MARR
2     DATE 1981
1   RIN 128

0 @F27@ FAM
1   WIFE @I36@
1   RIN 138

0 @F28@ FAM
1   HUSB @I34@
1   WIFE @I52@
1   CHIL @I54@
1   DIV Y
1   MARR
2     DATE 1952
1   RIN 120

0 @F29@ FAM
1   HUSB @I34@
1   WIFE @I53@
1   CHIL @I55@
1   MARR
2     DATE 1978
1   RIN 122

0 @F30@ FAM
1   HUSB @I54@
1   WIFE @I56@
1   MARR
2     DATE 1979
1   RIN 130

0 @F31@ FAM
1   HUSB @I22@
1   WIFE @I57@
1   CHIL @I58@
1   CHIL @I59@
1   MARR
2     DATE Wednesday, 6th November 1935
2     PLAC Buckingham,Palace,London,England
1   RIN 103

0 @F32@ FAM
1   CHIL @I57@
1   RIN 125

0 @F33@ FAM
1   HUSB @I59@
1   WIFE @I60@
1   CHIL @I61@
1   CHIL @I62@
1   CHIL @I63@
1   MARR
2     DATE Wednesday, 19th July 1972
1   RIN 105

0 @F34@ FAM
1   HUSB @I23@
1   WIFE @I64@
1   CHIL @I65@
1   CHIL @I66@
1   CHIL @I67@
1   MARR
2     DATE Thursday, 29th November 1934
2     PLAC Westminster,Abbey,London,England
1   RIN 101

0 @F35@ FAM
1   CHIL @I64@
1   MARR
2     DATE 1902
1   RIN 117

0 @F36@ FAM
1   HUSB @I65@
1   WIFE @I68@
1   CHIL @I69@
1   CHIL @I70@
1   CHIL @I71@
1   MARR
2     DATE 1961
1   RIN 110

0 @F38@ FAM
1   HUSB @I69@
1   WIFE @I72@
1   MARR
2     DATE Tuesday, 19th January 1988
1   RIN 133

0 @F39@ FAM
1   WIFE @I72@
1   DIV Y
1   RIN 134

0 @F40@ FAM
1   CHIL @I72@
1   DIV Y
1   RIN 135

0 @F37@ FAM
1   CHIL @I68@
1   RIN 129

0 @F41@ FAM
1   HUSB @I73@
1   WIFE @I66@
1   CHIL @I74@
1   CHIL @I75@
1   MARR
2     DATE Friday, 19th April 1963
2     PLAC ,,England
1   RIN 109

0 @F42@ FAM
1   HUSB @I74@
1   WIFE @I76@
1   MARR
2     DATE AFT    1989
1   RIN 137

0 @F43@ FAM
1   HUSB @I77@
1   WIFE @I75@
1   CHIL @I78@
1   MARR
2     DATE Monday, 19th February 1990
1   RIN 131

0 @F44@ FAM
1   HUSB @I67@
1   WIFE @I79@
1   CHIL @I80@
1   CHIL @I81@
1   MARR
2     DATE Friday, 30th June 1978
2     PLAC Vienna,Austria
1   RIN 123

0 @F45@ FAM
1   WIFE @I79@
1   DIV Y
1   MARR
2     DATE Sunday, 19th September 1971
1   RIN 124

0 TRLR
