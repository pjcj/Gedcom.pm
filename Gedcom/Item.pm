# Copyright 1998-2005, Paul Johnson (pjcj@cpan.org)

# This software is free.  It is licensed under the same terms as Perl itself.

# The latest version of this software should be available from my homepage:
# http://www.pjcj.net

# documentation at __END__

use strict;

require 5.005;

package Gedcom::Item;

use Symbol;

use vars qw($VERSION);
$VERSION = "1.15";

sub new
{
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self =
  {
    level => -3,
    file  => "*",
    line  => 0,
    items => [],
    @_
  };
  bless $self, $class;
  $self->read if $self->{file} && $self->{file} ne "*";
  $self;
}

sub copy
{
  my $self = shift;
  my $item  = $self->new;
  for my $key (qw(level xref tag value pointer min max gedcom))
  {
    $item->{$key} = $self->{$key} if exists $self->{$key}
  }
  $item->{items} = [ map { $_->copy } @{$self->_items} ];
  $item
}

sub read
{
  my $self = shift;

# $self->{fh} = FileHandle->new($self->{file})
  $self->{fh} = gensym;
  open $self->{fh}, $self->{file} or die "Can't open file $self->{file}: $!";
  binmode $self->{fh};

  # find out how big the file is
  seek($self->{fh}, 0, 2);
  my $size = tell $self->{fh};
  seek($self->{fh}, 0, 0);

  # initial callback
  my $callback = $self->{callback};;
  my $title = "Reading";
  my $txt1 = "Reading $self->{file}";
  my $count = 0;
  return undef
    if $callback &&
       !$callback->($title, $txt1, "Record $count", tell $self->{fh}, $size);

  $self->level($self->{grammar} ? -1 : -2);

  my $if = "$self->{file}.index";
  my ($gf, $gc);
  if ($self->{gedcom}{read_only} &&
      defined ($gf = -M $self->{file}) && defined ($gc = -M $if) && $gc < $gf)
  {
    if (! open I, $if)
    {
      die "Can't open $if: $!";
    }
    else
    {
      my $g = $self->{gedcom}{grammar}->structure("GEDCOM");
      while (<I>)
      {
        my @vals = split /\|/;
        my $record =
          Gedcom::Record->new(gedcom  => $self->{gedcom},
                              tag     => $vals[0],
                              line    => $vals[3],
                              cpos    => $vals[4],
                              grammar => $g->item($vals[0]),
                              fh      => $self->{fh},
                              level   => 0);
        $record->{xref}  = $vals[1] if length $vals[1];
        $record->{value} = $vals[2] if length $vals[2];
        my $class = $self->{gedcom}{types}{$vals[0]};
        bless $record, "Gedcom::$class" if $class;
        push @{$self->{items}}, $record;
      }
      close I or warn "Can't close $if";
    }
  }

  unless (@{$self->{items}})
  {
    # $#{$self->{items}} = 20000;
    # $#{$self->{items}} = -1;
    # If we have a grammar, then we are reading a gedcom file and must use
    # the grammar to verify what is being read.
    # If we do not have a grammar, then that is what we are reading.
    while (my $item = $self->next_item($self))
    {
      if ($self->{grammar})
      {
        my $tag = $item->{tag};
        my @g = $self->{grammar}->item($tag);
        # print "<$tag> => <@g>\n";
        if (@g)
        {
          $self->parse($item, $g[0]);
          push @{$self->{items}}, $item;
          $count++;
        }
        else
        {
          $tag = "<empty tag>" unless defined $tag && length $tag;
          warn "$self->{file}:$item->{line}: $tag is not a top level tag\n";
        }
      }
      else
      {
        # just add the grammar item
        push @{$self->{items}}, $item;
        $count++;
      }
      return undef
        if ref $item &&
           $callback &&
           !$callback->($title, $txt1, "Record $count line " . $item->{line},
                        tell $self->{fh}, $size);
    }
  }

# unless ($self->{gedcom}{read_only})
# {
#   $self->{fh}->close or die "Can't close file $self->{file}: $!";
#   delete $self->{fh};
# }

  if ($self->{gedcom}{read_only} && defined $gf && (! defined $gc || $gc > $gf))
  {
    if (! open I, ">$if")
    {
      warn "Can't open $if";
    }
    else
    {
      for my $item (@{$self->{items}})
      {
        print I join("|", map { $item->{$_} || "" } qw(tag xref value line cpos));
        print I "\n";
      }
      close I or warn "Can't close $if";
    }
  }

  $self;
}

sub add_items
{
  my $self = shift;
  my ($item, $parse) = @_;
# print "adding items to: "; $item->print;
  if (!$parse &&
      $item->{level} >= 0 &&
      $self->{gedcom}{read_only} &&
      $self->{gedcom}{grammar})
  {
    # print "ignoring items\n";
    $self->skip_items($item);
  }
  else
  {
    if ($parse && $self->{gedcom}{read_only} && $self->{gedcom}{grammar})
    {
#     print "reading items\n";
      if (defined $item->{cpos})
      {
        seek($self->{fh}, $item->{cpos}, 0);
        $. = $item->{line};
      }
    }
    $item->{items} = [];
    while (my $next = $self->next_item($item))
    {
      unless (ref $next)
      {
        # The grammar requires a single selection from its items
        $item->{selection} = 1;
        next;
      }
      my $level = $item->{level};
      my $next_level = $next->{level};
      if (!defined $next_level || $next_level <= $level)
      {
        $self->{stored_item} = $next;
        # print "stored ***********************************\n";
        return;
      }
      else
      {
        warn "$self->{file}:$item->{line}: " .
             "Can't add level $next_level to $level\n"
          if $next_level > $level + 1;
        push @{$item->{items}}, $next;
      }
    }
    $item->{_items} = 1 unless $item->{gedcom}{read_only};
  }
}

sub skip_items
{
  my $self = shift;
  my ($item) = @_;
  my $level = $item->{level};
  my $cpos = $item->{cpos} = tell $self->{fh};
# print "skipping items to level $level at $item->{line}:$cpos\n";
  my $fh = $self->{fh};
  while (my $l = <$fh>)
  {
    chomp $l;
#   print "parsing <$l>\n";
    if (my ($lev) = $l =~ /^\s*(\d+)/)
    {
      if ($lev <= $level)
      {
#       print "pushing <$l>\n";
        seek($self->{fh}, $cpos, 0);
        $.--;
        last;
      }
    }
    $cpos = tell $self->{fh};
  }
}

sub next_item
{
  my $self   = shift;
  my ($item) = @_;
  my $bpos   = tell $self->{fh};
  my $bline  = $.;
  # print "At $bpos:$bline\n";
  my $rec;
  my $fh = $self->{fh};
  if ($rec = $self->{stored_item})
  {
    $self->{stored_item} = undef;
  }
  elsif ((!$rec || !$rec->{level}) && (my $line = $self->next_text_line))
  {
    # TODO - tidy this up
    my $line_number = $.;
    # print "line $line_number is <$line>";
    if (my ($structure) = $line =~ /^\s*(\w+): =\s*$/)
    {
      $rec = $self->new(level     => -1,
                        structure => $structure,
                        line      => $line_number);
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
                      @?<?.*?\s*>?@?       # text element - non greedy
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
#     $line =~ /^\s*                       # optional whitespace at start
#               (\d+)                      # start level
#               \s*                        # optional whitespace
#               (?:                        # xref
#                 (@.*@)                   # text in @@
#                 \s+                      # whitespace
#               )?                         # optional
#               (\w+)                      # tag
#               \s*                        # whitespace
#               (?:                        # value
#                 (@?.*?@?)                # text element - non greedy
#                 \s+                      # whitespace
#               )??                        # optional - non greedy
#               \s*$/x)                    # optional whitespace at end
    {
      # print "found $level below $item->{level}\n";
      if ($level eq "n" || $level > $item->{level})
      {
        unless ($rec)
        {
          $rec = $self->new(line => $line_number);
          $rec->{gedcom} = $self->{gedcom} if $self->{gedcom}{grammar};
        }
        $rec->{level} = ($level eq "n" ? 0 : $level) if defined $level;
        $rec->{xref}  = $xref  =~ /^\@(.+)\@$/ ? $1 : $xref
          if defined $xref;
        $rec->{tag}   = $tag                         if defined $tag;
        $rec->{value} = ($rec->{pointer} = $value =~ /^\@(.+)\@$/) ? $1 : $value
          if defined $value;
        $rec->{min}   = $min                         if defined $min;
        $rec->{max}   = $max                         if defined $max;
      }
      else
      {
        # print " -- pushing back\n";
        seek($fh, $bpos, 0);
        $. = $bline;
      }
    }
    elsif ($line =~ /^\s*[\[\|\]]\s*(?:\/\*.*\*\/\s*)?$/)
    {
      # The grammar requires a single selection from its items.
      return "selection";
    }
    else
    {
      chomp $line;
      my $file = $self->{file};
      die "\n$file:$line_number: Can't parse line: $line\n";
    }
  }

# print "\ncomparing "; $item->print;
# print "with      "; $rec->print if $rec;
  $self->add_items($rec)
    if $rec && defined $rec->{level} && ($rec->{level} > $item->{level});
  $rec;
}

sub next_line
{
  my $self = shift;
  my $fh = $self->{fh};
  my $line = <$fh>;
  $line;
}

sub next_text_line
{
  my $self = shift;
  my $line = "";
  my $fh = $self->{fh};
  $line = <$fh> until !defined $line || $line =~ /\S/;
  $line;
}

sub write
{
  my $self = shift;
  my ($fh, $level, $flush) = @_;
  my @p;
  push(@p, $level . "  " x $level)         unless $flush || $level < 0;
  push(@p, "\@$self->{xref}\@")            if     defined $self->{xref} &&
                                                  length $self->{xref};
  push(@p, $self->{tag})                   if     $level >= 0;
  push(@p, ref $self->{value}
           ? "\@$self->{value}{xref}\@"
           : $self->resolve_xref($self->{value})
             ? "\@$self->{value}\@"
             : $self->{value})             if     defined $self->{value} &&
                                                  length $self->{value};
  $fh->print("@p");
  $fh->print("\n")                         unless $level < 0;
  for my $c (0 .. @{$self->_items} - 1)
  {
    $self->{items}[$c]->write($fh, $level + 1, $flush);
    $fh->print("\n")                       if     $level < 0 &&
                                                  $c < @{$self->{items}} - 1;
  }
}

sub write_xml
{
  my $self = shift;
  my ($fh, $level) = @_;

  return if $self->{tag} && $self->{tag} =~ /^(CON[CT]|TRLR)$/;

  my $spaced = 0;
  my $events = 0;

  $level = 0 unless $level;
  my $indent = "  " x $level;

  my $tag = $level >= 0 && $self->{tag};

  my $value = $self->{value}
              ? ref $self->{value}
                ? $self->{value}{xref}
                : $self->full_value
              : undef;
  $value =~ s/\s+$// if defined $value;

  my $sub_items = @{$self->_items};

  my $p = "";
  if ($tag)
  {
    $tag = $events &&
           defined $self->{gedcom}{types}{$self->{tag}} &&
                   $self->{gedcom}{types}{$self->{tag}} eq "Event"
      ? "EVEN"
      : $self->{tag};

    $tag = "GED" if $tag eq "GEDCOM";

    $p .= $indent;
    $p .= "<$tag";

    if ($tag eq "EVEN")
    {
      $p .= qq( EV="$self->{tag}");
    }
    elsif ($tag =~ /^(FAM[SC]|HUSB|WIFE|CHIL|SUBM|NOTE)$/ &&
           defined $value &&
           $self->resolve_xref($self->{value}))
    {
      $p .= qq( REF="$value");
      $value = undef;
      $tag = undef unless $sub_items;
    }
    elsif ($self->{xref})
    {
      $p .= qq( ID="$self->{xref}");
    }

    $p .= "/" unless defined $value || $tag;
    $p .= ">";
    $p .= "\n"
      if $sub_items ||
         (!$spaced &&
          (!(defined $value || $tag) || $tag eq "EVEN" || $self->{xref}));
  }

  if (defined $value)
  {
    $p .= "$indent  " if $spaced || $sub_items;
    $p .= $value;
    $p .= "\n"        if $spaced || $sub_items;
  }

  $fh->print($p);

  for my $c (0 .. $sub_items - 1)
  {
    $self->{items}[$c]->write_xml($fh, $level + 1);
  }

  if ($tag)
  {
    $fh->print($indent) if $spaced || $sub_items;
    $fh->print("</$tag>\n");
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

sub get_item
{
  my $self = shift;
  my ($tag, $count) = @_;
  if (wantarray && !$count)
  {
    return grep { $_->{tag} eq $tag } @{$self->_items};
  }
  else
  {
    $count = 1 unless $count;
    for my $c (@{$self->_items})
    {
      return $c if $c->{tag} eq $tag && !--$count;
    }
  }
  undef
}

sub get_child
{
  # NOTE - This function is deprecated - use get_item instead
  my $self = shift;
  my ($t) = @_;
  my ($tag, $count) = $t =~ /^_?(\w+?)(\d*)$/;
  $self->get_item($tag, $count);
}

sub get_children
{
  # NOTE - This function is deprecated - use get_item instead
  my $self = shift;
  $self->get_item(@_)
}

sub parent
{
  my $self = shift;

  my $i = "$self";
  my @records = ($self->{gedcom}{record});

  while (@records)
  {
    my $r = shift @records;
    for (@{$r->_items})
    {
      return $r if $i eq "$_";
      push @records, $r;
    }
  }

  undef
}

sub delete
{
  my $self = shift;

  my $parent = $self->parent;

  return unless $parent;

  $parent->delete_item($self);
}

sub delete_item
{
  my $self = shift;
  my ($item) = @_;

  my $i = "$item";
  my $n = 0;
  for (@{$self->_items})
  {
    last if $i eq "$_";
    $n++;
  }

  return 0 unless $n < @{$self->{items}};

  # print "deleting item $n of $#{$self->{items}}\n";
  splice @{$self->{items}}, $n, 1;
  delete $self->{gedcom}{xrefs}{$item->{xref}} if defined $item->{xref};

  1
}

for my $func (qw(level xref tag value pointer min max gedcom file line))
{
  no strict "refs";
  *$func = sub
  {
    my $self = shift;
    $self->{$func} = shift if @_;
    $self->{$func}
  }
}

sub full_value
{
  my $self = shift;
  my $value = $self->{value};
  $value =~ s/[\r\n]+$// if defined $value;
  for my $item (@{$self->_items})
  {
    my $v = defined $item->{value} ? $item->{value} : "";
    $v =~ s/[\r\n]+$//;
    $value .= "\n$v" if $item->{tag} eq "CONT";
    $value .=    $v  if $item->{tag} eq "CONC";
  }
  $value
}

sub _items
{
  my $self = shift;
  $self->{gedcom}{record}->add_items($self, 1)
    if !defined $self->{_items} && $self->{level} >= 0;
  $self->{_items} = 1;
  $self->{items}
}

sub items
{
  my $self = shift;
  @{$self->_items}
}

sub delete_items
{
  my $self = shift;
  delete $self->{_items};
  delete $self->{items};
}

1;

__END__

=head1 NAME

Gedcom::Item - a base class for Gedcom::Grammar and Gedcom::Record

Version 1.15 - 3rd May 2005

=head1 SYNOPSIS

  use Gedcom::Record;

  $item->{grammar} = Gedcom::Grammar->new(file     => $item->{grammar_file},
                                          callback => $item->{callback});
  my $c = $item->copy;
  $item->read if $item->{file};
  $item->add_items($rec);
  while (my $next = $item->next_item($item))
  my $line = $item->next_line;
  my $line = $item->next_text_line;
  $item->write($fh, $level, $flush);
  $item->write_xml($fh, $level);
  $item->print;
  my $item  = $item->get_item("CHIL", 2);
  my @items = $item->get_item("CHIL");
  my $parent = $item->parent;
  my $success = $item->delete;
  $item->delete_item($sub_item);
  my $v = $item->level;
  $item->level(1);
  my $v = $item->xref;
  my $v = $item->tag;
  my $v = $item->value;
  my $v = $item->pointer;
  my $v = $item->min;
  my $v = $item->max;
  my $v = $item->gedcom;
  my $v = $item->file;
  my $v = $item->line;
  my $v = $item->full_value;
  my $sub_items = $item->_items;
  my @sub_items = $item->items;
  $item->delete_items;

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

=head2 $item->{pointer}

True iff the value is a pointer to another item.

=head2 $item->{min}

The minimum number of items allowed.

=head2 $item->{max}

The maximum number of items allowed.

=head2 $item->{gedcom}

The top level gedcom object.

=head2 $item->{file}

The file from which this object was read, if any.

=head2 $item->{line}

The line number from which this object was read, if any.

=head2 $item->{items}

Array of all sub-items of this item.

It should not be necessary to access these hash members directly.

=head1 METHODS

=head2 new

  $item->{grammar} = Gedcom::Grammar->new(file     => $item->{grammar_file},
                                          callback => $item->{callback});

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

=head2 copy

  my $c = $item->copy;

Make a copy of the object.  The sub-items are copied too.

=head2 read

  $item->read if $item->{file};

Read a file into the object.  Called by the constructor.

=head2 add_items

  $item->add_items($rec);

Read in the sub-items of a item.

=head2 next_item

  while (my $next = $item->next_item($item))

Read the next item from a file.  Return the item or false if it
cannot be read.

=head2 next_line

  my $line = $item->next_line;

Read the next line from the file, and return it or false.

=head2 next_text_line

  my $line = $item->next_text_line;

Read the next line of text from the file, and return it or false.

=head2 write

  $item->write($fh, $level, $flush);

Write the item to a FileHandle.

The subroutine takes three parameters:
  $fh:        The FileHandle to which to write
  $level:     The level of the item
  $flush:     Whether or not to indent the gedcom output according to the level

=head2 write_xml

  $item->write_xml($fh, $level);

Write the item to a FileHandle as XML.

The subroutine takes two parameters:
  $fh:        The FileHandle to which to write
  $level:     The level of the item

Note that this function is experimental.  Please read the warnings for
Gedcom::write_xml().

=head2 print

  $item->print;

Print the item.  Used for debugging.  (What?  There are bugs?)

=head2 get_item

  my $item  = $item->get_item("CHIL", 2);
  my @items = $item->get_items("CHIL");

Get specific sub-items from the item.

The arguments are the name of the tag, and optionally the count.

In scalar context, returns the sub-item, or undef if it doesn't exist.
In array context, returns all sub-items matching the specified tag.

=head2 get_child

NOTE - This function is deprecated - use get_item instead

  my $child = get_child("CHIL2");

Get a specific child item from the item.

The argument contains the name of the tag, and optionally the count.
The regular expression to generate the tag and the count is:

  my ($tag, $count) = $t =~ /^_?(\w+?)(\d*)$/

Returns the child item, or undef if it doesn't exist

=head2 get_children

NOTE - This function is deprecated - use get_item instead

  my @children = get_children("CHIL");

=head2 parent

  my $parent = $item->parent;

Returns the parent of the item or undef if there is none.

Note that this is an expensive function.  A child does not know who its
parent is, and so this function searches through all items looking for
one with the appropriate child.

=head2 delete

  my $success = $item->delete;

Deletes the item.

Note that this is an expensive function.  It use parent() described
above.  It is better to use $parent->delete_item($child), assuming that
you know $parent.

Note too that this function calls delete_item(), so its caveats apply.

=head2 delete_item

  $item->delete_item($sub_item);

Delete the specified sub-item from the item.

Note that this function doesn't do any housekeeping.  It is up to you to
ensure that you don't leave any dangling pointers.

=head2 Access functions

  my $v = $item->level;
  $item->level(1);
  my $v = $item->xref;
  my $v = $item->tag;
  my $v = $item->value;
  my $v = $item->pointer;
  my $v = $item->min;
  my $v = $item->max;
  my $v = $item->gedcom;
  my $v = $item->file;
  my $v = $item->line;

Return the eponymous hash element.  If a value if passed into the
function, the element is first assigned that value.

=head2 full_value

  my $v = $item->full_value;

Return the value of the item including all CONT and CONC lines.  This is
probably what you want most of the time, and is the function called by
default from other functions that return values.  If, for some reason,
you want to process CONT and CONC items yourself, you will need to use
the value() function and probably the items() function.

=head2 _items

  my $sub_items = $item->_items;

Return a reference to alist of all the sub-items, reading them from the
Gedcom file if they have not already been read.

It should not be necessary to use this function.  See items().

=head2 items

  my @sub_items = $item->items;

Return a list of all the sub-items, reading them from the Gedcom file if
they have not already been read.

In general it should not be necessary to use this function.  The
sub-items will usually be accessed by name.  This function is only
necessary if the ordering of the different items is important.  This is
very rare, but is needed for example, when processing CONT and CONC
items.

=head2 delete_items

  $item->delete_items;

Delete all the sub-items, allowing the memory to be reused.  If the
sub-items are required again, they will be reread.

It should not be necessary to use this function unless you are using
read_only mode and need to reclaim your memory.

=cut
