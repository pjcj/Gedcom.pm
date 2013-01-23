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
        use Test::JSON;
    };

    if (my $e = $@)
    {
        eval "use Test::More skip_all => " .
             "q[mod_perl or Test::JSON not fully installed]";
             # "q[mod_perl or Test::JSON not fully installed [$e]]";

    }
}

use Test::More;

Apache::TestRequest::module('default');

my $config   = Apache::Test::config();
my $hostport = Apache::TestRequest::hostport($config) || "";

my $ws   = "/ws/json/royal";
my $root = "http://$hostport$ws";

sub ws { join "", map "$ws/$_\n",                  @_ }
sub rs { my $r = join "", map {chomp(my $t = $_); "$t\n" } @_; chomp $r; $r }

my @tests =
(
    [ "?search=Elizabeth_II", ws "I9"                                    ],
    [ "/i9/name",             rs <<'EOR'                                 ],
{"name":"Elizabeth_II Alexandra Mary /Windsor/"}
EOR
    [ "/i9/children",         ws qw( I11 I15 I19 I23 )                   ],
    [ "/i9/birth/date",       rs <<'EOR'                                 ],
{"date":"Wednesday, 21st April 1926"}
EOR
    [ "/i9/birth",            rs <<'EOR'                                 ],
{"level":1,"tag":"BIRT","items":[{"level":2,"pointer":"","value":"Wednesday, 21st April 1926","tag":"DATE","items":[]},{"level":2,"pointer":"","value":"17 Bruton St.,London,W1,England","tag":"PLAC","items":[]}]}
EOR
    [ "/i9",                  rs <<'EOR'                                 ],
{"rec":{"xref":"I9","level":0,"tag":"INDI","items":[{"level":1,"pointer":"","value":"Elizabeth_II Alexandra Mary/Windsor/","tag":"NAME","items":[]},{"level":1,"pointer":"","value":"Queen of England","tag":"TITL","items":[]},{"level":1,"pointer":"","value":"F","tag":"SEX","items":[]},{"level":1,"tag":"BIRT","items":[{"level":2,"pointer":"","value":"Wednesday, 21st April 1926","tag":"DATE","items":[]},{"level":2,"pointer":"","value":"17 Bruton St.,London,W1,England","tag":"PLAC","items":[]}]},{"level":1,"pointer":1,"value":"F6","tag":"FAMS","items":[]},{"level":1,"pointer":1,"value":"F4","tag":"FAMC","items":[]},{"level":1,"pointer":"","value":10,"tag":"RIN","items":[]}]}}

EOR
    [ "/i0",                  "Can't get record [i0]\n"                  ],
    [ "/I9/__error__",        "Invalid action [__error__]\n"             ],
    [ "",                     "No xref or parameters specified\n"        ],
);

plan tests => scalar @tests + 2 + grep substr($_->[1], 0, 1) eq "{", @tests;

for (@tests)
{
    my $q = $root . $_->[0];
    # t_debug("-- $q");
    # t_debug("++ ", get($q));
    my $result = get($q);
    my $match  = $_->[1];
    my $json   = substr($match, 0, 1) eq "{";
    # print "match [$json][$match]\n";
    is_valid_json $result, "$q well formed" if $json;
    $json ? is_json $result, $match, "$q json matches" : is $result, $match, $q;
}

is get("http://$hostport/ws/json/"),
   "No GEDCOM file specified\n",
   "No GEDCOM file specified";

like get("http://$hostport/ws/json/__error__"),
     qr!Can't open file .*/__error__.ged: No such file or directory!,
     "GEDCOM file does not exist";
