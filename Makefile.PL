#!/usr/local/bin/perl -w

# Copyright 1998-2002, Paul Johnson (pjcj@cpan.org)

# This software is free.  It is licensed under the same terms as Perl itself.

# The latest version of this software should be available from my homepage:
# http://www.pjcj.net

use strict;

require 5.005;

use ExtUtils::MakeMaker;

$| = 1;

my $Version = "1.11";
my $Date    = "7th April 2002";
my $Author  = 'pjcj@cpan.org';

my @perlbug = ("perlbug", "-a", $Author,
                          "-s", "Installation of Gedcom $Version");

my $Perlbug = join " ", map { / / ? "'$_'" : $_ } @perlbug;


open M, "MANIFEST" or die "Cannot open MANIFEST: $!";
my @files    = map { split } <M>;
my @versions = grep { $_ ne "README" && $_ ne "Makefile.PL" } @files;
close M or die "Cannot close MANIFEST: $!";

$ExtUtils::MakeMaker::Verbose = 0;

WriteMakefile
(
  NAME     => "Gedcom",
  VERSION  => $Version,
  AUTHOR   => 'Paul Johnson (pjcj@cpan.org)',
  ABSTRACT => "Interface to genealogy GEDCOM files",
  DIR      => [],
  PM       => { map {($_ => '$(INST_LIBDIR)/' . $_)} grep { /\.pm/ } @files },
  dist     => { COMPRESS => "gzip --best --force" },
  clean    => { FILES => join " ",  map { "$_.version" } @versions },
  depend   => { distdir => "@files" },
);

print "\n";
print "checking for Date::Manip.pm........ ";

eval "use Date::Manip";
if (my $m = $INC{"Date/Manip.pm"})
{
  print "$m\n";
}
else
{
  print  <<EOM;
not found

Date::Manip.pm is required to use the Gedcom function normalise_dates().  This
function will be unavailable until you install this module, available from CPAN.
In the meantime, you may continue to use the rest of Gedcom.pm.

EOM
}

print "checking for Text::Soundex.pm...... ";

eval "use Text::Soundex";
if (my $m = $INC{"Text/Soundex.pm"})
{
  print "$m\n";
}
else
{
  print  <<EOM;
not found

Text::Soundex.pm is required to use the Gedcom function soundex().  This
function will be unavailable until you install this module, available from CPAN.
In the meantime, you may continue to use the rest of Gedcom.pm.

EOM
}

print "checking for Parse::RecDescent.pm.. ";

eval "use Parse::RecDescent";
if (my $m = $INC{"Parse/RecDescent.pm"})
{
  print "$m\n";
}
else
{
  print  <<EOM;
not found

Parse::RecDescent.pm is required to use the Gedcom program lines2perl.  This
program will be unavailable until you install this module, available from CPAN.
In the meantime, you may continue to use the rest of Gedcom.pm.

EOM
}

print "checking for Roman.pm.............. ";

eval "use Roman";
if (my $m = $INC{"Roman.pm"})
{
  print "$m\n";
}
else
{
  print  <<EOM;
not found

Roman.pm is required to use the Gedcom function roman().  This function may be
called from lines2perl if your LifeLines program calls roman().  This function
will be unavailable until you install this module, available from CPAN.  In the
meantime, you may continue to use the rest of Gedcom.pm.

EOM
}

print "checking for working IO::Handle.... ";

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

print <<EOM if 0;

--------------------------------------------------------------------------------

I like to have some idea of the distribution of this software.  To that end I
would be very grateful for mail from you.  This will be used only to satisfy my
curiosity and to help me make decisions which may involve changes to the
module.

If you can run perlbug you can send me a success report with "make ok".
Failure reports with "make nok" are also appreciated.

EOM

print <<EOM;

--------------------------------------------------------------------------------

If you have any questions or comments please send a message to the perl-gedcom
mailing list, details of which are available in the README file.

EOM

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

ppm : ppd pure_all
\t tar cf Gedcom.tar blib
\t gzip --best --force Gedcom.tar
\t \$(PERL) -pi.bak \\
  -e 's/(OS NAME=")[^"]*/\$\$1MSWin32/;' \\
  -e 's/(ARCHITECTURE NAME=")[^"]*/\$\$1MSWin32-x86-multi-thread/;' \\
  -e 's/(CODEBASE HREF=")[^"]*/\$\$1Gedcom.tar.gz/;' \\
  Gedcom.ppd

ok :
\t \@$Perlbug -okay  || echo "Please send your report manually to $Author"

nok :
\t \@$Perlbug -nokay || echo "Please send your report manually to $Author"
  ]
}
