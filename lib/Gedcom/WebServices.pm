# Copyright 2005-2013, Paul Johnson (paul@pjcj.net)

require 5.006;

use strict;
use warnings;

our $AUTOLOAD;
our $VERSION = "1.15";

package Gedcom::WebServices;

use Gedcom 1.19;

use Apache::Constants qw( OK DECLINED );
use Apache::Request;
use Apache::URI;

sub _new
{
    my $class = shift;
    my $r     = shift;

    my $self =
    {
        r => $r ? Apache::Request->instance($r) : $r,
        @_
    };
    bless $self, $class
}

sub _set_handlers
{
    my ($handlers) = @_;

    my $handler_text;

    for my $h (@{$handlers})
    {
        # print STDERR "creating $type handler for $h\n";
        $handler_text .= _create_handler($h);
    }

    # print STDERR "handler_text is [$handler_text]\n";
    $handler_text
}

sub _create_handler
{
    my ($h) = @_;
    my $handler = "___$h";
    unless (defined &$handler)
    {
        no strict "refs";
        *$handler = sub ($$)
        {
            my ($class, $r) = @_;
            my $self;
            my $vars;
            eval
            {
                my $hn = "__$h";
                $self = $class->_new($r, handler => $hn);
                $self->$hn;
            };
            # die Template::Exception->new("Retemps.perl", $@);
            # die $@ if $@;
            $self->_error($@) if $@;
            exists $self->{_status} ? $self->{_status} : OK
        };
    }
    my $l = <<"EOE";
    \$Location{"/$h"} =
    {
        SetHandler  => "perl-script",
        PerlHandler => "Gedcom::WebServices->___$h",
    };
EOE
    $l
}

sub _parse_uri
{
    my $r      = shift;
    my $uri    = $r->parsed_uri;
    my $path   = $uri->path;
    # print STDERR "parse path $path\n";
    if ($path =~ s!^/ws/(plain|json|xml)/!!)
    {
        $r->notes(PATH => $path);
        # print STDERR "parse new path [$1]\n";
        $r->uri("/$1");
    }
    DECLINED
}

sub _error
{
    my $self = shift;
    my ($msg) = @_;
    print $msg;
}

sub _process
{
    my $self = shift;
    my ($type) = @_;

    my $path = $self->{r}->notes("path");
    # print STDERR "$type [$path]\n";

    my @params = split "/", $path;

    my $file = shift @params or die "No GEDCOM file specified\n";
    my $gedcom_file = "$Gedcom::ROOT/$file.ged";
    # print STDERR "gedcom_file $gedcom_file\n";

    my $ged = $self->{ged} = Gedcom->new(gedcom_file => $gedcom_file,
                                         read_only   => 1);
    die "Can't open gedcom file [$gedcom_file]\n" unless $ged;

    # print STDERR "params @params\n";

    my @ret;
    if (@params)
    {
        my $xref = shift @params;
        my $rec = $ged->resolve_xref($xref) || $ged->resolve_xref(uc $xref) ||
                  die "Can't get record [$xref]\n";

        if (@params)
        {
            my ($action, @parms) = @params;
            die "Invalid action [$action]\n" unless $rec->can($action);

            if ($Gedcom::Funcs{lc $action} && @parms)
            {
                # print STDERR "Calling get_value(@params)\n";
                @ret = $rec->get_value(@params);
            }
            else
            {
                # print STDERR "Calling $action(@params)\n";
                @ret = $rec->$action(@parms);
            }
        }
        else
        {
            if ($type eq "plain")
            {
                $rec->write(\*STDOUT);
            }
            elsif ($type eq "xml")
            {
                my $r = $rec->hash;
                $rec->write_xml(\*STDOUT);
            }
            elsif ($type eq "json")
            {
                my $r = $rec->hash;
                # use DDS; print STDERR Dump $r;
                print JSON->new->objToJson({ rec => $r });
            }
            else
            {
                die "unrecognised type: $type";
            }
        }
    }
    elsif (my $search = $self->{r}->param("search"))
    {
        @ret = $ged->get_individual($search);
    }
    else
    {
        die "No xref or parameters specified\n";
    }

    # print @ret . "\n";
    # use Data::Dumper; print Dumper \@ret;
    for (@ret)
    {
        if (ref)
        {
            if (defined $_->{xref})
            {
                print "/ws/$type/$file/", $_->xref, "\n";
            }
            else
            {
                if ($type eq "plain")
                {
                    $_->write(\*STDOUT, scalar @params);
                }
                elsif ($type eq "xml")
                {
                    $_->write_xml(\*STDOUT);
                }
                elsif ($type eq "json")
                {
                    my $r = $_->hash;
                    # use DDS; print STDERR Dump $r;
                    print JSON->new->objToJson($r);
                }
                else
                {
                    die "unrecognised type: $type";
                }
            }
        }
        else
        {
            my $result = @params ? $params[-1] : "result";
            if ($type eq "plain")
            {
                print "$_\n";
            }
            elsif ($type eq "xml")
            {
                $result = uc $result;
                print "<$result>$_</$result>\n";
            }
            elsif ($type eq "json")
            {
                print JSON->new->objToJson({ $result => $_ });
            }
            else
            {
                die "unrecognised type: $type";
            }
        }
    }
    print "\n" unless @ret;
}

sub __plain
{
    my $self = shift;
    $self->_process("plain");
}

sub __xml
{
    my $self = shift;
    $self->_process("xml");
}

sub __json
{
    my $self = shift;
    require JSON;
    $self->_process("json");
}

1;

__END__

=head1 NAME

Gedcom::WebServices - Basic web service routines for Gedcom.pm

Version 1.19 - 18th August 2013

=head1 SYNOPSIS

 wget -qO - http://www.example.com/ws/plain/my_family/i9/name

=head1 DESCRIPTION

This module provides web service access to a GEDCOM file in conjunction with
mod_perl.  Using it, A request for information can be made in the form of a URL
specifying the GEDCOM file to be used, which information is required and the
format in which the information is to be delivered.  This information is then
returned in the specified format.

There are currently three supported formats:

=over

=item *

plain - no markup

=item *

XML

=item *

JSON

=back

=head2 URLs

The format of the URLs used to access the web services are:

 $BASEURL/$FORMAT/$GEDCOM/$XREF/requested/information
 $BASEURL/$FORMAT/$GEDCOM?search=search_criteria

=over

=item BASEURL

The base URL to access the web services.

=item FORMAT

The format in which to return the results.

=item GEDCOM

The name of the GEDCOM file to use (the extension .ged is assumed).

=item XREF

The xref of the record about which information is required.  XREFs can be
obtained initially from a search, and subsequently from certain queries.


=item requested/information

The information requested.  This is in the same format as that taken by the
get_value method.

=item search_criteria

An individual to search for.  This is in the same format as that taken by the
get_individual method.

=back

=head1 EXAMPLES

 $ wget -qO - 'http://pjcj.sytes.net:8585/ws/plain/royal92?search=elizabeth_ii'
 /ws/plain/royal92/I52

 $ wget -qO - http://pjcj.sytes.net:8585/ws/plain/royal92/I52
 0 @I52@ INDI
 1   NAME Elizabeth_II Alexandra Mary/Windsor/
 1   TITL Queen of England
 1   SEX F
 1   BIRT
 2     DATE 21 APR 1926
 2     PLAC 17 Bruton St.,London,W1,England
 1   FAMS @F14@
 1   FAMC @F12@

 $ wget -qO - http://pjcj.sytes.net:8585/ws/plain/royal92/I52/name
 Elizabeth_II Alexandra Mary /Windsor/

 $ wget -qO - http://pjcj.sytes.net:8585/ws/plain/royal92/I52/birth/date
 21 APR 1926

 $ wget -qO - http://pjcj.sytes.net:8585/ws/plain/royal92/I52/children
 /ws/plain/royal92/I58
 /ws/plain/royal92/I59
 /ws/plain/royal92/I60
 /ws/plain/royal92/I61

 $ wget -qO - http://pjcj.sytes.net:8585/ws/json/royal92/I52/name
 {"name":"Elizabeth_II Alexandra Mary /Windsor/"}

 $ wget -qO - http://pjcj.sytes.net:8585/ws/xml/royal92/I52/name
 <NAME>Elizabeth_II Alexandra Mary /Windsor/</NAME>

 $ wget -qO - http://pjcj.sytes.net:8585/ws/xml/royal92/I52
 <INDI ID="I52">
   <NAME>Elizabeth_II Alexandra Mary/Windsor/</NAME>
   <TITL>Queen of England</TITL>
   <SEX>F</SEX>
   <BIRT>
     <DATE>21 APR 1926</DATE>
     <PLAC>17 Bruton St.,London,W1,England</PLAC>
   </BIRT>
   <FAMS REF="F14"/>
   <FAMC REF="F12"/>
 </INDI>

=head1 CONFIGURATION

Add a section similar to the following to your mod_perl config:

 PerlWarn On
 PerlTaintCheck On

 PerlPassEnv GEDCOM_TEST

 <IfDefine GEDCOM_TEST>
     <Perl>
         $Gedcom::TEST = 1;
     </Perl>
 </IfDefine>

 <Perl>
     use Apache::Status;

     $ENV{PATH} = "/bin:/usr/bin";
     delete @ENV{"IFS", "CDPATH", "ENV", "BASH_ENV"};

     $Gedcom::DATA = $Gedcom::ROOT;  # location of data stored on server

     use lib "$Gedcom::ROOT/blib/lib";
     use Gedcom::WebServices;

     my $handlers =
     [ qw
       (
           plain
           xml
           json
       )
     ];

     eval Gedcom::WebServices::_set_handlers($handlers);
     # use Apache::PerlSections; print STDERR Apache::PerlSections->dump;
 </Perl>

 PerlTransHandler Gedcom::WebServices::_parse_uri

=head1 BUGS

Very probably.

See the BUGS file.  And the TODO file.

=head1 VERSION

Version 1.19 - 18th August 2013

=head1 LICENCE

Copyright 2005-2013, Paul Johnson (paul@pjcj.net)

This software is free.  It is licensed under the same terms as Perl itself.

The latest version of this software should be available from my homepage:
http://www.pjcj.net

=cut
