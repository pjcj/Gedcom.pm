#!/usr/local/bin/perl -w

# Copyright 1998-1999, Paul Johnson (pjcj@transeda.com)

# This software is free.  It is licensed under the same terms as Perl itself.

# The latest version of this software should be available from my homepage:
# http://www.transeda.com/pjcj

# Version 1.011 - 28th April 1999

use strict;

require 5.004;

use ExtUtils::MakeMaker;

my $Version = "1.02";
my $Date    = "5th May 1999";

open(M, "MANIFEST") or die "Cannot open MANIFEST: $!";
my @files    = map { split } <M>;
my @versions = grep { $_ ne "README" && $_ ne "Makefile.PL" } @files;
close(M) or die "Cannot close MANIFEST: $!";

WriteMakefile
(
  NAME    => "Gedcom",
  VERSION => $Version,
  DIR     => [],
  dist    => { COMPRESS => "gzip --best --force" },
  clean   => { FILES => join " ",  map { "$_.version" } @versions },
  depend  => { distdir => "@files" },
);

eval "use Date::Manip";
unless ($INC{"Date/Manip.pm"})
{
  print  <<EOM;

Date::Manip is required to use the Gedcom function normalise_dates().
This function will be unavailable until you install this module,
available from CPAN.  In the meantime, you may continue to use the rest
of Gedcom.pm.
EOM
}

sub MY::postamble
{
  qq[
SET_VERSION = \$(PERL) -pi.version \\
  -e 's/(^\\s*\\\$\$VERSION = ")\\d+\\.\\d+(";)/\$\${1}$Version\$\$2/;' \\
  -e 's/(Version )\\d+\\.\\d+( - ).*/\$\${1}$Version\$\${2}$Date/;' \\
  -e 's/(^\\s*use Gedcom(?:::\\w+)*\\s+)\\d+\\.\\d+;/\$\${1}$Version;/;'

tags : @files
\t ptags @files

grammar :
\t \$(PERL) parse_grammar gedcom-5.5.grammar
\t \$(SET_VERSION) -e 's/^ +//' Gedcom/Grammar_5_5.pm

@versions : Makefile.PL
\t \$(SET_VERSION) @versions

README : Gedcom.pm
\t TERMCAP= COLUMNS=80 pod2text Gedcom.pm | \\
  \$(PERL) -n \\
  -e 'print if (/NAME/ ... /^[A-Z ]+\$\$/) =~ /^\\d+\$\$/;' \\
  -e 'print if (/DESCRIPTION/ ... /^[A-Z ]+\$\$/) =~ /^\\d+\$\$/;' \\
  > README
  ]
}

my $author = 'pjcj@transeda.com';

my @command = ("perlbug", "-a", $author,
                          "-s", "Installation of Gedcom $Version",
                          "-okay");

my $message = <<EOM;

I like to have some idea of the distribution of this software.  To that
end I would be very grateful for mail from you.  This will be used only
to satisfy my curiosity and to help me make decisions which may involve
changes to the interface etc.

The command: @command
will provide all the information I need.

EOM

print $message;

if (-t STDIN)
{
  my $mess = <<EOM;

May I send a message to the author, Paul Johnson ($author), using the
above command, to indicate that you are using this module?   yes or no [yes] 
EOM

  chomp $mess;
  print $mess;
  my $rep = <STDIN>;
  if ($rep =~ /^n/)
  {
    print <<EOM;

If you are able to send a message in the future, please do so with the
command: @command

EOM
  }
  else
  {
    system @command;
    print "\n@command failed: status $?\n\nPlease send a message manually\n\n"
      if $?;
  }
}
