#!/usr/local/bin/perl -w

# Copyright 1998-1999, Paul Johnson (pjcj@transeda.com)

# This software is free.  It is licensed under the same terms as Perl itself.

# The latest version of this software should be available from my homepage:
# http://www.transeda.com/pjcj

use strict;

require 5.005;

use ExtUtils::MakeMaker;

$| = 1;

my $Version = "1.05";
my $Date    = "20th July 1999";

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

print "\n";
print "checking for Date::Manip..........";

eval "use Date::Manip";
if (my $m = $INC{"Date/Manip.pm"})
{
  print "$m\n";
}
else
{
  print  <<EOM;
not found

Date::Manip is required to use the Gedcom function normalise_dates().  This
function will be unavailable until you install this module, available from CPAN.
In the meantime, you may continue to use the rest of Gedcom.pm.

EOM
}

print "checking for Text::Soundex........";

eval "use Text::Soundex";
if (my $m = $INC{"Text/Soundex.pm"})
{
  print "$m\n";
}
else
{
  print  <<EOM;
not found

Text::Soundex is required to use the Gedcom function soundex().  This function
will be unavailable until you install this module, available from CPAN.  In the
meantime, you may continue to use the rest of Gedcom.pm.

EOM
}

print "checking for Parse::RecDescent....";

eval "use Parse::RecDescent";
if (my $m = $INC{"Parse/RecDescent.pm"})
{
  print "$m\n";
}
else
{
  print  <<EOM;
not found

Parse::RecDescent is required to use the Gedcom program lines2perl.  This
program will be unavailable until you install this module, available from CPAN.
In the meantime, you may continue to use the rest of Gedcom.pm.

EOM
}

print "checking for working IO::Handle...";

eval <<'EOE';
  use FileHandle;
  my $fh = FileHandle->new("Makefile.PL");
  $fh->getline;
  $fh->input_line_number;
EOE
if ($@)
{
  print <<'EOM';
broken

You have a broken IO::Handle module.  In particular, the input_line_number
method causes an error.  Gedcom.pm will work around the problem, but if you
experience other problems with this function, or your use of $., you may wish to
solve the problem.

Perl 5.005_03 and (I believe) some developer releases have this problem, as does
IO.pm version 1.20.  The problem is fixed as from 5.005_57.  If you would like
to patch your Perl, my patch is available at
http://www.xray.mpe.mpg.de/mailing-lists/perl5-porters/1999-04/msg02366.html
or send me mail.
EOM
}
else
{
  print "working\n";
}

print "\n";

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

my $command = join " ", map { / / ? "'$_'" : $_ } @command;

my $message = <<EOM;
I like to have some idea of the distribution of this software.  To that end I
would be very grateful for mail from you.  This will be used only to satisfy my
curiosity and to help me make decisions which may involve changes to the
interface etc.

The command: $command
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

If you are able to send a message in the future, please do so with the command:
$command

EOM
  }
  else
  {
    system @command;
    print "\n$command failed: status $?\n\nPlease send a message manually\n\n"
      if $?;
  }
}

print <<EOM;
If you have any questions or comments, mailing list details are available in the
README file, or send mail to me directly.

EOM
