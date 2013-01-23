#!/usr/local/bin/perl -w

# Copyright 1999-2013, Paul Johnson (paul@pjcj.net)

# This software is free.  It is licensed under the same terms as Perl itself.

# The latest version of this software should be available from my homepage:
# http://www.pjcj.net

# Version 1.18 - 24th January 2013

use strict;

use lib -d "t" ? "t" : "..";

use Basic (resolve => "resolve_xrefs", read_only => 1);
