#!/usr/local/bin/perl -w

# Copyright 1998-2001, Paul Johnson (pjcj@cpan.org)

# This software is free.  It is licensed under the same terms as Perl itself.

# The latest version of this software should be available from my homepage:
# http://www.transeda.com/pjcj

# Version 1.09 - 12th February 2001

use strict;

use lib -d "t" ? "t" : "..";

use Basic (create_grammar => "gedcom-5.5.grammar",
           resolve        => "unresolve_xrefs",
           read_only      => 0);
