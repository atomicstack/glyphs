#!/usr/bin/env perl

use 5.36.0;
use strict;
use warnings;

use charnames qw//;
use Data::Dumper qw/Dumper/;
use Fcntl qw/O_WRONLY O_CREAT O_EXCL/;
use JSON::XS qw/encode_json/;
use POSIX qw/strftime/;

################################################################################
################################################################################

sub safe_write($output_filename, $content) {
  my $output_filehandle = IO::File->new($output_filename, O_WRONLY | O_CREAT | O_EXCL)
    or die "couldn't create $output_filename: $!\n";

  binmode($output_filehandle, ":utf8");

  $output_filehandle->print($content)
    or die "couldn't write to $output_filename: $!";

  $output_filehandle->close
    or die "couldn't close $output_filename: $!";
}

################################################################################
################################################################################

sub filename_with_timestamp ($filename) {
  my $now = POSIX::strftime('%F-%T', localtime);
  return "${filename}.${now}";
}

################################################################################
################################################################################

my $json = JSON::XS->new->pretty(1)->canonical(1);

################################################################################
################################################################################

my $unicode_filename = 'UnicodeData.txt';
my $url = "http://unicode.org/Public/UNIDATA/$unicode_filename";

my @file;
if (-f $unicode_filename) {
  say "using local copy of $unicode_filename";
  @file = IO::File->new($unicode_filename => 'r')->getlines;
}
else {
  say "fetching $url...";
  @file = split /\n/ => qx{curl -s $url};
}

chomp( my @unicode_definitions = @file );

################################################################################
################################################################################

my @key_names = qw/
  value
  name
  category
  class
  bidirectional_category
  mapping
  decimal_digit_value
  digit_value
  numeric_value
  mirrored
  unicode_name
  comment
  uppercase_mapping
  lowercase_mapping
  titlecase_mapping
/;

my %category_is_blacklisted = map { $_ => 1 } qw/
  Cc Cf Co Cs
  LC Ll Lm Lo Lt Lu
  Mc Me Mn Md
  Nd Nl
  Zs
/;
################################################################################
################################################################################

my @canonical;
my @materialised;

my $index = 0;

foreach my $line (@unicode_definitions) {
  my %h;
  my @v = split /;/ => $line;
  @h{@key_names} = @v;
  (defined $h{name} and $h{value} and $h{category}) or die "failed to parse line: $line";
  next if hex($h{value}) <= 255;
  next if $category_is_blacklisted{ $h{category} };

  $h{name}  = ucfirst( lc $h{name} );
  $h{index} = $index++;
  $h{icon}  = charnames::string_vianame("U+$h{value}");

  push @canonical => \%h;
  push @materialised => { name => $h{name}, icon => $h{icon} };
}

################################################################################
################################################################################

my $canonical_filename = filename_with_timestamp( 'canonical-glyphs.json' );
safe_write($canonical_filename => $json->encode(\@canonical));
say "wrote @{[ int scalar @canonical ]} glyphs to $canonical_filename";

my $materialised_filename = filename_with_timestamp( 'glyphs.json' );
safe_write($materialised_filename => $json->encode(\@materialised));
say "wrote @{[ int scalar @materialised ]} glyphs to $materialised_filename";

################################################################################
################################################################################
