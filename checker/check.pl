#!/usr/bin/env perl

use warnings;
use strict;
use Data::Dumper;

my $DEBUG = 0;
my $URL_BASE = 'https://www.selfdefined.app/definitions';

use DBI;
my $db = DBI->connect('DBI:SQLite:dbname=defs.db', '', '', { RaiseError => 1 })
   or die $DBI::errstr;

my $p_lookup = $db->prepare('SELECT word, ref FROM words WHERE word LIKE ?');
my %words;
sub lookup($) {
    my $word = shift;
    if($words{lc $word}) {
        $words{lc $word}{count}++;
        print STDERR $words{lc $word}{NO} ? '.' : '=' if $ENV{PROGRESS};
        return;
    }

    my $res = $p_lookup->execute($word);
    while (my $row = $p_lookup->fetchrow_hashref) {
        $words{lc $word}{count}++;
        $words{lc $row->{word}}{ref} = $row->{ref};
        print STDERR '+' if $ENV{PROGRESS};
        return;
    }

    $words{lc $word}{NO}++;
    print STDERR '.' if $ENV{PROGRESS};
}

# Process input
while(my $line = <>) {
    foreach my $word (split(/\s+/, $line)) {
        lookup($word);
    }
}

# Report
print join(',', qw(word count flag_level flag_text flag_for url)), "\n";
my $p_word = $db->prepare('SELECT title, slug, flag_level, flag_text, flag_for FROM definitions WHERE title LIKE ?');
foreach my $word (keys %words) {
    next if $words{$word}{NO};
    if($words{$word}{ref}) {
        $p_word->execute($words{$word}{ref});
    } else {
        $p_word->execute($word);
    }
    my $row = $p_word->fetchrow_hashref();
    printf "%s,%d,%s,%s,%s,${URL_BASE}/%s\n",
        lc $word,
        $words{$word}{count},
        ($row->{flag_level} or ''),
        ($row->{flag_text} or ''),
        ($row->{flag_for} or ''),
        $row->{slug}
    ;

}