# Copyright 2005, Paul Johnson (pjcj@cpan.org)

require 5.006;

use strict;
use warnings;

our $AUTOLOAD;
our $VERSION = "1.15";

package Gedcom::WebServices;

use Gedcom 1.15;

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
    print STDERR "path $path\n";
    if ($path =~ s|^/ws/plain/||)
    {
        $r->notes(PATH => $path);
        $r->uri("/plain");
    }
    DECLINED
}

sub _error
{
    my $self = shift;
    my ($msg) = @_;
    print $msg;
}

sub __plain
{
    my $self = shift;

    my $path = $self->{r}->notes("path");
    print STDERR "plain [$path]\n";

    my @params = split "/", $path;

    my $file = shift @params or die "No GEDCOM file specified";
    my $gedcom_file = "$Gedcom::ROOT/$file.ged";
    my $ged = $self->{ged} = Gedcom->new(gedcom_file => $gedcom_file,
                                         read_only   => 1);
    die "Can't open gedcom file [$gedcom_file]" unless $ged;

    my @ret;
    if (@params)
    {
        my $xref = shift @params;
        my $rec = $ged->resolve_xref($xref) || $ged->resolve_xref(uc $xref);
        die "Can't get record [$xref]" unless $rec;

        if (@params)
        {
            my $action = shift @params;
            die "Invalid action [$action]" unless $rec->can($action);

            if ($Gedcom::Funcs{lc $action} && @params)
            {
                print STDERR "Calling get_value($action, @params)\n";
                @ret = $rec->get_value($action, @params);
            }
            elsif ($action =~ /^write(?:_xml)?/)
            {
                print STDERR "Calling $action(STDOUT)\n";
                $rec->$action(\*STDOUT);
            }
            else
            {
                print STDERR "Calling $action(@params)\n";
                @ret = $rec->$action(@params);
            }
        }
        else
        {
            $rec->write(\*STDOUT);
        }
    }
    elsif (my $search = $self->{r}->param("search"))
    {
        @ret = $ged->get_individual($search);
    }
    else
    {
        die "No xref or parameters specified";
    }

    # print @ret . "\n";
    # use Data::Dumper; print Dumper \@ret;
    for (@ret)
    {
        if (ref)
        {
            if (defined $_->{xref})
            {
                print "/ws/plain/$file/", $_->xref, "\n";
            }
            else
            {
                $_->write(\*STDOUT, @params + 1);
            }
        }
        else
        {
            print "$_\n";
        }
    }
    print "\n" unless @ret;
}

1;

__END__

=head1 NAME

Gedcom::WebServices - Basic web service routines for Gedcom.pm

Version 1.15 - 3rd May 2005

=head1 SYNOPSIS

  use Gedcom::WebServices;

=head1 DESCRIPTION

=head1 METHODS

=cut
