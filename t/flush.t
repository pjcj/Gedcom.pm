#!/usr/local/bin/perl -w

# Copyright 1998-2017, Paul Johnson (paul@pjcj.net)

# This software is free.  It is licensed under the same terms as Perl itself.

# The latest version of this software should be available from my homepage:
# http://www.pjcj.net

# Version 1.20 - 17th September 2016

use strict;

use lib -d "t" ? "t" : "..";

use Basic (resolve => "unresolve_xrefs", flush => 1);
