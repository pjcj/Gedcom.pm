#!/usr/local/bin/perl -w

# Copyright 1999-2000, Paul Johnson (pjcj@cpan.org)

# This software is free.  It is licensed under the same terms as Perl itself.

# The latest version of this software should be available from my homepage:
# http://www.pjcj.fsnet.co.uk

# Version 1.07 - 14th March 2000

use strict;

use lib -d "t" ? "t" : "..";

use Basic (resolve => "resolve_xrefs", read_only => 0);
