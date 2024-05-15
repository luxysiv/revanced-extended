#!/usr/bin/perl

use strict;
use warnings;

sub process_patches {
    my ($name, $lines_ref, $include_ref, $exclude_ref) = @_;

    foreach my $line (@$lines_ref) {
        if ($line =~ /^[+\-]\s*(\S+)/) {
            my $patch_name = $1;
            if ($line =~ /^\+/) {
                push @$include_ref, "--include", $patch_name;
            } elsif ($line =~ /^\-/) {
                push @$exclude_ref, "--exclude", $patch_name;
            }
        }
    }
}

# Main script
my $name = $ARGV[0];
open(my $fh, '<', "./etc/$name-patches.txt") or die "Cannot open file: $!";
my @lines = <$fh>;
close($fh);

my @include_patches;
my @exclude_patches;

process_patches($name, \@lines, \@include_patches, \@exclude_patches);

# Output processed patches (for debugging)
print "Include patches:\n";
print join("\n", @include_patches), "\n";

print "Exclude patches:\n";
print join("\n", @exclude_patches), "\n";
