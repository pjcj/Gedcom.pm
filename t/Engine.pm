#!/usr/local/bin/perl -w

# Copyright 1999-2000, Paul Johnson (pjcj@cpan.org)

# This software is free.  It is licensed under the same terms as Perl itself.

# The latest version of this software should be available from my homepage:
# http://www.pjcj.fsnet.co.uk

# Version 1.07 - 14th March 2000

use strict;

require 5.005;

package Engine;

use vars qw($VERSION);
$VERSION = "1.07";

use Gedcom 1.07;

sub test
{
  my $class = shift;
  my (%args) = @_;

  die "subroutine not specified" unless defined $args{subroutine};

  $args{gedcom_file} = (-d "t" ? "" : "../") . "royal.ged"
    unless defined $args{gedcom_file};
  $args{read_only} = 1
    unless defined $args{read_only};

  my $ged = Gedcom->new(%args);

  $args{subroutine}->($ged, %args)
}

sub import
{
  my $class = shift;
  $class->test(@_) if @_;
}

1;
