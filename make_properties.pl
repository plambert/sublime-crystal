#!/usr/bin/env perl

# create sublime snippet files for crystal property macros

use Modern::Perl 2016;
use Path::Tiny;
use FindBin;

sub parse_opts {
  my $opts={};
  if ('HASH' eq ref $_[0]) {
    my $hashref=shift @_;
    while(my ($k, $v) = each %$hashref) {
      $opts->{$k}=$v;
    }
  }
  if (scalar(@_) % 2 == 1) {
    $opts->{type} = shift @_;
  }
  while (1 < @_) {
    my ($k, $v) = (shift(@_), shift(@_));
    $opts->{$k}=$v;
  }
  return $opts;
}

sub findidx {
  my $template=shift;
  my $idx=1;
  while($template =~ m{(?<!\\)\$(?|\{(\d+)|(\d+))}g) {
    my $newidx=+$1;
    $idx = 1+$newidx unless $idx > $newidx;
  }
  return $idx;
}

sub guess_trigger {
  my ($macro, $nil) = @_;
  my $trigger;
  state $triggers = { property => 'prop', getter => 'get', setter => 'set' };
  if ($triggers->{$macro}) {
    $trigger = $triggers->{$macro};
  }
  else {
    $trigger = substr($macro, 0, 4);
  }
  $trigger .= '?' if $nil;
  return $trigger;
}

sub write_snippet {
  my $opts=parse_opts(@_);
  my $macro = $opts->{macro} // "property";
  my $type = $opts->{type} // die "need a type";
  my $desc = $opts->{desc} // $type;
  my $nillable = $opts->{nillable} // undef;
  my $boolean = $opts->{boolean} // undef;
  my $newable = $opts->{new} ? $opts->{new} : undef;
  my $trigger = $opts->{trigger} // guess_trigger($macro, $nillable);

  if ($type =~ m{^[A-Za-z0-9_]+\(.*\)$} and not defined $newable) {
    $newable = "${type}.new"
  }
  elsif (defined $newable and $newable =~ /\}/) {
    $newable =~ s{\}}{\\\}}g;
  }

  my $nilsuffix = $nillable ? "?" : "";
  my $macroname = "${macro}${nilsuffix}";

  my $idx = findidx($type);
  my $file;
  if ($desc) {
    $file=path("${macroname} (${desc}).sublime-snippet" =~ s{/}{_}gr);
  }
  else {
    $file=path("${macroname}.sublime-snippet" =~ s{/}{_}gr);
  }

  say $file;

  my $io=$file->openw_utf8;

  local *STDOUT = $io;

  say "<snippet>";
  say "  <content><![CDATA[";
  if ($newable) {
    say "${macroname} \${1:attribute_name} : ${type}\${${idx}: = ${newable}}";
    $idx += 1;
  }
  else {
    say "${macroname} \${1:attribute_name} : ${type}";
  }
  say "\$0]]></content>";
  if ($desc) {
    say "  <description>${macroname} ($desc)</description>";
  }
  else {
    say "  <description>${macroname} (...)</description>";
  }
  say "  <tabTrigger>${trigger}</tabTrigger>";
  say "  <scope>source.crystal</scope>";
  say "</snippet>";

  $io->close;
}

sub write_snippets {
  my $opts=parse_opts(@_);
  my $macros = delete($opts->{macros}) // [ qw{property getter setter} ];
  for my $macro (@$macros) {
    if (defined $opts->{nillable}) {
      write_snippet({%$opts, macro => $macro});
    }
    else {
      write_snippet({%$opts, nillable => undef, macro => $macro});
      write_snippet({%$opts, nillable => 1, macro => $macro});
    }
  }
}

my $basedir=path $FindBin::Bin, "snippets";

$basedir->mkpath;
chdir($basedir) or die "${basedir}: could not chdir: $!\n";

for my $type (qw{Char String Time}) {
  write_snippets $type;
}

write_snippets type => "Bool", nillable => 1;

write_snippets desc => "Int", type => 'Int${2:32}';
write_snippets desc => "UInt", type => 'UInt${2:32}';

write_snippets desc => "Float", type => 'Float${2:32}';

write_snippets desc => "Array", type => 'Array(${2:String})', new => '[] of $2';
write_snippets desc => "Hash", type => 'Hash(${2:String}, ${3:String})', new => '{} of $2 => $3';
