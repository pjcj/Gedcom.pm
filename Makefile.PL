#!/usr/bin/perl -w

# Copyright 1998-2013, Paul Johnson (paul@pjcj.net)

# This software is free.  It is licensed under the same terms as Perl itself.

# The latest version of this software should be available from my homepage:
# http://www.pjcj.net

use strict;

require 5.005;

use ExtUtils::MakeMaker;
use ExtUtils::Manifest "maniread";

if (0)  # For automating webservices testing
{
    eval
    q{
        use Apache::TestMM qw(test clean);
        Apache::TestMM::filter_args();
        Apache::TestMM::generate_script("t/TEST");
    };
}

$| = 1;

my $Version  = "1.19";
my $Date     = "18th August 2013";
my $Author   = 'paul@pjcj.net';

my @perlbug  = ("perlbug", "-a", $Author,
                           "-s", "Installation of Gedcom $Version");

my $Perlbug  = join " ", map { / / ? "'$_'" : $_ } @perlbug;

my @files    = sort keys %{maniread()};
my @versions = grep { !/README|travis|Makefile\.PL/ } @files;

$ExtUtils::MakeMaker::Verbose = 0;

WriteMakefile
(
    NAME       => "Gedcom",
    VERSION    => $Version,
    AUTHOR     => 'Paul Johnson (paul@pjcj.net)',
    ABSTRACT   => "Interface to genealogy GEDCOM files",
    DIR        => [],
    EXE_FILES  => [ "cgi-bin/gedcom.cgi" ],
    PREREQ_PM  => { "Text::Soundex" => 0 },
    META_MERGE => {
        license => [ "perl_5" ],
        release_status => "stable",
        prereqs => {
            runtime => {
                recommends => {
                    "Date::Manip"       => 0,
                    "Parse::RecDescent" => 0,
                    "Roman"             => 0,
                },
            },
        },
        resources => {
            license    => [ "http://dev.perl.org/licenses/" ],
            bugtracker => {
                web  => "https://github.com/pjcj/Gedcom.pm/issues",
            },
            repository => {
                type => "git",
                url  => "http://github.com/pjcj/Gedcom.pm",
                web  => "http://github.com/pjcj/Gedcom.pm",
            },
            x_mailing_list => "http://lists.perl.org/list/perl-gedcom.html",
        },
        "meta-spec" => {
            version => 2,
            url     => "http://search.cpan.org/perldoc?CPAN::Meta::Spec",
        },
    },
    dist       => { COMPRESS => "gzip --best --force" },
    clean      => { FILES => join " ",  map { "$_.version" } @versions },
    depend     => { distdir => "@files" },
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
    print <<EOM;
not found

Date::Manip.pm is required to use the Gedcom function normalise_dates().  This
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
    print <<EOM;
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
    print <<EOM;
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
tags : @files
\t ptags @files

grammar : pure_all gedcom-5.5.grammar gedcom-5.5.1.grammar
\t \$(PERL) -Mblib parse_grammar gedcom-5.5.grammar
\t \$(PERL) -Mblib parse_grammar gedcom-5.5.1.grammar
\t \$(PERL) utils/makeh set_version $Version "$Date" lib/Gedcom/Grammar_5_5*.pm
\t \$(PERL) -pi -e 's/^ +//' lib/Gedcom/Grammar_5_5*.pm

@versions : Makefile.PL
\t \$(PERL) utils/makeh set_version $Version "$Date" @versions
\t \$(MAKE) grammar README

README : lib/Gedcom.pm
\t TERMCAP= COLUMNS=80 pod2text -s lib/Gedcom.pm | \\
  \$(PERL) utils/makeh make_readme > README

# Webservies section

restart : all
\t t/TEST -stop && rm -f t/logs/*log && t/TEST -start \$(TEST_OPTIONS)

restart_cover : all
\t t/TEST -stop && cover && rm -f t/logs/*log && \\
   t/TEST -defines COVER -one-process -start \$(TEST_OPTIONS)

stop : all
\t t/TEST -stop

runtestcover : all
\t rm -f t/logs/*log && \\
   DEVEL_COVER=1 t/TEST -defines COVER -one-process -verbose \$(TEST_OPTIONS) && \\
   cover -report html_basic

mytestcover : all
\t cover -delete && \\
   rm -f t/logs/*log && \\
   DEVEL_COVER=1 t/TEST -defines COVER -one-process \$(TEST_OPTIONS) && \\
   cover -report html_basic

# cover : mytestcover

cgi : all install
\t cp `dirname \$(PERL)`/gedcom.cgi cgi-bin && \\
   rm *.ged && \\
   ln -s ../ged/* .

# Reports

ok :
\t \@$Perlbug -okay  || echo "Please send your report manually to $Author"

nok :
\t \@$Perlbug -nokay || echo "Please send your report manually to $Author"
    ]
}
