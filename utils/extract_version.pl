#!/usr/bin/perl
use strict;
use warnings;

while (<>) {
    while (/(\d+(\.\d+)+)/g) {
        print "$1\n";
    }
}
