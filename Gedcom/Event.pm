# Copyright 1999-2000, Paul Johnson (pjcj@cpan.org)

# This software is free.  It is licensed under the same terms as Perl itself.

# The latest version of this software should be available from my homepage:
# http://www.transeda.com/pjcj

# documentation at __END__

use strict;

require 5.005;

package Gedcom::Event;

use Gedcom::Record 1.06;

use vars qw($VERSION @ISA);
$VERSION = "1.06";
@ISA     = qw( Gedcom::Record );

# sub type
# {
#   my $self = shift;
#   $self->tag_value("TYPE")
# }

# sub date
# {
#   my $self = shift;
#   $self->tag_value("DATE")
# }

# sub place
# {
#   my $self = shift;
#   $self->tag_value("PLAC")
# }

1;

__END__

=head1 NAME

Gedcom::Event - a module to manipulate Gedcom events

Version 1.06 - 13th February 2000

=head1 SYNOPSIS

  use Gedcom::Event;

=head1 DESCRIPTION

A selection of subroutines to handle events in a gedcom file.

Derived from Gedcom::Record.

=head1 HASH MEMBERS

None.

=head1 METHODS

None yet.

=head2 Individual functions

=cut
