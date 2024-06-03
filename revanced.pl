#!/usr/bin/perl
use strict;
use warnings;
use FindBin;
use Env;
use JSON;
use File::Spec;
use IO::File;

use lib "$FindBin::Bin/utils";
use apkpure qw(apkpure);
use uptodown qw(uptodown);
use apkmirror qw(apkmirror);
use apply_patches qw(apply_patches);
use github_release qw(github_release);
use github_downloader qw(download_resources);

sub download_and_patch_app {
    my ($app_info) = @_;

    my $success = eval {
        apkmirror(
            $app_info->{apkmirror}->{org},
            $app_info->{apkmirror}->{name},
            $app_info->{package},
            $app_info->{apkmirror}->{arch},
            $app_info->{apkmirror}->{dpi}
        );
        apply_patches($app_info->{apkmirror}->{name});
        github_release($app_info->{apkmirror}->{name});
        1;
    };

    unless ($success) {
        $success = eval {
            uptodown(
                $app_info->{uptodown}->{name},
                $app_info->{package}
            );
            apply_patches($app_info->{uptodown}->{name});
            github_release($app_info->{uptodown}->{name});
            1;
        };
    }

    unless ($success) {
        $success = eval {
            apkpure(
                $app_info->{apkpure}->{name},
                $app_info->{package}
            );
            apply_patches($app_info->{apkpure}->{name});
            github_release($app_info->{apkpure}->{name});
            1;
        };
    }

    return $success;
}

sub read_json_file {
    my ($file_path) = @_;
    my $file = IO::File->new($file_path, "r") or die "Could not open file '$file_path': $!";
    my $json_text = do { local $/; <$file> };
    $file->close;
    my $json = decode_json($json_text);
    return $json;
}

sub main {
    my $app_name = shift @ARGV or die "App name not provided";

    download_resources();

    my $json_file = File::Spec->catfile($FindBin::Bin, 'apps', "$app_name.json");

    my $app_info = read_json_file($json_file);
    my $success = download_and_patch_app($app_info);
    unless ($success) {
    }
}

main();
