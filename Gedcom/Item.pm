# Copyright 1998-1999, Paul Johnson (pjcj@transeda.com)

# This software is free.  It is licensed under the same terms as Perl itself.

# The latest version of this software should be available from my homepage:
# http://www.transeda.com/pjcj

# documentation at __END__

use strict;

require 5.004;

package Gedcom::Item;

BEGIN
{
  use vars qw($VERSION);
  $VERSION = "1.01";

  eval "use Date::Manip";
}

sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self = { children => [], @_ };
  bless $self, $class;
  $self->read if $self->{file};
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
      $rec = $self->new(level     => -1,
                        structure => $structure,
                        number    => "many",
                        line      => $self->{fh}->input_line_number);
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
      $rec->{level}  = ($level eq "n" ? 0 : $level) if defined $level;
      $rec->{xref}   = $xref                        if defined $xref;
      $rec->{tag}    = $tag                         if defined $tag;
      $rec->{value}  = $value                       if defined $value;
      $rec->{min}    = $min                         if defined $min;
      $rec->{max}    = $max                         if defined $max;
      $rec->{gedcom} = $self->{gedcom};
      if (ref($self) !~ /Grammar/ and $_ = $rec->{tag})
      {
        my $class = /INDI/i ? "Individual" :
                    /FAM/i  ? "Family"     :
                              undef;
        bless $rec, "Gedcom::$class" if $class;
      }
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
  unless ($INC{"Date/Manip.pm"})
  {
    warn "Date::Manip is required to use normalise_dates()";
    return;
  }
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
  my ($tag, $count) = $t =~ /^_?(\w+?)(\d*)$/;
  $count = 1 unless $count;
  # print "looking for <$tag> number <$count>\n";
  for my $c (@{$self->{children}})
  {
    return $c if $c->{tag} eq $tag && !--$count;
  }
  undef;
}

sub get_children
{
  my $self = shift;
  my ($tag) = @_;
  grep { $_->{tag} eq $tag } @{$self->{children}}
}

sub delete_child
{
  my $self = shift;
  my ($child) = @_;
  my $c = "$child";
  my $n = 0;
  for (@{$self->{children}})
  {
    my $ch = "$_";
    # print "matching $ch against $c\n";
    last if $c eq $ch;
    $n++;
  }
  # print "deleting child $n of $#{$self->{children}}\n";
  splice @{$self->{children}}, $n, 1;
}

1;

__END__

=head1 NAME

Gedcom::Item - a base class for Gedcom::Grammar and Gedcom::Record

Version 1.01 - 27th April 1999

=head1 SYNOPSIS

  use Gedcom::Record;

  $self->{grammar} = Gedcom::Grammar->new(file     => $self->{grammar_file},
                                          callback => $self->{callback});
  $self->read() if $self->{file};
  $self->add_children($rec)
  while (my $next = $self->next_record($record))
  $line = $self->next_line()
  my $line = $self->next_text_line()
  $record->>write($fh, $level)
  $record->normalise_dates($format)
  $item->print()
  my $child = get_child("CHIL2")
  my @children = get_children("CHIL")

=head1 DESCRIPTION

A selection of subroutines to handle items in a gedcom file.

=head1 HASH MEMBERS

Some of the more important hash members are:

=head2 $item->{level}

The level of the item.

=head2 $item->{xref}

The cross reference, either hard or soft.

=head2 $item->{tag}

The name of the tag.

=head2 $item->{value}

The value of the item.

=head2 $item->{min}

The minimum number of items allowed.

=head2 $item->{max}

The maximum number of items allowed.

=head2 $item->{children}

Array of all children of this item.

=head1 METHODS

=head2 new

  $self->{grammar} = Gedcom::Grammar->new(file     => $self->{grammar_file},
                                          callback => $self->{callback});

Create a new object.

If file is supplied, it is the name of a file to read.

If callback is supplied, it is a subroutine reference which is called at
various times while the file is being read.

The subroutine takes five parameters:
  $title:     A title
  $txt1:      One text message
  $txt2:      A secondary text message
  $current:   A count of how far through the file we are
  $total:     The extent of the file

The subroutine should return true iff the file shuld continue to be
read.

=head2 read

  $self->read() if $self->{file};

Read a file into the object.  Called by the constructor.

=head2 add_children

  $self->add_children($rec)

Read in the children of a record.

=head2 next_record

  while (my $next = $self->next_record($record))

Read the next record from a file.  Return the record or false if it
cannot be read.

=head2 next_line

  $line = $self->next_line()

Read the next line from the file, and return it or false.

=head2 next_text_line

  my $line = $self->next_text_line()

Read the next line of text from the file, and return it or false.

=head2 write

  $record->>write($fh, $level)

Write the record to a FileHandle.

The subroutine takes two parameters:
  $fh:        The FileHandle to which to write
  $level:     The level of the record

=head2 normalise_dates

  $record->normalise_dates($format)

Change the format of all dates in the record.

See the documentation for Gedcom::normalise_dates

=head2 print

  $item->print()

Print the item.  Used for debugging.  (What?  There are bugs?)

=head2 get_child

  my $child = get_child("CHIL2")

Get a specific child from the item.

The argument contains the name of the tag, and optionally the count.
The regular expression to generate the tag and the count is:

  my ($tag, $count) = $t =~ /^_?(\w+?)(\d*)$/;

Returns the child, or undef if it doesn't exist;

=head2 get_children

  my @children = get_children("CHIL")

Get all children matching a specified tag.

=cut
