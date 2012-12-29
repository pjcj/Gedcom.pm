#!/usr/local/bin/perl -w

# Copyright 1999-2012, Paul Johnson (paul@pjcj.net)

# This software is free.  It is licensed under the same terms as Perl itself.

# The latest version of this software should be available from my homepage:
# http://www.pjcj.net

# Version 1.17 - 29th December 2012

use strict;

use lib -d "t" ? "t" : "..";

use Basic (resolve => "resolve_xrefs", read_only => 1);
