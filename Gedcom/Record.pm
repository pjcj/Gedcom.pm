# Copyright 1998-1999, Paul Johnson (pjcj@transeda.com)

# This software is free.  It is licensed under the same terms as Perl itself.

# The latest version of this software should be available from my homepage:
# http://www.transeda.com/pjcj

# documentation at __END__

use strict;

require 5.004;

package Gedcom::Record;

use Gedcom::Item 1.01;

BEGIN
{
  use vars qw($VERSION @ISA);
  $VERSION = "1.01";
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
  my ($callback) = @_;;
  $self->{gedcom}{xrefs}{$self->{xref}} = $self if defined $self->{xref};
  # print "- xrefs are @{[keys %{$self->{gedcom}{xrefs}}]}\n";
  for my $child (@{$self->{children}})
  {
    $child->collect_xrefs($callback);
  }
}

sub resolve_xrefs
{
  my $self = shift;;
  my ($callback) = @_;;
  if (my $xref = $self->resolve_xref($self->{value}))
  {
    $self->{value} = $xref;
  }
  for my $child (@{$self->{children}})
  {
    $child->resolve_xrefs($callback);
  }
}

sub resolve_xref
{
  my $self = shift;;
  my ($value) = @_;
  # print "resolving $value\n";
  if (defined $value && defined(my $xref = $self->{gedcom}{xrefs}{$value}))
  {
    # print "to $xref\n";
    return $xref;
  }
  undef;
}

sub resolve
{
  my $self = shift;
  my @x = map { ref($_) ? $_ : $self->resolve_xref($_) } @_;
  wantarray ? @x : $x[0];
}

sub validate
{
  my $self = shift;
  my ($record, $callback) = @_;
  # print "tag is $self->{tag}\n";
  return 1 unless $self->{tag} eq "INDI" || $self->{tag} eq "FAM";
  return 1 if exists $self->{validated};
  $self->{validated} = 1;
  # print "validating: "; $self->print; print $self->summary, "\n";
  my $xrefs = $self->{gedcom}{xrefs};
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
    for $child ($self->child_values($f))
    {
      $found = 0;
      $child = $xrefs->{$child} unless ref $child;
      if ($child)
      {
        for my $back (@{$chk->{$f}})
        {
          # print "back $back\n";
          for my $ch ($child->child_values($back))
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
  my $f = \shift;
  my $i = \shift;
  my $callback = shift;
  return unless $self->{tag} eq "FAM" || $self->{tag} eq "INDI";
  return unless exists $self->{xref} and not exists $self->{new_xref};
  # print "renumbering: "; $self->print; print $self->summary, "\n";
  my ($type) = $self->{xref} =~ /^@(\w+?)\d+\@$/;
  $self->{new_xref} = "\@$type" . ($self->{tag} eq "FAM" ? $$f++ : $$i++) . "@";
  for my $fam ($self->resolve($self->child_values("FAMS"),
                              $self->child_values("FAMC")))
  {
    for my $child (qw( HUSB WIFE CHIL ))
    {
      # print "child $child\n";
      for my $ch ($self->resolve($fam->child_values($child)))
      {
        # print "child is $ch\n";
        $ch->renumber($$f, $$i, $callback);
      }
    }
  }
  $self->{xref} = $self->{new_xref};
}

sub child_value
{
  my $self = shift;;
  my ($child) = @_;
  my $c = $self->get_child($child);
  $c ? $c->{value} : undef;
}

sub child_values
{
  my $self = shift;;
  my ($child) = @_;
  map { $_->{value} } $self->get_children($child);
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

Version 1.01 - 27th April 1999

=head1 SYNOPSIS

  use Gedcom::Record;

  return 0 unless $self->parse($record, $structures, $grammar, $callback)
  $record->collect_xrefs($callback)
  $record->resolve_xrefs($callback)
  my $xref = $self->resolve_xref($self->{value})
  my @famc = $self->resolve($self->child_values("FAMC"))
  return 0 unless $child->validate($self->{record}, $callback);
  $record->renumber($xrefs, $callback, $f, $i)
  my $child = $record->child_value("NAME");
  my @children = $record->child_values("CHIL");
  print $record->summary, "\n";

=head1 DESCRIPTION

A selection of subroutines to handle records in a gedcom file.

Derived from Gedcom::Item.

=head1 HASH MEMBERS

Some of the more important hash members are:

=head2 $record->{new_xref}

The new xref of the record.  Used by renumber().

=head1 METHODS

=head2 parse

  return 0 unless $self->parse($record, $structures, $grammar, $callback)

Parse a Gedcom record.

Match a Gedcom::Record against a Gedcom::Grammar.  Warn of any
mismatches, and associate the Gedcom::Grammar with the Gedcom::Record as
$self->{grammar}.  Do this recursively.

=head2 collect_xrefs

  $record->collect_xrefs($callback)

Recursively collect all the xrefs.  Called by Gedcom::collect_xrefs.
$callback is not used yet.

=head2 resolve_xrefs

  $record->resolve_xrefs($callback)

Recursively changes all xrefs to reference the record they are pointing
to.  Like changing a soft link to a hard link on a Unix filesystem.
Called by Gedcom::resolve_xrefs. $callback is not used yet.

=head2 resolve_xref

  my $xref = $self->resolve_xref($value)

Return the record $value points to, or undef.

=head2 resolve

  my @famc = $self->resolve $self->child_values("FAMC")

For each argument, either return it or, if it an xref, return the
referenced record.

=head2 validate

  return 0 unless $child->validate($self->{record}, $callback);

Validate the Gedcom::Record.  This performs a number of consistency
checks, but could do even more.  $callback is not used yet.

Returns true iff the Record is valid.

=head2 renumber

  $record->renumber($xrefs, $callback, $f, $i)

Renumber the record.

As a record is renumbered, it is assigned the next available number.
Families start with the number $f.  Individuals are assigned the number
$i.  $f and $i are passed by reference.  The husband, wife and children
are then renumbered.  This helps to ensure that families are numerically
close together.

=head2 child_value

  my $child = $record->child_value("NAME");

Return the value of the specified child, or undef if the child could not
be found.  Calls get_child().

=head2 child_values

  my @children = $record->child_values("CHIL");

Return a list of the values of the specified children.  Calls
get_children().

=head2 summary

  print $record->summary, "\n";

Return a line of text summarising the record.

=cut
