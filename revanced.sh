#!/bin/bash
source ./etc/utils.sh

download_app() {
    app_name=$1
    sources=("apkmirror" "uptodown" "apkpure")

    for source in "${sources[@]}"; do
        if $source "$app_name"; then
            return 0
        fi
    done
    
    return 1
}

# Main script 
patch_upload() {
    app_name=$1
    download_app "$app_name"
    apply_patches "$app_name"
    create_github_release "$app_name"
}

# Perform download_repository_assets
download_resources

ls revanced-patches*.jar > current_file.txt

if cmp -s current_file.txt patches.txt; then
    echo "No change, skipping patch..."
    delete_cache
else
    rm patches.txt > /dev/null 2>&1
    # Patch YouTube
    patch_upload "youtube"

    # Patch YouTube Music 
    patch_upload "youtube-music"
    mv current_file.txt patches.txt
    delete_cache
fi
