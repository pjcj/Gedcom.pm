# Copyright 1998-1999, Paul Johnson (pjcj@transeda.com)

# This software is free.  It is licensed under the same terms as Perl itself.

# The latest version of this software should be available from my homepage:
# http://www.transeda.com/pjcj

# documentation at __END__

use strict;

require 5.004;

package Gedcom::Item;

use Data::Dumper;
use Date::Manip;

$Data::Dumper::Indent = 1;
Date_Init("DateFormat=UK");

BEGIN
{
  use vars qw($VERSION);
  $VERSION = "1.00";
}

sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self = { children => [], @_ };
  bless($self, $class);
  $self->read() if $self->{file};
  $self;
}

sub read
{
  my $self = shift;
  my $callback = $self->{callback};;
  $self->{fh} = FileHandle->new($self->{file})
    or die "Can't open file ", $self->{file}, ": $!";
  $self->{fh}->seek(0, 2);
  my $size = $self->{fh}->tell;
  $self->{fh}->seek(0, 0);
  my $title = "Reading";
  my $txt1 = "Reading " . $self->{file};
  my $count = 0;
  return undef
    if $callback &&
       !&$callback($title, $txt1, "Record $count", $self->{fh}->tell, $size);
  $self->{level} = -1;

  my $grammar = $self->{grammar};
  my ($t, $structures, %children);
  if ($grammar)
  {
    my $t = $self->{tag};
    my $g = $grammar->{tag};
    warn "Can't match $t with $g" if $t && $t ne $g;
    $structures = $grammar->{structures};
    %children   = %{$grammar->{valid_children}};
#   print "valid children are: ", join(", ", keys %children), "\n";
  }

  while (my $structure = $self->next_record($self))
  {
    $self->add_children($structure);
    if ($grammar)
    {
      my $tag = $structure->{tag};
      if (defined $children{$tag})
      {
        if ($self->parse($structure,
                         $structures,
                         $children{$tag},
                         $self->{callback}))
        {
          push @{$self->{children}}, $structure;
          $count++;
        }
      }
      else
      {
        warn "$self->{file}:$structure->{line}: " .
             "$tag does not appear to be a child of $t\n";
      }
    }
    else
    {
      push @{$self->{children}}, $structure;
      $count++;
    }
    delete $structure->{gedcom};
#   delete $structure->{grammar};
    return undef
      if $callback &&
         !&$callback($title, $txt1, "Record $count line " . $structure->{line},
                     $self->{fh}->tell, $size);
  }
  $self->{fh}->close()
    or die "Can't close file ", $self->{file}, ": $!";
  delete $self->{fh};
  $self;
}

sub add_children
{
  my $self = shift;
  my ($record) = @_;
# print "adding children to: "; $record->print();
# print Dumper $record;
  while (my $next = $self->next_record($record))
  {
    unless (ref $next)
    {
      $record->{number} = $next;
      next;
    }
    my $level = $record->{level};
    my $next_level = $next->{level};
#   print "levels are $level and $next_level\n";
    if (!defined $next_level || $next_level <= $level)
    {
#     print "storing...\n";
      $self->{stored_record} = $next;
      return;
    }
    elsif ($next_level > $level + 1)
    {
      warn "Can't add level $next_level to $level";
    }
    else
    {
      delete $next->{gedcom};
      push @{$record->{children}}, $next;
    }
  }
}

sub next_record
{
  my $self = shift;
  my ($record) = @_;
  my $rec;
  if ($rec = $self->{stored_record})
  {
    $self->{stored_record} = undef;
  }
  elsif ((!$rec || !$rec->{level}) &&
         (my $line = $self->next_text_line()))
  {
#   print "line is $line";
    if (my ($structure) = $line =~ /^\s*(\w+): =\s*$/)
    {
      $rec = $self->new(level      => -1,
                        structure  => $structure,
                        number     => "many",
                        line       => $self->{fh}->input_line_number);
#     print "found structure $structure\n";
    }
    elsif (my ($level, $xref, $tag, $value, $min, $max) =
      $line =~ /^\s*                       # optional whitespace at start
                ((?:\+?\d+)|n)             # start level
                \s*                        # optional whitespace
                (?:                        # xref
                  (@<?.*>?@)               # text in @<?>?@
                  \s+                      # whitespace
                )?                         # optional
                (?:                        # tag
                  (?!<<)                   # don't match a type
                  ([\w\s\[\]\|<>]+?)       # non greedy
                  \s+                      # whitespace
                )?                         # optional
                (?:                        # value
                  (                        #
                    (?:                    # one of
                      @?<?.*?>?@?          # text element - non greedy
                      |                    # or
                      \[\s*                # start list
                      (?:                  #
                        @?<.*>@?           # text element
                        \s*\|?\s*          # optionally delimited
                      )+                   # one or more
                      \]                   # end list
                    )                      #
                  )                        #
                  \s+                      # whitespace
                )??                        # optional - non greedy
                (?:                        # value
                  \{                       # open brace
                    (\d+)                  # min
                    :                      # :
                    (\d+|M)                # max
                    \*?                    # optional *
                  [\}\]]                   # close brace or bracket
                )?                         # optional
                \*?                        # optional *
                \s*$/x)                    # optional whitespace at end
    {
      $rec = $self->new(line => $self->{fh}->input_line_number) unless $rec;
      $rec->{level} = ($level eq "n" ? 0 : $level) if defined $level;
      $rec->{xref}  = $xref                        if defined $xref;
      $rec->{tag}   = $tag                         if defined $tag;
      $rec->{value} = $value                       if defined $value;
      $rec->{min}   = $min                         if defined $min;
      $rec->{max}   = $max                         if defined $max;
    }
    elsif ($line =~ /^\s*[\[\|\]]\s*(?:\/\*.*\*\/\s*)?$/)
    {
      return "one";
    }
    else
    {
      die "no match for <$line>";
    }
  }
# print "comparing "; $record->print();
# print Dumper($record);
# print "with      "; $rec->print() if $rec;
# print Dumper($rec);
  $self->add_children($rec)
    if $rec && defined $rec->{level} && ($rec->{level} > $record->{level});
  $rec;
}

sub next_line
{
  my $self = shift;
  my $line = $self->{fh}->getline();
  # print "read $line" if defined $line;
  $line;
}

sub next_text_line
{
  my $self = shift;
  my $line = "";
  until (!defined $line || $line =~ /\S/)
  {
    $line = $self->next_line()
  }
  $line;
}

sub write
{
  my $self = shift;
  my ($fh, $level) = @_;
  my @p;
  push(@p, $level . "  " x $level)    unless $level < 0;
  push(@p, $self->{xref})             if     $self->{xref};
  push(@p, $self->{tag})              if     $self->{tag};
  push(@p, ref $self->{value}
           ? $self->{value}->{xref}
           : $self->{value})          if     $self->{value};
  $fh->print("@p");
  $fh->print("\n")                    unless $level < 0;
  for my $c (0 .. @{$self->{children}} - 1)
  {
    $self->{children}[$c]->write($fh, $level + 1);
    $fh->print("\n")                  if     $level < 0 &&
                                             $c < @{$self->{children}} - 1;
  }
}

sub normalise_dates
{
  my $self = shift;
  my $format = shift || "%A, %E %B %Y";
  if (defined $self->{tag} && $self->{tag} =~ /^date$/i)
  {
    if (defined $self->{value} && $self->{value})
    {
      # print "date was $self->{value}\n";
      my @dates = split / or /, $self->{value};
      for my $dt (@dates)
      {
        my $date = ParseDate($dt);
        my $d = UnixDate($date, $format);
        $dt = $d if $d;
      }
      $self->{value} = join " or ", @dates;
      # print "date is  $self->{value}\n";
    }
  }
  for my $child (@{$self->{children}})
  {
    $child->normalise_dates($format);
  }
}

sub renumber
{
  my $self = shift;
  return if exists $self->{new_xref};
  for my $child (@{$self->{children}})
  {
    $child->renumber();
  }
}

sub print
{
  my $self = shift;
  for my $v (qw( level xref tag value min max ))
  {
    print($v, ": ", $self->{$v}, " ") if defined $self->{$v};
  }
  print "\n";
}

sub get_child
{
  my $self = shift;
  my ($t) = @_;
  my ($type, $count) = $t =~ /^_?(\w+?)(\d*)$/;
  $count = 1 unless $count;
  # print "looking for <$type> number <$count>\n";
  for my $c (@{$self->{children}})
  {
    return $c if $c->{tag} eq $type && !--$count;
  }
  undef;
}

sub get_children
{
  my $self = shift;
  my ($type) = @_;
  [ grep { $_->{tag} eq $type } @{$self->{children}} ]
}

1;

__END__

=head1 NAME

Gedcom::Item - a base class for Gedcom::Grammar and Gedcom::Record

Version 1.00 - 8th March 1999

=head1 SYNOPSIS

use Gedcom::Record;

=head1 DESCRIPTION

To be written...

=cut
