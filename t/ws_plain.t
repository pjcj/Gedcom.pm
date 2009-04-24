#!/usr/bin/perl -w

# Copyright 1999-2009, Paul Johnson (paul@pjcj.net)

# This software is free.  It is licensed under the same terms as Perl itself.

# The latest version of this software should be available from my homepage:
# http://www.pjcj.net

# Version 1.16 - 24th April 2009

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

my $ws   = "/ws/plain/royal";
my $root = "http://$hostport$ws";

sub ws { join "", map "$ws/$_\n",                  @_ }
sub rs { join "", map {chomp(my $t = $_); "$t\n" } @_ }

my @tests =
(
    [ "?search=Elizabeth_II", ws "I9"                                    ],
    [ "/i9/name",             rs "Elizabeth_II Alexandra Mary /Windsor/" ],
    [ "/i9/children",         ws qw( I11 I15 I19 I23 )                   ],
    [ "/i9/birth/date",       "Wednesday, 21st April 1926\n"             ],
    [ "/i9/birth",            rs <<'EOR'                                 ],
1   BIRT
2     DATE Wednesday, 21st April 1926
2     PLAC 17 Bruton St.,London,W1,England
EOR
    [ "/i9",                  rs <<'EOR'                                 ],
0 @I9@ INDI
1   NAME Elizabeth_II Alexandra Mary/Windsor/
1   TITL Queen of England
1   SEX F
1   BIRT
2     DATE Wednesday, 21st April 1926
2     PLAC 17 Bruton St.,London,W1,England
1   FAMS @F6@
1   FAMC @F4@
1   RIN 10

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

is get("http://$hostport/ws/plain/"),
   "No GEDCOM file specified\n",
   "No GEDCOM file specified";

like get("http://$hostport/ws/plain/__error__"),
     qr!Can't open file .*/__error__.ged: No such file or directory!,
     "GEDCOM file does not exist";
