#!/usr/local/bin/perl -w

# Copyright 1999-2004, Paul Johnson (pjcj@cpan.org)

# This software is free.  It is licensed under the same terms as Perl itself.

# The latest version of this software should be available from my homepage:
# http://www.pjcj.net

# Version 1.14 - 5th April 2004

use strict;

require 5.005;

package Lines;

use File::Basename;
use Test;

use vars qw($VERSION);
$VERSION = "1.14";

use Gedcom 1.14;

sub test
{
  my $class = shift;
  my (%args) = @_;

  die "tests not specified" unless defined $args{tests};
  plan tests => $args{tests};

  $args{gedcom_file} = (-d "t" ? "" : "../") ."royal.ged"
    unless defined $args{gedcom_file};

  die "report not specified" unless defined $args{report};

  if (defined $args{report_command})
  {
    $args{lines} = "/home/pjcj/ged/other/lines/bin/lines302"
      unless defined $args{lines};

    if ( -x $args{lines} && open(L, "|$args{lines}"))
    {
      my $db = basename($args{gedcom_file}, "\.ged");
      system "rm -rf $db";
      print L "$db\n";
      print L "yur$args{gedcom_file}\n ";
      print L "r$args{report}\n";
      print L "$args{report_command}";
      print L "q";
      close(L) or die "Can't close <$args{lines}>";
      print "\n";
    }
  }
  ok 1;

  $args{perl_program} = "$args{report}.plx" unless defined $args{perl_program};
  if ($args{generate})
  {
    system((-d "t" ? "" : "../") .
           "lines2perl -quiet $args{report} > $args{perl_program}");
    ok $? == 0;
  }
  else
  {
    ok 1;
  }

  $args{lines_report} = "$args{report}.l" unless defined $args{lines_report};
  $args{perl_report}  = "$args{report}.p" unless defined $args{perl_report};

  die "perl_command not specified" unless defined $args{perl_command};
  my $command = "|$^X " . (-d "t" ? "" : "-I .. ") .
                "$args{perl_program} -quiet -gedcom_file $args{gedcom_file} " .
                "> $args{perl_report}";
  open P, $command or die "Can't run <$command>";
  select P;
  $| = 1;
  print P $args{perl_command};
  close(P) or die "Can't close <$args{perl_program}>";
  ok 1;

  # check the gedcom file is correct
  ok open LO, $args{lines_report};
  ok open PO, $args{perl_report};
  ok <PO>, $_ while <LO>;
  ok eof PO;
  ok close PO;
  ok close LO;
  # ok unlink $args{perl_report};
}

sub import
{
  my $class = shift;
  $class->test(@_) if @_;
}

1;
