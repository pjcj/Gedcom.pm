#!/usr/local/bin/perl -w

# Copyright 1999-2004, Paul Johnson (pjcj@cpan.org)

# This software is free.  It is licensed under the same terms as Perl itself.

# The latest version of this software should be available from my homepage:
# http://www.pjcj.net

# Version 1.14 - 5th April 2004

use strict;

require 5.005;

use Test ();

BEGIN { Test::plan tests => 161 }

use lib -d "t" ? "t" : "..";

use Gedcom 1.14;
use Engine;

sub ok
{
    my @a = @_;
    s/[\r\n]+$/\n/ for @a;
    Test::ok(@a)
}

my $Test = sub
{
  my $ged = shift;
  ok($ged);

  my @birthdates = <DATA>;
  my @b = @birthdates;

  # Look at each individual.
  for my $i ($ged->individuals)
  {
    # Look at each birth record.
    # There will generally be one birth record, but there may be none,
    # or more than one.
    for my $b ($i->birth)
    {
      # Look at each date in the birth record.
      # Again, there will generally be only one date, but there may be
      # none, or more than one.
      for my $d ($b->date)
      {
        ok($i->name . " was born on $d\n", shift @b);
      }
    }
  }

  # Here's a newer, better way of doing the same thing.
  @b = @birthdates;
  for my $i ($ged->individuals)
  {
    for my $bd ($i->get_value(qw(birth date)))
    {
      ok($i->name . " was born on $bd\n", shift @b);
    }
  }

  ok($ged->get_individual("Edward_VIII")->get_value(qw(birth date)),
     "Saturday, 23rd June 1894");

  my $i = $ged->get_individual("B1 C1");
  ok($i->get_value("birth date"), "Saturday, 1st January 2000");
  ok($i->get_value(["birth", 2], "date"), "Sunday, 2nd January 2000");
  ok($i->birth(2)->date, "Sunday, 2nd January 2000");
};

Engine->test(subroutine => $Test);

__DATA__
Edward_VII /Wettin/ was born on Tuesday, 9th November 1841
Alexandra of_Denmark "Alix" // was born on Sunday, 1st December 1844
George_V /Windsor/ was born on Saturday, 3rd June 1865
Mary_of_Teck (May) // was born on Sunday, 26th May 1867
Edward_VIII /Windsor/ was born on Saturday, 23rd June 1894
Bessiewallis /Warfield/ was born on 1896
George_VI /Windsor/ was born on Saturday, 14th December 1895
Elizabeth Angela Marguerite /Bowes-Lyon/ was born on Saturday, 4th August 1900
Elizabeth_II Alexandra Mary /Windsor/ was born on Wednesday, 21st April 1926
Philip /Mountbatten/ was born on Friday, 10th June 1921
Charles Philip Arthur /Windsor/ was born on Sunday, 14th November 1948
Diana Frances /Spencer/ was born on Saturday, 1st July 1961
William Arthur Philip /Windsor/ was born on Monday, 21st June 1982
Henry Charles Albert /Windsor/ was born on Saturday, 15th September 1984
Anne Elizabeth Alice /Windsor/ was born on Tuesday, 15th August 1950
Mark Anthony Peter /Phillips/ was born on Wednesday, 22nd September 1948
Peter Mark Andrew /Phillips/ was born on Tuesday, 15th November 1977
Zara Anne Elizabeth /Phillips/ was born on Friday, 15th May 1981
Andrew Albert Christian /Windsor/ was born on Friday, 19th February 1960
Sarah Margaret /Ferguson/ was born on Thursday, 15th October 1959
Beatrice Elizabeth Mary /Windsor/ was born on Monday, 8th August 1988
Eugenie Victoria Helena /Windsor/ was born on Friday, 23rd March 1990
Edward Anthony Richard /Windsor/ was born on Tuesday, 10th March 1964
Margaret Rose /Windsor/ was born on Thursday, 21st August 1930
Anthony Charles Robert /Armstrong-Jones/ was born on Friday, 7th March 1930
David Albert Charles /Armstrong-Jones/ was born on Friday, 3rd November 1961
Sarah Frances Elizabeth /Armstrong-Jones/ was born on Friday, 1st May 1964
Mary /Windsor/ was born on Sunday, 25th April 1897
Henry George Charles /Lascelles/ was born on 1882
George Earl_of_Harewood /Lascelles/ was born on 1923
Marion (Maria) Donata /Stein/ was born on 1926
David /Lascelles/ was born on 1950
Emily // was born on 1976
Benjamin // was born on 1978
Alexander /Lascelles/ was born on 1980
Edward /Lascelles/ was born on 1982
James /Lascelles/ was born on 1953
Sophie /Lascelles/ was born on 1973
Rowan /Lascelles/ was born on 1977
Jeremy /Lascelles/ was born on 1955
Thomas /Lascelles/ was born on 1982
Ellen /Lascelles/ was born on 1984
Patricia /Tuckwell/ was born on 1923
Mark /Lascelles/ was born on 1964
Gerald /Lascelles/ was born on 1924
Angela /Dowding/ was born on 1919
Henry /Lascelles/ was born on 1953
Elizabeth Collingwood /Colvin/ was born on 1924
Martin /Lascelles/ was born on 1963
Henry William Frederick /Windsor/ was born on Saturday, 31st March 1900
Alice Christabel /Montagu-Douglas/ was born on Wednesday, 25th December 1901
William Henry Andrew /Windsor/ was born on Thursday, 18th December 1941
Richard Alexander Walter /Windsor/ was born on Saturday, 26th August 1944
Birgitte of_Denmark /von_Deurs/ was born on 1947
Alexander Patrick Gregers // was born on Thursday, 24th October 1974
Davina Elizabeth Alice /Windsor/ was born on Saturday, 19th November 1977
Rose Victoria Birgitte /Windsor/ was born on Saturday, 1st March 1980
George Edward Alexander /Windsor/ was born on Saturday, 20th December 1902
Marina of_Greece // was born on Friday, 30th November 1906
Edward George Nicholas /Windsor/ was born on Monday, 9th September 1935
Katharine /Worsley/ was born on 1933
George Philip of_St._Andrews /Windsor/ was born on Tuesday, 26th June 1962
Sylvana /Tomaselli/ was born on ABT    1957
Helen Marina Lucy /Windsor/ was born on Tuesday, 28th April 1964
Nicholas Charles Edward /Windsor/ was born on Saturday, 25th July 1970
Alexandra /Windsor/ was born on Friday, 25th December 1936
Angus /Ogilvy/ was born on 1928
James Robert Bruce /Ogilvy/ was born on Saturday, 29th February 1964
Marina Victoria Alexandra /Ogilvy/ was born on Sunday, 31st July 1966
Paul /Mowatt/ was born on ABT    1962
/Mowatt/ was born on Saturday, 26th May 1990
Michael /Windsor/ was born on Saturday, 4th July 1942
Marie-Christine /von_Reibnitz/ was born on Monday, 15th January 1945
Frederick /Windsor/ was born on Friday, 6th April 1979
Gabriella Marina Alexandra /Windsor/ was born on Thursday, 23rd April 1981
John Charles Francis /Windsor/ was born on Wednesday, 12th July 1905
B1 C1 was born on Saturday, 1st January 2000
B1 C1 was born on Sunday, 2nd January 2000
