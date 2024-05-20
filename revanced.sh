#!/bin/bash

# Download Github releases assets 
perl utils/github_downloader.pl

# Patch YouTube 
eval $(perl utils/uptodown.pl "youtube" \
                              "com.google.android.youtube")
perl utils/apply_patches.pl "youtube"
perl utils/github_release.pl "youtube"

# Patch YouTube Music 
eval $(perl utils/uptodown.pl "youtube-music" \
                              "com.google.android.apps.youtube.music")
perl utils/apply_patches.pl "youtube-music"
perl utils/github_release.pl "youtube-music"

# You can add other apps here 
