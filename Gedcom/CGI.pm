# Copyright 2001-2005, Paul Johnson (pjcj@cpan.org)

# This software is free.  It is licensed under the same terms as Perl itself.

# The latest version of this software should be available from my homepage:
# http://www.pjcj.net

# documentation at __END__

use strict;

require 5.005;

package Gedcom::CGI;

use CGI qw(:cgi :html);

use Gedcom 1.15;

use vars qw($VERSION);
$VERSION = "1.15";

sub gedcom
{
  my ($gedcom_file) = @_;
  $gedcom_file = "/home/pjcj/g/perl/dev/Gedcom/$gedcom_file.ged";
  Gedcom->new(gedcom_file => $gedcom_file,
              read_only   => 1);
}

sub dates
{
  my ($i) = @_;
  "(" . ($i->get_value("birth date") || "") . " - "
      . ($i->get_value("death date") || "") . ")"
}

sub indi_link
{
  my ($g, $i) = @_;
  return p("Unknown") unless $i;
  p(
    a({-href => "/cgi-bin/gedcom.cgi?op=indi&gedcom=$g&indi=" . $i->xref},
      $i->cased_name) .
    " " . dates($i)
   )
}

sub main
{
  my $gedcom = param("gedcom");
  my $ged = gedcom($gedcom);
  print header,
        start_html,
        h1($gedcom),
        map(indi_link($gedcom, $_), $ged->individuals),
        end_html;
}

sub event_row
{
  my ($n, @e) = @_;
  map { td
        ([
          $n,
          $_->get_value("date")  || "-",
          $_->get_value("place") || "-",
        ])
      } @e
}

sub indi_row
{
  my ($g, $n, @i) = @_;
  map { td
        ([
          $n,
          a({-href => "/cgi-bin/gedcom.cgi?op=indi&gedcom=$g&indi=" . $_->xref},
            $_->cased_name),
          $_->get_value("birth date") || "-",
          $_->get_value("death date") || "-",
        ])
      } @i
}

sub indi
{
  my $gedcom = param("gedcom");
  my $indi   = param("indi");
  my $ged    = gedcom($gedcom);
  my $i      = $ged->get_individual($indi);
  my $name   = $i->cased_name;
  my $sex    = uc $i->sex;
  my $spouse = $sex eq "M" ? "wife" : $sex eq "F" ? "husband" : "spouse";
  print header,
        start_html(-title => $name),
        h1($name),
        table
        (
          { -border => undef },
          Tr
          (
            { align => "CENTER", valign => "TOP" },
            [
              th([ "Event", "Date", "Place"]),
              event_row("Birth",       $i->birth),
              event_row("Christening", $i->christening),
              event_row("Baptism",     $i->baptism),
              event_row("Baptism",     $i->bapl),
              event_row("Endowment",   $i->endowment),
              event_row("Death",       $i->death),
              event_row("Burial",      $i->burial),
              event_row("Marriage",    $i->get_record(qw(fams marriage))),
            ]
          )
        ),
        p,
        table
        (
          { -border => undef },
          Tr
          (
            { align => "CENTER", valign => "TOP" },
            [
              th([ "Relation", "Name", "Birth", "Death"]),
              indi_row($gedcom, ucfirst $spouse ,$i->$spouse()),
              indi_row($gedcom, "Father", $i->father),
              indi_row($gedcom, "Mother", $i->mother),
              indi_row($gedcom, "Child",  $i->children),
            ]
          )
        ),
        p(a({-href => "/cgi-bin/gedcom.cgi?op=main&gedcom=$gedcom"}, $gedcom)),
        end_html;
}

1;

__END__

=head1 NAME

Gedcom::CGI - Basic CGI routines for Gedcom.pm

Version 1.15 - 3rd May 2005

=head1 SYNOPSIS

  use Gedcom::CGI;

=head1 DESCRIPTION

=head1 METHODS

=cut
