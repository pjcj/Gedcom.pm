#!/usr/local/bin/perl -w

# Copyright 1999-2000, Paul Johnson (pjcj@cpan.org)

# This software is free.  It is licensed under the same terms as Perl itself.

# The latest version of this software should be available from my homepage:
# http://www.pjcj.fsnet.co.uk

# Version 1.07 - 14th March 2000

# This is really just a test of the lifelines testing mechanism, but it
# also serves as a very basic lifelines test.

use strict;

use lib -d "t" ? "t" : "..";

use Lines;

my $report = (-d "t" ? "t/" : "") . "lines/lines";

Lines->test(tests          => 9,
            report         => $report,
            lines_report   => "$report.l",
            report_command => $ENV{lines} ? "$report.l\n" : undef,
            generate       => $ENV{generate},
            perl_program   => "$report.plx",
            perl_report    => "$report.p",
            perl_command   => "");
