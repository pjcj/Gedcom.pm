# Copyright 1998-1999, Paul Johnson (pjcj@transeda.com)

# This software is free.  It is licensed under the same terms as Perl itself.

# The latest version of this software should be available from my homepage:
# http://www.transeda.com/pjcj

# documentation at __END__

use strict;

require 5.004;

package Gedcom::Record;

use Data::Dumper;
$Data::Dumper::Indent = 1;

use Gedcom::Item 1.00;

BEGIN
{
  use vars qw($VERSION @ISA);
  $VERSION = "1.00";
  @ISA = qw( Gedcom::Item );
}

sub parse
{
  my $self = shift;
  my ($record, $structures, $grammar, $callback) = @_;
# print "checking "; $self->print();
# print "against ";  $grammar->print();
  my $t = $record->{tag};
  my $g = $grammar->{tag};
  warn "Can't match $t with $g" if $t && $t ne $g;
  $record->{grammar} = $grammar;
  my %children = map { $_->{tag} => $_ } $grammar->valid_children($structures);
# print "valid children are: ", join(", ", keys %children), "\n";
  for my $child (@{$record->{children}})
  {
    my $tag = $child->{tag};
    if (defined $children{$tag})
    {
      return 0
        unless $self->parse($child, $structures, $children{$tag}, $callback);
    }
    else
    {
      warn "$self->{file}:$child->{line}: " .
           "$tag does not appear to be a child of $t\n"
        unless $tag eq "CONT" || $tag eq "CONC" || substr($tag, 0, 1) eq "_";
    }
  }
  1;
}

sub collect_xrefs
{
  my $self = shift;
  my $xrefs = shift;
  if (my $xref = $self->{xref})
  {
    $xrefs->{$xref} = $self;
  }
  for my $child (@{$self->{children}})
  {
    $child->collect_xrefs($xrefs);
  }
}

sub resolve_xrefs
{
  my $self = shift;;
  my ($xrefs, $callback) = @_;;
  if (my $value = $self->{value})
  {
    if (defined(my $xref = $xrefs->{$value}))
    {
      $self->{value} = $xref;
    }
  }
  for my $child (@{$self->{children}})
  {
    $child->resolve_xrefs($xrefs, $callback);
  }
}

sub validate
{
  my $self = shift;
  my $record = shift;
  my $xrefs = shift;
  my $callback = shift;
  # print "tag is $self->{tag}\n";
  return 1 unless $self->{tag} eq "INDI" || $self->{tag} eq "FAM";
  return 1 if exists $self->{validated};
  $self->{validated} = 1;
  # print "validating: "; $self->print; print $self->summary, "\n";
  my $found;
  my $child;
  my $check =
  {
    INDI =>
    {
      FAMS => [ "HUSB", "WIFE" ],
      FAMC => [ "CHIL" ]
    },
    FAM =>
    {
      HUSB => [ "FAMS" ],
      WIFE => [ "FAMS" ],
      CHIL => [ "FAMC" ],
    },
  };
  my $chk = $check->{$self->{tag}};
  for my $f (keys %$chk)
  {
    $found = 1;
    CHILD:
    for $child (@{$self->children($f)})
    {
      $found = 0;
      $child = $xrefs->{$child} unless ref $child;
      if ($child)
      {
        for my $back (@{$chk->{$f}})
        {
          # print "back $back\n";
          for my $ch (@{$child->children($back)})
          {
            # print "child is $ch\n";
            $ch = $xrefs->{$ch} unless ref $ch;
            if ($ch)
            {
              if ($ch->{xref} eq $self->{xref})
              {
                $found = 1;
                # print "found...\n";
                next CHILD;
              }
              # $ch->validate($xrefs, $callback);
            }
          }
        }
        unless ($found)
        {
          warn "$f $child->{xref} " .
               "does not reference $self->{tag} $self->{xref} at " .
               "$record->{file} line $self->{line}\n" .
               "$record->{file}:" . ($child->{line} + 1) . ": 1   " .
               join(", ", @{$chk->{$f}}) .  " $self->{xref}\n";
        }
      }
    }
  }
  $self->{validated} = 2;
}

sub renumber
{
  my $self = shift;
  my $xrefs = shift;
  my $callback = shift;
  my $f = \shift;
  my $i = \shift;
  return unless $self->{tag} eq "FAM" || $self->{tag} eq "INDI";
  return unless exists $self->{xref} and not exists $self->{new_xref};
  # print "renumbering: "; $self->print; print $self->summary, "\n";
  my ($type) = $self->{xref} =~ /^@(\w+?)\d+\@$/;
  $self->{new_xref} = "\@$type" . ($self->{tag} eq "FAM" ? $$f++ : $$i++) . "@";
  for my $fam (@{$self->children("FAMS")}, @{$self->children("FAMC")})
  {
    $fam = $xrefs->{$fam} unless ref $fam;
    if ($fam)
    {
      for my $child (qw( HUSB WIFE CHIL ))
      {
        # print "child $child\n";
        for my $ch (@{$fam->children($child)})
        {
          # print "child is $ch\n";
          $ch = $xrefs->{$ch} unless ref $ch;
          if ($ch)
          {
            $ch->renumber($xrefs, $callback, $$f, $$i);
          }
        }
      }
    }
  }
  $self->{xref} = $self->{new_xref};
}

sub get_records
{
  my $self = shift;;
  my ($type) = shift;
  [ grep { $_->{tag} eq $type } @{$self->{children}} ]
}

sub child
{
  my $self = shift;;
  my ($child) = shift;
  my $c = $self->get_child($child);
  $c ? $c->{value} : undef;
}

sub children
{
  my $self = shift;;
  my ($child) = shift;
  my $c = $self->get_children($child);
  [ map { $_->{value} } @$c ]
}

sub summary
{
  my $self = shift;
# print "summary of ", Dumper $self;
  my $s = "";
  $s .= sprintf("%-5s", $self->{xref} =~ /@(.*)@/);
  my $child = $self->get_child("NAME");
  $s .= sprintf(" %-40s", $child ? $child->{value} : "");
  $child = $self->get_child("SEX");
  $s .= sprintf(" %1s", $child ? $child->{value} : "");
  my $d = "";
  if ($child   = $self->get_child("BIRT") and
      my $date = $child->get_child("DATE"))
  {
    $d = $date->{value};
  }
  $s .= sprintf(" %16s", $d);
  $s;
}

1;

__END__

=head1 NAME

Gedcom::Record - a class to manipulate Gedcom records

Version 1.00 - 8th March 1999

=head1 SYNOPSIS

use Gedcom::Record;

=head1 DESCRIPTION

To be written...

=cut
