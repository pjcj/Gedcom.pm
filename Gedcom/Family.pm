# Copyright 1998-1999, Paul Johnson (pjcj@transeda.com)

# This software is free.  It is licensed under the same terms as Perl itself.

# The latest version of this software should be available from my homepage:
# http://www.transeda.com/pjcj

# documentation at __END__

use strict;

require 5.004;

package Gedcom::Family;

use Gedcom::Record 1.01;

BEGIN
{
  use vars qw($VERSION @ISA);
  $VERSION = "1.01";
  @ISA = qw( Gedcom::Record );
}

1;

__END__

=head1 NAME

Gedcom::Family - a class to manipulate Gedcom families

Version 1.01 - 27th April 1999

=head1 SYNOPSIS

  use Gedcom::Family;

=head1 DESCRIPTION

A selection of subroutines to handle families in a gedcom file.

Derived from Gedcom::Record.

=head1 HASH MEMBERS

None.

=head1 METHODS

None yet.

=cut
