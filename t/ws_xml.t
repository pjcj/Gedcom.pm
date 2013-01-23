#!/usr/bin/perl -w

# Copyright 1999-2013, Paul Johnson (paul@pjcj.net)

# This software is free.  It is licensed under the same terms as Perl itself.

# The latest version of this software should be available from my homepage:
# http://www.pjcj.net

# Version 1.18 - 24th January 2013

use strict;

use lib -d "t" ? "t" : "..";

BEGIN
{
    unless ($ENV{DEVEL_COVER_WS_TESTS})
    {
        eval "use Test::More skip_all => " .
             "q[\$DEVEL_COVER_WS_TESTS is not set]";

    }

    eval
    q{
        use 5.006;
        use Apache::Test ":withtestmore";
        use Apache::TestUtil;
        use LWP::Simple;
    };

    if (my $e = $@)
    {
        eval "use Test::More skip_all => q[mod_perl not fully installed]";
        #eval "use Test::More skip_all => q[mod_perl not fully installed [$e]]";
    }
}

use Test::More;

Apache::TestRequest::module('default');

my $config   = Apache::Test::config();
my $hostport = Apache::TestRequest::hostport($config) || "";

my $ws   = "/ws/xml/royal";
my $root = "http://$hostport$ws";

sub ws { join "", map "$ws/$_\n",                  @_ }
sub rs { join "", map {chomp(my $t = $_); "$t\n" } @_ }

my @tests =
(
    [ "?search=Elizabeth_II", ws "I9"                                    ],
    [ "/i9/name",             rs <<'EOR'                                 ],
<NAME>Elizabeth_II Alexandra Mary /Windsor/</NAME>
EOR
    [ "/i9/children",         ws qw( I11 I15 I19 I23 )                   ],
    [ "/i9/birth/date",       rs <<'EOR'                                 ],
<DATE>Wednesday, 21st April 1926</DATE>
EOR
    [ "/i9/birth",            rs <<'EOR'                                 ],
<BIRT>
  <DATE>Wednesday, 21st April 1926</DATE>
  <PLAC>17 Bruton St.,London,W1,England</PLAC>
</BIRT>
EOR
    [ "/i9",                  rs <<'EOR'                                 ],
<INDI ID="I9">
  <NAME>Elizabeth_II Alexandra Mary/Windsor/</NAME>
  <TITL>Queen of England</TITL>
  <SEX>F</SEX>
  <BIRT>
    <DATE>Wednesday, 21st April 1926</DATE>
    <PLAC>17 Bruton St.,London,W1,England</PLAC>
  </BIRT>
  <FAMS REF="F6"/>
  <FAMC REF="F4"/>
  <RIN>10</RIN>
</INDI>

EOR
    [ "/i0",                  "Can't get record [i0]\n"                  ],
    [ "/I9/__error__",        "Invalid action [__error__]\n"             ],
    [ "",                     "No xref or parameters specified\n"        ],
);

plan tests => scalar @tests + 2;

for (@tests)
{
    my $q = $root . $_->[0];
    # t_debug("-- $q");
    # t_debug("++ ", get($q));
    is get($q), $_->[1], $q;
}

is get("http://$hostport/ws/xml/"),
   "No GEDCOM file specified\n",
   "No GEDCOM file specified";

like get("http://$hostport/ws/xml/__error__"),
     qr!Can't open file .*/__error__.ged: No such file or directory!,
     "GEDCOM file does not exist";
