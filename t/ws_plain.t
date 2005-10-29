#!/usr/bin/perl -w

# Copyright 1999-2005, Paul Johnson (pjcj@cpan.org)

# This software is free.  It is licensed under the same terms as Perl itself.

# The latest version of this software should be available from my homepage:
# http://www.pjcj.net

# Version 1.15 - 3rd May 2005

use strict;

use lib -d "t" ? "t" : "..";

BEGIN
{
    eval
    q{
        use Apache::Test;
        use Apache::TestUtil;
        use Apache::TestRequest qw( GET_BODY GET );
        use LWP::Simple;
    };

    if (my $e = $@)
    {
        eval "use Test::More skip_all => q[mod_perl not fully installed [$e]]";
    }
}

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
    [ "/i9/birth",            rs <<"EOR"                                 ],
1   BIRT
2     DATE Wednesday, 21st April 1926
2     PLAC 17 Bruton St.,London,W1,England
EOR
);

plan tests => scalar @tests;

for (@tests)
{
    my $q = $root . $_->[0];
    # t_debug("-- $q");
    # t_debug("++ ", get($q));
    ok t_cmp get($q), $_->[1], $q;
}
