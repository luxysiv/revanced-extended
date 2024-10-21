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
    pkg_name="$1"
    jq -r '.. | objects | select(.name == "'$pkg_name'" and .versions != null) | .versions[]' patches.json | max
}

# Download necessary resources to patch from Github latest release 
download_resources() {
    for repo in revanced-patches revanced-cli revanced-integrations; do
        githubApiUrl="https://api.github.com/repos/inotia00/$repo/releases/latest"
        page=$(req - 2>/dev/null $githubApiUrl)
        assetUrls=$(echo $page | jq -r '.assets[] | select(.name | endswith(".asc") | not) | "\(.browser_download_url) \(.name)"')
        while read -r downloadUrl assetName; do
            req "$assetName" "$downloadUrl" 
        done <<< "$assetUrls"
    done
}

# Get some versions of application on APKmirror pages 
get_apkmirror_version() {
    grep 'fontBlack' | sed -n 's/.*>\(.*\)<\/a> <\/h5>.*/\1/p' | sed 20q
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
    version="${version:-$(req - $url | pup 'div.widget_appmanager_recentpostswidget h5 a.fontBlack text{}' | get_latest_version)}"
    url="https://www.apkmirror.com/apk/$org/$name/$name-${version//./-}-release"
    url="https://www.apkmirror.com$(req - $url | pup -p --charset utf-8 ':parent-of(:parent-of(span:contains("'$type'")))' \
                                               | pup -p --charset utf-8 ':parent-of(div:contains("'$arch'"))' \
                                               | pup -p --charset utf-8 ':parent-of(div:contains("'$dpi'")) a.accent_color attr{href}' \
                                               | sed 1q )"
    url="https://www.apkmirror.com$(req - $url | pup -p --charset utf-8 'a.downloadButton attr{href}')"
    url="https://www.apkmirror.com$(req - $url | pup -p --charset utf-8 'a#download-link attr{href}')"
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
    version="${version:-$(req - 2>/dev/null "$url" | pup 'div#versions-items-list > div span.version text{}' | get_latest_version)}"
    url=$(req - $url | pup -p --charset utf-8 ':parent-of(span:contains("'$version'"))' \
                     | pup -p --charset utf-8 'div[data-url]' attr{data-url} \
                     | sed 1q)
    url="https://dw.uptodown.com/dwn/$(req - "$url" | pup -p --charset utf-8 'button#detail-download-button attr{data-url}')"
    req $name-v$version.apk $url
}

# Tiktok not work because not available version supported 
apkpure() {
    config_file="./apps/apkpure/$1.json"
    name=$(jq -r '.name' "$config_file")
    package=$(jq -r '.package' "$config_file")
    version=$(jq -r '.version' "$config_file")
    url="https://apkpure.net/$name/$package/versions"
    version=$(req - 2>/dev/null $api | get_supported_version "$package")
    version="${version:-$(req - $url | pup 'div.ver-item > div.ver-item-n text{}' | get_latest_version)}"
    url="https://apkpure.net/$name/$package/download/$version"
    url=$(req - $url | pup -p --charset utf-8 'a#download_link attr{href}')
    req $name-v$version.apk "$url"
}

# Apply patches with Include and Exclude Patches
apply_patches() {   
    name="$1"
    # Read patches from file
    mapfile -t lines < ./etc/$name-patches.txt

    # Process patches
    for line in "${lines[@]}"; do
        if [[ -n "$line" && ( ${line:0:1} == "+" || ${line:0:1} == "-" ) ]]; then
            patch_name=$(sed -e 's/^[+|-] *//;s/ *$//' <<< "$line") 
            [[ ${line:0:1} == "+" ]] && includePatches+=("--include" "$patch_name")
            [[ ${line:0:1} == "-" ]] && excludePatches+=("--exclude" "$patch_name")
        fi
    done
    
    # Remove x86 and x86_64 libs
    zip --delete "$name-v$version.apk" "lib/x86/*" "lib/x86_64/*" >/dev/null
    
    # Apply patches using Revanced tools
    java -jar revanced-cli*.jar patch \
        --merge revanced-integrations*.apk \
        --patch-bundle revanced-patches*.jar \
        "${excludePatches[@]}" "${includePatches[@]}" \
        --out "$name-revanced-extended-v$version.apk" \
        "$name-v$version.apk"
    rm $name-v$version.apk
    unset excludePatches includePatches version
}

# Make body Release 
create_body_release() {
    body=$(cat <<EOF
# Release Notes

## Build Tools:
- **ReVanced Patches:** v$patchver
- **ReVanced Integrations:** v$integrationsver
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
    patchver=$(ls -1 revanced-patches*.jar | grep -oP '\d+(\.\d+)+')
    integrationsver=$(ls -1 revanced-integrations*.apk | grep -oP '\d+(\.\d+)+')
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
