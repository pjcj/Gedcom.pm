# Copyright 1999-2005, Paul Johnson (pjcj@cpan.org)

# This software is free.  It is licensed under the same terms as Perl itself.

# The latest version of this software should be available from my homepage:
# http://www.pjcj.net

# documentation at __END__

use strict;

require 5.005;

package Gedcom::LifeLines;

use Exporter;
BEGIN
{                                        # We'll use these if they are available
  eval "use Date::Manip";
  eval "use Roman ()";
}

use Gedcom 1.15;

use vars qw($VERSION @ISA @EXPORT);
$VERSION = "1.15";
@ISA     = qw( Exporter );
@EXPORT  = qw
(
  set_ged display flush
  name fullname surname givens trimname
  birth death baptism burial
  father mother nextsib prevsib
  sex male female pn
  nspouses nfamilies parents
  title key soundex inode root
  indi firstindi nextindi previndi
  marriage husband wife nchildren firstchild lastchild fnode
  fam firstfam nextfam prevfam
  xref tag value parent child sibling
  savenode
  date place year long short gettoday
  dayformat monthformat dateformat stddate
  extractdate extractnames extractplaces extracttokens
  getindi getindiset getfam getint getstr
  getindimsg getintmsg getstrmsg
  choosechild choosefam chooseindi choosesubset
  menuchoose
  lower upper capitalize trim rjustify
  save strsave concat strconcat strlen
  substring index
  d card ord alpha roman
  strsoundex
  strtoint atoi
  strcmp eqstr nestr
  linemode pagemode col row pos pageout
  nl sp qt
  newfile outfile
  copyfile print
  addtoset deletefromset lengthset
  union intersect difference
  parentset childset spouseset siblingset
  ancestorset descendentset descendantset
  uniqueset namesort keysort valuesort
  genindiset gengedcom
  createnode addnode deletenode
  reference dereference getrecord
  lock unlock
  database version
  system
);

my ($Day_format, $Month_format, $Date_format)   = (0, 0, 0);
my ($Line_mode, $Rows, $Columns, $Row, $Column) = (1, 0, 0, 0, 0);
my ($Line, @Lines) = ("");

my $Ged;

sub set_ged
{
  $Ged = shift
}

sub display
{
  my ($text) = @_;
  return unless defined $text && length $text;
  if ($Line_mode)
  {
    $Line .= $text;
    print $1 if $Line =~ s/^(.*\n)//s;
  }
  else
  {
    # print STDERR "$Row, $Column: <$text>\n";
    $Lines[$Row] .= " " x ($Column - length $Lines[$Row]);
    substr $Lines[$Row], $Column, length $text, $text;
    $Column += length $text;
  }
  return
}

sub flush
{
  if ($Line_mode)
  {
    print $Line;
    $Line = "";
  }
  else
  {
    pageout();
  }
  return
}

sub name
{
  my ($indi, $cased) = @_;
  return unless $indi;
  my $name = !defined $cased || $cased ? $indi->cased_name : $indi->name;
  $name =~ s|/||g;
  $name
}

sub fullname
{
  my ($indi, $cased, $inorder, $length) = @_;
  return unless $indi;
  my $name = $inorder
    ? name($indi, $cased)
    : ($cased ? uc $indi->surname : $indi->surname) . ", " . $indi->given_names;
  $name = substr $name, 0, $length if defined $length;
  $name
}

sub surname
{
  my ($indi) = @_;
  return unless $indi;
  $indi->surname
}

sub givens
{
  my ($indi) = @_;
  return unless $indi;
  $indi->given_names
}

sub trimname
{
  my ($indi, $length) = @_;
  return unless $indi;
  substr $indi->name, 0, $length
}

sub birth
{
  my ($indi) = @_;
  return unless $indi;
  $indi->tag_record("BIRT")
}

sub death
{
  my ($indi) = @_;
  return unless $indi;
  $indi->tag_record("DEAT")
}

sub baptism
{
  my ($indi) = @_;
  return unless $indi;
  $indi->tag_record("BAPM") ||
  $indi->tag_record("BAPL") ||
  $indi->tag_record("CHR")
}

sub burial
{
  my ($indi) = @_;
  return unless $indi;
  $indi->tag_record("BURI")
}

sub father
{
  my ($indi) = @_;
  return undef unless $indi;
  scalar $indi->father
}

sub mother
{
  my ($indi) = @_;
  return undef unless $indi;
  scalar $indi->mother
}

sub nextsib
{
  my ($indi) = @_;
  return undef unless $indi;
  scalar $indi->younger_siblings
}

sub prevsib
{
  my ($indi) = @_;
  return undef unless $indi;
  scalar $indi->older_siblings
}

sub sex
{
  my ($indi) = @_;
  return unless $indi;
  $indi->sex
}

sub male
{
  my ($indi) = @_;
  return unless $indi;
  $indi->sex eq "M"
}

sub female
{
  my ($indi) = @_;
  return unless $indi;
  $indi->sex eq "F"
}

sub pn
{
  my ($indi, $type) = @_;
  return unless $indi;
  (qw(He She he she His Her his her him her))[$type * 2 +
                                              ($indi->sex eq "F" ? 1 : 0)]
}

sub nspouses
{
  my ($indi) = @_;
  return unless $indi;
  my @a = $indi->spouse;
  scalar @a
}

sub nfamilies
{
  my ($indi) = @_;
  return unless $indi;
  my @a = $indi->fams;
  scalar @a
}

sub parents
{
  my ($indi) = @_;
  return unless $indi;
  my $a = $indi->famc;
  $a
}

sub title
{
  my ($indi) = @_;
  return unless $indi;
  $indi->tag_value("TITL")
}

sub key
{
  my ($record, $type) = @_;
  return unless $record;
  my $key = $record->xref;
  $key =~ s/^[a-z]*//i if $type;
  $key
}

sub soundex
{
  my ($indi) = @_;
  return unless $indi;
  $indi->soundex
}

sub inode
{
  my ($indi) = @_;
  $indi;
}

sub root
{
  my ($record) = @_;
  $record;
}

sub indi
{
  my ($name) = @_;
  $Ged->get_individual($name)
}

sub firstindi
{
  (sort { key($a, 1) <=> key($b, 1) } $Ged->individuals)[0]
}

sub nextindi
{
  my ($indi) = @_;
  return unless $indi;
  my @a = sort { key($a, 1) <=> key($b, 1) } $Ged->individuals;
  my $i;
  for ($i = 0; $i <= $#a; $i++)
  {
    last if $a[$i]->{xref} eq $indi->{xref}
  }
  splice @a, 0, $i + 1;
  wantarray ? @a : $a[0]
}

sub previndi
{
  my ($indi) = @_;
  return unless $indi;
  my @a = sort { key($a, 1) <=> key($b, 1) } $Ged->individuals;
  my $i;
  for ($i = 0; $i <= $#a; $i++)
  {
    last if $a[$i]->{xref} eq $indi->{xref}
  }
  splice @a, $i;
  wantarray ? @a : $a[-1]
}

sub marriage
{
  my ($fam) = @_;
  return unless $fam;
  $fam->marr
}

sub husband
{
  my ($fam) = @_;
  return undef unless $fam;
  scalar $fam->husband
}

sub wife
{
  my ($fam) = @_;
  return undef unless $fam;
  scalar $fam->wife
}

sub nchildren
{
  my ($fam) = @_;
  return unless $fam;
  $fam->number_of_children
}

sub firstchild
{
  my ($fam) = @_;
  return undef unless $fam;
  scalar $fam->children
}

sub lastchild
{
  my ($fam) = @_;
  return undef unless $fam;
  scalar $fam->children
}

sub fnode
{
  my ($fam) = @_;
  $fam;
}

sub fam
{
  my ($xref) = @_;
  $Ged->resolve_xref($xref)
}

sub firstfam
{
  (sort { key($a, 1) <=> key($b, 1) } $Ged->families)[0]
}

sub nextfam
{
  my ($fam) = @_;
  return unless $fam;
  my @a = sort { key($a, 1) <=> key($b, 1) } $Ged->families;
  my $i;
  for ($i = 0; $i <= $#a; $i++)
  {
    last if $a[$i]->{xref} eq $fam->{xref}
  }
  splice @a, 0, $i + 1;
  wantarray ? @a : $a[0]
}

sub prevfam
{
  my ($fam) = @_;
  return unless $fam;
  my @a = sort { key($a, 1) <=> key($b, 1) } $Ged->families;
  my $i;
  for ($i = 0; $i <= $#a; $i++)
  {
    last if $a[$i]->{xref} eq $fam->{xref}
  }
  splice @a, $i;
  wantarray ? @a : $a[-1]
}

sub xref
{
  my ($record) = @_;
  return unless $record;
  $record->xref
}

sub tag
{
  my ($record) = @_;
  return unless $record;
  $record->tag
}

sub value
{
  my ($record) = @_;
  return unless $record;
  $record->full_value
}

sub parent
{
  my ($record) = @_;
  return unless $record;
  $record->parent
}

sub child
{
  my ($record) = @_;
  return unless $record;
  $record->_items()->[0]
}

sub sibling
{
  my ($record) = @_;
  return unless $record;

  my $parent = $record->parent;
  return unless $parent;

  my $r = "$record";
  my $n = 0;
  for (@{$parent->_items})
  {
    last if $r eq "$_";
    $n++;
  }

  return unless $n < $#{$parent->{items}};

  $parent->{items}[$n + 1]
}

sub savenode
{
  my ($record) = @_;
  return unless $record;
  $record->copy
}

sub date
{
  my ($event) = @_;
  return unless $event;
  $event->date || ""
}

sub place
{
  my ($event) = @_;
  return unless $event;
  $event->place || ""
}

sub year
{
  my ($event) = @_;
  return unless $event;
  $event->date =~ /(\d{3,4})/;
  $1 || "";
}

sub long
{
  my ($event) = @_;
  return unless $event;
  date($event) . ", " . place($event)
}

sub short
{
  my ($event) = @_;
  return unless $event;
  year($event) . ", " . ((split(/,\s*/, place($event)))[-1] || "")
}

sub gettoday
{
  my $event = Gedcom::Event->new(gedcom => $Ged);
  $event->add("date", uc join " ", (localtime)[2, 1, 4])
}

sub dayformat
{
  $Day_format = shift || 0;
  return;
}

sub monthformat
{
  $Month_format = shift || 0;
  return;
}

sub dateformat
{
  $Date_format = shift || 0;
  return;
}

sub stddate
{
  my ($event) = @_;
  my $date = date($event);
  return "" unless $date;
  unless ($INC{"Date/Manip.pm"})
  {
    warn "Date::Manip.pm is required to use stddate()";
    return $date;
  }
  my $dt = ParseDate($date);
  my $d = UnixDate($dt, $Day_format == 1 ? "%d" : "%e");
  $d = int $d if $Day_format == 2;
  my $m = UnixDate($dt, $Month_format > 4
                        ? "%B"
                        : $Month_format > 2
                          ? "%b"
                          : $Month_format == 1
                            ? "%m"
                            : "%f");
  $m = int $m if $Month_format == 2;
  $m = uc  $m if $Month_format == 3 || $Month_format == 5;
  my $y = UnixDate($dt, "%Y");
  (
    "$d $m $y",
    "$m $d, $y",
    "$m/$d/$y",
    "$d/$m/$y",
    "$m-$d-$y",
    "$d-$m-$y",
    "$m$d$y",
    "$d$m$y",
    "$y $m $d",
    "$y/$m/$d",
    "$y-$m-$d",
    "$y$m$d",
  )[$Date_format]
}

sub extractdate
{
  my $record =  shift;
  return unless $record;
  my $d      = \shift;
  my $m      = \shift;
  my $y      = \shift;
  $$d = $$m = $$y = 0;
  my $date = $record->tag eq "DATE" ? $record->full_value : $record->date;
  return unless $date;
  unless ($INC{"Date/Manip.pm"})
  {
    warn "Date::Manip.pm is required to use extractdate()";
    return;
  }
  my $dt = ParseDate($date);
  return unless $dt;
  $$d = int UnixDate($dt, "%e");
  $$m = int UnixDate($dt, "%f");
  $$y = int UnixDate($dt, "%Y");
  return
}

sub extractnames
{
  my $record  =  shift;
  my $names   = \shift;
  my $count   = \shift;
  my $surname = \shift;
  $$names = [];
  $$count = $$surname = 0;
  my $name = $record->tag eq "NAME" ? $record->full_value : $record->name;
  return unless $name;

  my ($before, $sn, $after) = split "/", $name;
  my @bf    = split " ", $before;
  my @af    = split " ", $after;
  $$count   = @bf + @af; $$count++ if $sn;
  $$names   = [@bf, $sn || (), @af];
  $$surname = $sn ? @bf + 1 : 0;

  # print "[$name] [", join("|", @$$names), "], $$count, $$surname, \n";
  return
}

sub extractplaces
{
  my $record =  shift;
  my $places = \shift;
  my $count  = \shift;
  $$places = [];
  $$count  = 0;
  my $place = $record->tag eq "PLACE" ? $record->full_value : $record->place;
  return unless $place;
  @$$places = split /\s*,\s*/, $place;
  $$count   = scalar @$$places;
  return
}

sub extracttokens
{
  my $string     =  shift;
  my $tokens     = \shift;
  my $count      = \shift;
  my $delimiters =  shift;
  $$tokens = [];
  $$count  = 0;
  return unless $string;
  @$$tokens = split /[\Q$delimiters\E]/, $string;
  $$count   = scalar @$$tokens;
  return
}

sub getindi
{
  my $indi   = \shift;
  my $string =  shift || "Please specify an individual";
  print STDERR $string, " ";
  my $i = <STDIN>;
  chomp $i;
  # print "looking for $i\n";
  $$indi = indi($i);
  # print "found $$indi - ", $$indi->name, "\n";
  return
}

sub getindimsg
{
  getindi(@_)
}

sub getindiset
{
  die "LifeLines getindiset function not yet implemented"
}

sub getfam
{
  my $fam = \shift;
  my $string =  shift || "Please enter a family:";
  print STDERR $string, " ";
  my $f = <STDIN>;
  chomp $f;
  $$fam = $Ged->resolve_xref($f) ||
          $Ged->resolve_xref(uc $f) ||
          $Ged->resolve_xref("F$f");
  return
}

sub getint
{
  my $number = \shift;
  my $string =  shift || "Please enter an integer:";
  print STDERR $string, " ";
  $$number = <STDIN>;
  chomp $$number;
  return
}

sub getintmsg
{
  getint(@_)
}

sub getstr
{
  my $str    = \shift;
  my $string =  shift || "Please enter a string:";
  print STDERR $string, " ";
  $$str = <STDIN>;
  return
}

sub getstrmsg
{
  getstr(@_)
}

sub choosechild
{
  die "LifeLines choosechild function not yet implemented"
}

sub choosefam
{
  die "LifeLines choosefam function not yet implemented"
}

sub chooseindi
{
  die "LifeLines chooseindi function not yet implemented"
}

sub choosesubset
{
  die "LifeLines choosesubset function not yet implemented"
}

sub menuchoose
{
  die "LifeLines menuchoose function not yet implemented"
}

sub lower
{
  my ($string) = @_;
  lc $string
}

sub upper
{
  my ($string) = @_;
  uc $string
}

sub capitalize
{
  my $string = \shift;
  $$string = ucfirst $$string
}

sub trim
{
  my ($string, $length) = @_;
  substr $string, 0, $length
}

sub rjustify
{
  my ($string, $length) = @_;
  $string = substr $string, 0, $length;
  " " x ($length - length $string) . $string
}

sub save
{
  my ($string) = @_;
  $string
}

sub strsave
{
  my ($string) = @_;
  $string
}

sub concat
{
  join "", @_
}

sub strconcat
{
  join "", @_
}

sub strlen
{
  my ($string) = @_;
  length $string
}

sub substring
{
  my ($string, $start, $end) = @_;
  substr $string, $start - 1, $end - $start + 1
}

sub index
{
  my ($string, $substring, $occurrence) = @_;
  my $pos = 0;
  while ($occurrence-- && ($pos = index $string, $substring, $pos) >= 0) {}
  $pos + 1
}

sub d
{
  my ($number) = @_;
  $number ? int $number : 0
}

sub card
{
  my ($number) = @_;
  my @cardinals = qw
  (
    zero one two three four five six seven eight nine ten eleven twelve
  );

  $number < 0 || $number > $#cardinals ? $number : $cardinals[$number]
}

sub ord
{
  my ($number) = @_;
  my @ordinals = qw
  (
    zeroth first second third fourth fifth sixth
    seventh eighth ninth tenth eleventh twelfth
  );
  my @suffixes = qw( th st nd rd th th th th th th );

  return if $number < 0;
  return $ordinals[$number] if $number < @ordinals;
  my $n = $number % 100;
  return $number . "th" if $n < 10 && $n < 14;
  return $number . $suffixes[$number % 10];
}

sub alpha
{
  my ($number) = @_;
  chr CORE::ord 'a' - $number
}

sub roman
{
  my ($number) = @_;
  unless ($INC{"Roman.pm"})
  {
    warn "Roman.pm is required to use roman()";
    return $number;
  }
  Roman::roman($number)
}

sub strsoundex
{
  my ($string) = @_;
  Gedcom::soundex($string)
}

sub strtoint
{
  my ($string) = @_;
  local $^W;
  int $string
}

sub atoi
{
  strtoint(@_)
}

sub strcmp
{
  my ($string1, $string2) = @_;
  $string1 cmp $string2
}

sub eqstr
{
  my ($string1, $string2) = @_;
  $string1 eq $string2
}

sub nestr
{
  my ($string1, $string2) = @_;
  $string1 ne $string2
}

sub linemode
{
  $Line_mode = 1;
  return
}

sub pagemode
{
  my ($rows, $columns) = @_;
  $Line_mode = 0;
  $Rows      = $rows    || 0;
  $Columns   = $columns || 0;
  $#Lines    = $Rows;
  $Lines[$_] = "" for 0..$Rows - 1;
  return
}

sub col
{
  my ($column) = @_;
  $column--;
  if ($Line_mode)
  {
    display(length $Line > $column
            ? "\n" . " " x $column
            : " " x ($column - length $Line))
  }
  else
  {
    $Column = $column
  }
  return
}

sub row
{
  my ($row) = @_;
  unless ($Line_mode)
  {
    $Row = $row - 1;
    $Column = 0;
  }
  return
}

sub pos
{
  my ($row, $column) = @_;
  ($Row, $Column) = ($row - 1, $column - 1) unless $Line_mode;
  return
}

sub pageout
{
  # print join "\n", map { substr($_, 0, $Columns) } @Lines[0..$Rows - 1];
  print substr($Lines[$_], 0, $Columns), "\n" for 0..$Rows - 1;
  $Lines[$_] = "" for 0..$Rows - 1;
  $Row = $Column = 0;
  return
}

sub nl
{
  "\n"
}

sub sp
{
  " "
}

sub qt
{
  '"'
}

{
  my $Openfile;

  sub newfile
  {
    my ($filename, $append) = @_;

    flush();
    my $mode = $append ? ">>" : ">";
    open LLOUT, "$mode$filename" or die "Cannot open $filename\n";
    select LLOUT;
    $Openfile = $filename;
    return;
  }

  sub outfile
  {
    $Openfile
  }
}

sub copyfile
{
  my ($file) = @_;
  $file = "$ENV{LLPROGRAMS}/$file" unless -e $file;
  unless (open(F, $file))
  {
    warn "Error: Cannot open file $file in copyfile: $!";
    return;
  }
  print while <F>;
  close F or warn "Error: Cannot close file $file in copyfile: $!";
}

sub print
{
  print STDERR @_;
  return
}

sub addtoset
{
  my ($set, $indi, $data) = @_;
  push @$set, [$indi, $data];
  return
}

sub deletefromset
{
  my ($set, $indi, $all) = @_;
  my $count = 0;
  my @new = grep
  {
    my $keep = ($count && !$all) || $_->[0] ne $indi;
    $count++ unless $keep;
    $keep
  } @$set;
  $_[0] = \@new;
  return
}

sub lengthset
{
  my ($set) = @_;
  scalar @$set
}

sub union
{
  my ($s1, $s2) = @_;
  my %s;
  for my $e (@$s1, @$s2)
  {
    $s{$e->[0]} = $e->[1] unless exists $s{$e->[0]}
  }
  my @s;
  while (my ($indi, $data) = each %s)
  {
    push @s, [$indi, $data]
  }
  \@s
}

sub intersect
{
  my ($s1, $s2) = @_;
  my (%s1, %s2);
  for my $e (@$s1)
  {
    $s1{$e->[0]} = $e->[1] unless exists $s1{$e->[0]}
  }
  for my $e (@$s2)
  {
    $s2{$e->[0]} = $e->[1] unless exists $s2{$e->[0]}
  }
  my @s;
  while (my ($indi, $data) = each %s1)
  {
    push @s, [$indi, $data] if exists $s2{$indi}
  }
  \@s
}

sub difference
{
  my ($s1, $s2) = @_;
  my (%s1, %s2);
  for my $e (@$s1)
  {
    $s1{$e->[0]} = $e->[1] unless exists $s1{$e->[0]}
  }
  for my $e (@$s2)
  {
    $s2{$e->[0]} = $e->[1] unless exists $s2{$e->[0]}
  }
  my @s;
  while (my ($indi, $data) = each %s1)
  {
    push @s, [$indi, $data] unless exists $s2{$indi}
  }
  \@s
}

sub parentset
{
  my ($set) = @_;
  [ map { my ($i, $d) = @$_; map { [ $_ => $d ] } $i->parents } @$set ]
}

sub childset
{
  my ($set) = @_;
  [ map { my ($i, $d) = @$_; map { [ $_ => $d ] } $i->children } @$set ]
}

sub spouseset
{
  my ($set) = @_;
  [ map { my ($i, $d) = @$_; map { [ $_ => $d ] } $i->spouse } @$set ]
}

sub siblingset
{
  my ($set) = @_;
  [ map { my ($i, $d) = @$_; map { [ $_ => $d ] } $i->siblings } @$set ]
}

sub ancestorset
{
  my ($set) = @_;
  # TODO - set the data appropriatly
  [ map { my $c = $_->[0]; map { [ $_ => 0 ] } $c->ancestors } @$set ]
}

sub descendentset
{
  my ($set) = @_;
  # TODO - set the data appropriatly
  [ map { my $c = $_->[0]; map { [ $_ => 0 ] } $c->descendents } @$set ]
}

sub descendantset
{
  descendentset(@_)
}

sub uniqueset
{
  my ($set) = @_;
  union($set, [])
}

sub namesort
{
  my ($set) = @_;
  @$set = sort { fullname($a->[0]) cmp fullname($b->[0]) } @$set;
  return
}

sub keysort
{
  my ($set) = @_;
  @$set = sort { key($a->[0]) cmp key($b->[0]) } @$set;
  return
}

sub valuesort
{
  my ($set) = @_;
  # TODO - should this be cmp?
  @$set = sort { $a->[1] <=> $b->[1] } @$set;
  return
}

sub genindiset
{
  my $name = shift;
  my $set  = \shift;
  $$set = [ map { $_ => 0 } $Ged->get_individual($name) ];
  return
}

sub gengedcom
{
  my ($set) = @_;
  die "LifeLines gengedcom function not yet implemented"
}

sub createnode
{
  die "LifeLines createnode function not yet implemented"
}

sub addnode
{
  die "LifeLines addnode function not yet implemented"
}

sub deletenode
{
  die "LifeLines deletenode function not yet implemented"
}

sub reference
{
  my ($ref) = @_;
  $Ged->resolve_xref($ref)
}

sub dereference
{
  my ($ref) = @_;
  $Ged->resolve_xref($ref)
}

sub getrecord
{
  dereference(@_)
}

sub lock
{
  return
}

sub unlock
{
  return
}

sub database
{
  $Ged->{file}
}

sub version
{
  $VERSION
}

sub system
{
  system(@_)
}

1;

__END__

=head1 NAME

Gedcom::LifeLines - functions for lines2perl

Version 1.15 - 3rd May 2005

=head1 SYNOPSIS

  use Gedcom::LifeLines;

=head1 DESCRIPTION

A selection of subroutines to emulate Lifelines functions.

For details about the functions, see the Lifelines documentation.

I general, this module should only be used by the output of the
lines2perl program.  Anything in here that finds a more general use
should probably be abstracted away to one of the more standard modules.

Functions yet to be implemented include:
  sibling()
  getindiset()
  choosechild()
  choosefam()
  chooseindi()
  choosesubset()
  menuchoose()
  gengedcom()
  createnode()
  addnode()
  deletenode()

=cut
