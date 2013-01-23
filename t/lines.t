#!/usr/local/bin/perl -w

# Copyright 1999-2013, Paul Johnson (paul@pjcj.net)

# This software is free.  It is licensed under the same terms as Perl itself.

# The latest version of this software should be available from my homepage:
# http://www.pjcj.net

# Version 1.18 - 24th January 2013

# This is really just a test of the lifelines testing mechanism, but it
# also serves as a very basic lifelines test.

use strict;

use lib -d "t" ? "t" : "..";

use Lines;

use File::Spec;

my $report = File::Spec->catfile((-d "t" ? ("t/") : ()), "lines", "lines");

Lines->test(tests          => 10,
            report         => $report,
            lines_report   => "$report.l",
            report_command => $ENV{lines} ? "$report.l\n" : undef,
            generate       => $ENV{generate},
            perl_program   => "$report.plx",
            perl_report    => "$report.p",
            perl_command   => "");
