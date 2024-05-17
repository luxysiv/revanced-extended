#!/bin/bash
source ./utils/utils.sh

# Main script 

# Perform download_repository_assets
perl utils/github_downloader.pl

# Patch YouTube 
uptodown "youtube" \
         "com.google.android.youtube"
apply_patches "youtube"
github_release "youtube"

# Patch YouTube Music 
uptodown "youtube-music" \
         "com.google.android.apps.youtube.music" 
apply_patches "youtube-music"
github_release "youtube-music"

# You can add other apps here 
