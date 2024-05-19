#!/bin/bash
source ./utils/utils.sh

# Main script 

# Perform download_repository_assets
perl utils/github_downloader.pl

# Patch YouTube 
eval $(perl utils/uptodown.pl "youtube" \
                              "com.google.android.youtube")
perl utils/apply_patches.pl "youtube"
github_release "youtube"

# Patch YouTube Music 
eval $(perl utils/uptodown.pl "youtube-music" \
                              "com.google.android.apps.youtube.music")
perl utils/apply_patches.pl "youtube-music"
github_release "youtube-music"

# You can add other apps here 
