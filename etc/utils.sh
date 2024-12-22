#!/bin/bash
# Script make by Mạnh Dương

# Make requests like send from Firefox Android 
req() {
    wget --header="User-Agent: Mozilla/5.0 (Android 13; Mobile; rv:125.0) Gecko/125.0 Firefox/125.0" \
         --header="Content-Type: application/octet-stream" \
         --header="Accept-Language: en-US,en;q=0.9" \
         --header="Connection: keep-alive" \
         --header="Upgrade-Insecure-Requests: 1" \
         --header="Cache-Control: max-age=0" \
         --header="Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8" \
         --keep-session-cookies --timeout=30 -nv -O "$@"
}

# Find max version
max() {
	local max=0
	while read -r v || [ -n "$v" ]; do
		if [[ ${v//[!0-9]/} -gt ${max//[!0-9]/} ]]; then max=$v; fi
	done
	if [[ $max = 0 ]]; then echo ""; else echo "$max"; fi
}

# Get largest version (Just compatible with my way of getting versions code)
get_latest_version() {
    grep -Evi 'alpha|beta' | grep -oPi '\b\d+(\.\d+)+(?:\-\w+)?(?:\.\d+)?(?:\.\w+)?\b' | max
}

# Read highest supported versions from Revanced 
get_supported_version() {
    package_name=$1
    output=$(java -jar revanced-cli*.jar list-versions -f "$package_name" patch*.rvp)
    version=$(echo "$output" | tail -n +3 | sed 's/ (.*)//' | grep -v -w "Any" | max | xargs)
    echo "$version"
}

# Download necessary resources to patch from Github latest release 
download_resources() {
    for repo in revanced-patches revanced-cli; do
        githubApiUrl="https://api.github.com/repos/inotia00/$repo/releases/latest"
        page=$(req - 2>/dev/null $githubApiUrl)
        assetUrls=$(echo $page | jq -r '.assets[] | select(.name | endswith(".asc") | not) | "\(.browser_download_url) \(.name)"')
        while read -r downloadUrl assetName; do
            req "$assetName" "$downloadUrl" 
        done <<< "$assetUrls"
    done
}

# Filtered key words to extract link
extract_filtered_links() {
    local dpi="$1" arch="$2" type="$3"
    awk -v dpi="$dpi" -v arch="$arch" -v type="$type" '
    BEGIN { block = ""; link = ""; found_dpi = found_arch = found_type = printed = 0 }
    /<a class="accent_color"/ {
        if (printed) next
        if (block != "" && link != "" && found_dpi && found_arch && found_type && !printed) { 
            print link; printed = 1 
        }
        block = $0; found_dpi = found_arch = found_type = 0
        if (match($0, /href="([^"]+)"/, arr)) link = arr[1]
    }
    { if (!printed) block = block "\n" $0 }
    /table-cell/ && $0 ~ dpi { found_dpi = 1 }
    /table-cell/ && $0 ~ arch { found_arch = 1 }
    /apkm-badge/ && $0 ~ (">" type "</span>") { found_type = 1 }
    END {
        if (block != "" && link != "" && found_dpi && found_arch && found_type && !printed)
            print link
    }
    '
}

# Get some versions of application on APKmirror pages 
get_apkmirror_version() {
    grep -oP 'class="fontBlack"[^>]*href="[^"]+"\s*>\K[^<]+' | sed 20q | awk '{print $NF}'
}

# Best but sometimes not work because APKmirror protection 
apkmirror() {
    config_file="./apps/apkmirror/$1.json"
    org=$(jq -r '.org' "$config_file")
    name=$(jq -r '.name' "$config_file")
    type=$(jq -r '.type' "$config_file")
    arch=$(jq -r '.arch' "$config_file")
    dpi=$(jq -r '.dpi' "$config_file")
    package=$(jq -r '.package' "$config_file")
    version=$(jq -r '.version' "$config_file")

    version="${version:-$(get_supported_version "$package")}"
    url="https://www.apkmirror.com/uploads/?appcategory=$name"
    version="${version:-$(req - $url | get_apkmirror_version | get_latest_version)}"
    url="https://www.apkmirror.com/apk/$org/$name/$name-${version//./-}-release"
    url="https://www.apkmirror.com$(req - "$url" | extract_filtered_links "$dpi" "$arch" "$type")"
    url="https://www.apkmirror.com$(req - "$url" | grep -oP 'class="[^"]*downloadButton[^"]*"[^>]*href="\K[^"]+')"
    url="https://www.apkmirror.com$(req - "$url" | grep -oP 'id="download-link"[^>]*href="\K[^"]+')"
    req $name-v$version.apk $url
}

# X not work (maybe more)
uptodown() {
    config_file="./apps/uptodown/$1.json"
    name=$(jq -r '.name' "$config_file")
    package=$(jq -r '.package' "$config_file")
    version=$(jq -r '.version' "$config_file")
    version="${version:-$(get_supported_version "$package")}"
    url="https://$name.en.uptodown.com/android/versions"
    version="${version:-$(req - 2>/dev/null $url | grep -oP 'class="version">\K[^<]+' | get_latest_version)}"

    # Fetch data_code
    data_code=$(req - "$url" | grep 'detail-app-name' | grep -oP '(?<=data-code=")[^"]+')

    page=1
    while :; do
        json=$(req - "https://$name.en.uptodown.com/android/apps/$data_code/versions/$page" | jq -r '.data')
        
        # Exit if no valid JSON or no more pages
        [ -z "$json" ] && break
        
        # Search for version URL
        version_url=$(echo "$json" | jq -r --arg version "$version" '[.[] | select(.version == $version and .kindFile == "apk")][0].versionURL // empty')
        if [ -n "$version_url" ]; then
            download_url=$(req - "${version_url}-x" | grep -oP '(?<=data-url=")[^"]+')
            [ -n "$download_url" ] && req "$name-v$version.apk" "https://dw.uptodown.com/dwn/$download_url" && break
        fi
        
        # Check if all versions are less than target version
        all_lower=$(echo "$json" | jq -r --arg version "$version" '.[] | select(.kindFile == "apk") | .version | select(. < $version)' | wc -l)
        total_versions=$(echo "$json" | jq -r '.[] | select(.kindFile == "apk") | .version' | wc -l)
        [ "$all_lower" -eq "$total_versions" ] && break

        page=$((page + 1))
    done
}

# Tiktok not work because not available version supported 
apkpure() {
    config_file="./apps/apkpure/$1.json"
    name=$(jq -r '.name' "$config_file")
    package=$(jq -r '.package' "$config_file")
    version=$(jq -r '.version' "$config_file")
    url="https://apkpure.net/$name/$package/versions"
    version="${version:-$(get_supported_version "$package")}"
    version="${version:-$(req - $url | grep -oP 'data-dt-version="\K[^"]*' | sed 10q | get_latest_version)}"
    url="https://apkpure.net/$name/$package/download/$version"
    url=$(req - $url | grep -oP '<a[^>]*id="download_link"[^>]*href="\K[^"]*' | head -n 1)
    req $name-v$version.apk "$url"
}

# Apply patches with Include and Exclude Patches
apply_patches() {   
    name="$1"
    
    # Read patches from file if the file exists
    if [[ -f "./etc/$name-patches.txt" ]]; then
        mapfile -t lines < ./etc/$name-patches.txt

        # Process patches
        for line in "${lines[@]}"; do
            if [[ -n "$line" && ( ${line:0:1} == "+" || ${line:0:1} == "-" ) ]]; then
                patch_name=$(sed -e 's/^[+|-] *//;s/ *$//' <<< "$line") 
                [[ ${line:0:1} == "+" ]] && includePatches+=("-e" "$patch_name")
                [[ ${line:0:1} == "-" ]] && excludePatches+=("-d" "$patch_name")
            fi
        done
    fi

    # Remove x86 and x86_64 libs
    zip --delete "$name-v$version.apk" "lib/x86/*" "lib/x86_64/*" >/dev/null
    
    # Apply patches using Revanced tools
    java -jar revanced-cli*.jar patch \
        --patches patches*.rvp \
        "${excludePatches[@]}" "${includePatches[@]}" \
        --out "$name-revanced-extended-v$version.apk" \
        "$name-v$version.apk"
    rm "$name-v$version.apk"
    unset excludePatches includePatches version
}

# Make body Release 
create_body_release() {
    body=$(cat <<EOF
# Release Notes

## Build Tools:
- **ReVanced Patches:** v$patchver
- **ReVanced CLI:** v$cliver

## Note:
**ReVancedGms** is **necessary** to work. 
- Please **download** it from [HERE](https://github.com/revanced/gmscore/releases/latest).
EOF
)

    releaseData=$(jq -n \
      --arg tag_name "$tagName" \
      --arg target_commitish "main" \
      --arg name "Revanced Extended $tagName" \
      --arg body "$body" \
      '{ tag_name: $tag_name, target_commitish: $target_commitish, name: $name, body: $body }')
}

# Release Revanced APK
create_github_release() {
    name="$1"
    authorization="Authorization: token $GITHUB_TOKEN" 
    apiReleases="https://api.github.com/repos/$GITHUB_REPOSITORY/releases"
    uploadRelease="https://uploads.github.com/repos/$GITHUB_REPOSITORY/releases"
    apkFilePath=$(find . -type f -name "$name-revanced*.apk")
    apkFileName=$(basename "$apkFilePath")
    patchver=$(ls -1 patches*.rvp | grep -oP '\d+(\.\d+)+')
    cliver=$(ls -1 revanced-cli*.jar | grep -oP '\d+(\.\d+)+')
    tagName="v$patchver"

    # Make sure release with APK
    if [ ! -f "$apkFilePath" ]; then
        exit
    fi

    existingRelease=$(req - --header="$authorization" "$apiReleases/tags/$tagName" 2>/dev/null)

    # Add more assets release with same tag name
    if [ -n "$existingRelease" ]; then
        existingReleaseId=$(echo "$existingRelease" | jq -r ".id")
        uploadUrlApk="$uploadRelease/$existingReleaseId/assets?name=$apkFileName"

        # Delete assest release if same name upload 
        for existingAsset in $(echo "$existingRelease" | jq -r '.assets[].name'); do
            [ "$existingAsset" == "$apkFileName" ] && \
                assetId=$(echo "$existingRelease" | jq -r '.assets[] | select(.name == "'"$apkFileName"'") | .id') && \
                req - --header="$authorization" --method=DELETE "$apiReleases/assets/$assetId" 2>/dev/null
        done
    else
        # Make tag name
        create_body_release 
        newRelease=$(req - --header="$authorization" --post-data="$releaseData" "$apiReleases")
        releaseId=$(echo "$newRelease" | jq -r ".id")
        uploadUrlApk="$uploadRelease/$releaseId/assets?name=$apkFileName"
    fi

    # Upload file to Release 
    req - &>/dev/null --header="$authorization" --post-file="$apkFilePath" "$uploadUrlApk"
}
