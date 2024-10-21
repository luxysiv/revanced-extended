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

# Function to fetch the latest release version of a GitHub repository
get_latest_release_version() {
    local repo="$1"
    local url="https://api.github.com/repos/${repo}/releases/latest"

    # Use req to get the latest release tag name, including the GitHub token in the header
    response=$(req - --header="Authorization: token $GITHUB_TOKEN" "$url" 2>/dev/null)

    # Check if the request was successful
    if [[ $? -eq 0 ]]; then
        # Extract the tag name from the response
        tag_name=$(echo "$response" | grep -oP '"tag_name":\s*"\K(v?[\d.]+)' | head -n 1)

        if [[ -n "$tag_name" ]]; then
            # Extract the version from the tag (e.g., v4.16.0-release to 4.16.0)
            echo "$tag_name" | grep -oP '\d+\.\d+\.\d+'
        else
            echo "Error: Tag name not found for $repo"
            return 1
        fi
    else
        echo "Error: Failed to fetch release version for $repo"
        return 1
    fi
}

# Function to compare versions of two repositories
compare_repository_versions() {    
    version_patches=$(get_latest_release_version "inotia00/revanced-patches")
    version_current=$(get_latest_release_version "$GITHUB_REPOSITORY")

    if [[ -n "$version_patches" && -n "$version_current" ]]; then
        if [[ "$version_patches" == "$version_current" ]]; then
            echo "Patched! Skipping build..."
            return 0  # Skip build if versions are the same
        else
            return 1  # Run build if versions differ
        fi
    else
        return 1  # Run build if either repository fails to respond
    fi
}


# Compare versions
if ! compare_repository_versions "$repo_patches" "$repository"; then
    echo "Running build..."
    download_resources
    patch_upload "youtube"
    patch_upload "youtube-music"
fi
