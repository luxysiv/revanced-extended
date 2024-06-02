#!/usr/bin/perl
use strict;
use warnings;
use FindBin;
use Env;

use lib "$FindBin::Bin/utils";
use apkpure qw(apkpure);
use uptodown qw(uptodown);
use apkmirror qw(apkmirror);
use apply_patches qw(apply_patches);
use github_release qw(github_release);
use github_downloader qw(download_resources);

# Main
# Could set specific version to patch. Example:
# $ENV{VERSION} = "6.51.52";

# Download Github releases assets
download_resources();

# Patch YouTube
my $success = eval {
    apkmirror(
        "google-inc",
        "youtube",
        "com.google.android.youtube"
    );
    apply_patches("youtube");
    github_release("youtube");
    1;
};

unless ($success) {
    $success = eval {
        uptodown(
            "youtube",
            "com.google.android.youtube"
        );
        apply_patches("youtube");
        github_release("youtube");
        1;
    };

    unless ($success) {
        eval {
            apkpure(
                "youtube",
                "com.google.android.youtube"
            );
            apply_patches("youtube");
            github_release("youtube");
            1;
        };
    }
}

# Patch YouTube Music
$success = eval {
    apkmirror(
        "google-inc",
        "youtube-music",
        "com.google.android.apps.youtube.music",
        "arm64-v8a"
    );
    apply_patches("youtube-music");
    github_release("youtube-music");
    1;
};

unless ($success) {
    $success = eval {
        uptodown(
            "youtube-music",
            "com.google.android.apps.youtube.music"
        );
        apply_patches("youtube-music");
        github_release("youtube-music");
        1;
    };

    unless ($success) {
        eval {
            apkpure(
                "youtube-music",
                "com.google.android.apps.youtube.music"
            );
            apply_patches("youtube-music");
            github_release("youtube-music");
            1;
        };
    }
}

# You can add other apps here
