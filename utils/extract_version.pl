#!/usr/bin/perl
use strict;
use warnings;

my $file = shift or die "Usage: $0 filename\n";

while ($file =~ /(\d+(\.\d+)+)/g) {
    print "$1\n";
}
