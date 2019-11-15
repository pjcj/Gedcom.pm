#!/usr/local/bin/perl -w

# This program was generated by lines2perl, which is part of Gedcom.pm.
# Gedcom.pm is Copyright 1998-2019, Paul Johnson (paul@pjcj.net)
# Version 1.22 - 15th November 2019

# Gedcom.pm is free.  It is licensed under the same terms as Perl itself.

# The latest version of Gedcom.pm should be available from my homepage:
# http://www.pjcj.net

use strict;

require 5.005;

use diagnostics;
use integer;

use Getopt::Long;

use Gedcom::LifeLines 1.22;

my $Ged;                                                         # Gedcom object
my %Opts;                                                              # options
my $_Traverse_sub;                                     # subroutine for traverse

sub out  { print  STDERR @_ unless $Opts{quiet} }
sub outf { printf STDERR @_ unless $Opts{quiet} }

sub initialise ()
{
  die "usage: $0 -gedcom_file file.ged\n"
    unless GetOptions(\%Opts,
                      "gedcom_file=s",
                      "quiet!",
                      "validate!",
                     ) and defined $Opts{gedcom_file};
  local $SIG{__WARN__} = sub { out "\n@_" };
  out "reading...";
  $Ged = Gedcom->new
  (
    gedcom_file  => $Opts{gedcom_file},
    callback     => sub { out "." }
  );
  if ($Opts{validate})
  {
    out "\nvalidating...";
    my %x;
    my $vcb = sub
    {
     my ($r) = @_;
     my $t = $r->{xref};
     out "." if $t && !$x{$t}++;
    };
    $Ged->validate($vcb);
  }
  out "\n";
  set_ged($Ged);
}

$SIG{__WARN__} = sub
{
  out $_[0] unless $_[0] =~ /^Use of uninitialized value/
};

sub main ()
{
  display "te\"st1\n";
  display 'te\'st2';
  display &nl();
  undef
}


initialise();
main();
flush();
0

__END__

Original LifeLines program follows:

proc main ()
{
  "te\"st1\n"
  'te\'st2'
  nl()
}

