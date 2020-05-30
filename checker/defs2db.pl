#!/usr/bin/env perl

use warnings;
use strict;

my $DEBUG = 0;
my $SEPERATOR = '---';

use File::Slurp qw(read_file);
use YAML::Any qw(LoadFile Load);
use DBI;
use JSON;
use Data::Dumper;

sub _debug($;@) {
    return unless $ENV{DEBUG} or $DEBUG;
    my ($str, @params) = @_;
    printf "DEBUG $str\n", @params;
}

sub getFrontMatter($) {
    my $str = shift;
    unless(index($str, $SEPERATOR) == 0) {
        warn "Initial separator not found";
        return undef;
    }
    my $next_seperator = index($str, $SEPERATOR, length($SEPERATOR));
    return substr($str, length($SEPERATOR)+1, $next_seperator-length($SEPERATOR)-1);
}

my %fields;

my $db = DBI->connect("DBI:SQLite:dbname=defs.db", '', '', { RaiseError => 1 })
   or die $DBI::errstr;

my $p_def = $db->prepare("
    INSERT INTO definitions
        (title, slug, defined, speech, skip_in_table_of_content, flag_level, flag_text, flag_for)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)"
    );
# my $p_flag = $db->prepare("INSERT INTO flags (title, level, text, for) VALUES (?, ?, ?, ?)");
my $p_readings = $db->prepare("INSERT INTO readings (title, text, href) VALUES (?, ?, ?)");
my $p_alt_words = $db->prepare("INSERT INTO alt_words (title, alt_word) VALUES (?, ?)");
my $p_sub_terms = $db->prepare("INSERT INTO sub_terms (title, text, full_title) VALUES (?, ?, ?)");
my $p_data = $db->prepare("INSERT INTO data (title, yaml, json) VALUES (?, ?, ?)");

while(my $input = shift @ARGV) {
    _debug("Parsing %s", $input);
    my $input_data = read_file($input);
    $input_data =~ s/\r//g;
    my $fm_str = getFrontMatter($input_data);
    my ($fm, @rest) = Load($fm_str);

    $p_def->execute(
        $fm->{title},
        $fm->{slug},
        ($fm->{defined} or 0),
        ($fm->{speech} or 'unknown'),
        ($fm->{skip_in_table_of_content} or '0'),
        $fm->{flag}->{level},
        $fm->{flag}->{text},
        $fm->{flag}->{for},
    );

    foreach my $reading (@{$fm->{reading}}) {
        $p_readings->execute(
            $fm->{title},
            $reading->{text},
            $reading->{href},
        );
    }

    foreach my $alt_word (@{$fm->{alt_words}}) {
        $p_alt_words->execute(
            $fm->{title},
            $alt_word,
        );
    }

    foreach my $sub_term (@{$fm->{sub_terms}}) {
        $p_sub_terms->execute(
            $fm->{title},
            $sub_term->{text},
            $sub_term->{full_title},
        );
    }

    $p_data->execute($fm->{title}, $fm_str, encode_json($fm));
}

$db->disconnect;