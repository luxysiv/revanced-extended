#!/usr/bin/perl
use strict;
use warnings;
use File::Glob ':glob';
use File::Find;
use Cwd;
use File::Spec;

# Subroutine to get environment variables
sub get_env_var {
    my ($var) = @_;
    my $value = $ENV{$var} or die "$var not set in environment";
    return $value;
}

# Subroutine to process patches
sub process_patches {
    my ($name) = @_;
    my @optionsPatches = `perl utils/process_patches.pl $name`;
    chomp @optionsPatches;
    return @optionsPatches;
}

# Subroutine to find files using wildcard patterns
sub find_files {
    my ($pattern) = @_;
    my ($file) = bsd_glob($pattern);
    return $file;
}

# Subroutine to construct and execute a command
sub execute_cmd {
    my ($cmd) = @_;
    system($cmd) == 0 or die "Failed to execute: $cmd";
}

# Subroutine to find apksigner
sub find_apksigner {
    my $android_sdk_root = shift;
    my $apksigner;
    find(sub {
        if ($_ eq 'apksigner' && -f $_) {
            $apksigner = $File::Find::name;
        }
    }, File::Spec->catdir($android_sdk_root, 'build-tools'));
    die "apksigner not found" unless $apksigner;
    return $apksigner;
}

# Main logic
sub main {
    # Get command-line arguments
    my ($name) = @ARGV;
    die "Usage: $0 <name>" unless $name;

    # Get environment variables
    my $version = get_env_var('VERSION');
    my $android_sdk_root = get_env_var('ANDROID_SDK_ROOT');

    # Process patches
    my @optionsPatches = process_patches($name);

    # Find necessary files
    my $cli_jar = find_files("revanced-cli*.jar");
    my $integrations_apk = find_files("revanced-integrations*.apk");
    my $patches_jar = find_files("revanced-patches*.jar");

    # Construct and execute patch command
    my $patch_cmd = "java -jar $cli_jar patch "
                  . "--merge $integrations_apk "
                  . "--patch-bundle $patches_jar "
                  . "--out patched-$name-v$version.apk "
                  . "@optionsPatches "
                  . "$name-v$version.apk";
    execute_cmd($patch_cmd);

    # Remove the original APK
    unlink "$name-v$version.apk" or warn "Could not unlink $name-v$version.apk: $!";

    # Find apksigner tool
    my $apksigner = find_apksigner($android_sdk_root);

    # Construct and execute sign command
    my $input_apk = "patched-$name-v$version.apk";
    my $output_apk = "$name-revanced-extended-v$version.apk";
    my $sign_cmd = "$apksigner sign --verbose "
                 . "--ks ./etc/public.jks "
                 . "--ks-key-alias public "
                 . "--ks-pass pass:public "
                 . "--key-pass pass:public "
                 . "--in $input_apk "
                 . "--out $output_apk";
    execute_cmd($sign_cmd);

    # Remove the patched APK file
    unlink $input_apk or warn "Could not unlink $input_apk: $!";
}

# Run the main subroutine
main();
