require 5.004;

use ExtUtils::MakeMaker;

WriteMakefile
(
  'NAME'         => 'Gedcom',
  'VERSION_FROM' => 'Gedcom.pm',
);

my $author = 'pjcj@transeda.com';

my @command = ("perlbug", "-a", $author,
                          "-s", "Installation of Gedcom 1.00",
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
  print "May I send a message to the author, Paul Johnson ($author)\n",
        "to indicate that you are using this module?   yes or no [yes] ";
  my $rep = <>;
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
