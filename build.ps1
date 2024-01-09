# Dropbox YouTube URL
$yt_url = "https://www.dropbox.com/scl/fi/wqnuqe65xd0bxn3ed2ous/com.google.android.youtube_18.45.43-1541152192_minAPI26-arm64-v8a-armeabi-v7a-x86-x86_64-nodpi-_apkmirror.com.apk?rlkey=fkujhctrb1dko978htdl0r9bi&dl=0"

# Take version from Dropbox link
$version = [regex]::Match($yt_url, '\d+(\.\d+)+').Value

# Declare repositories
$repositories = @{
    "revanced-cli" = "revanced/revanced-cli"
    "revanced-patches" = "revanced/revanced-patches"
    "revanced-integrations" = "revanced/revanced-integrations"
}

# Download latest releases for specified repositories
foreach ($repo in $repositories.Keys) {
    $response = Invoke-WebRequest -Uri "https://api.github.com/repos/$($repositories[$repo])/releases/latest"
    $asset_urls = $response.Content | ConvertFrom-Json | Where-Object { $_.name -like "*$repo*" } | Select-Object -Property browser_download_url, name

    foreach ($asset_url in $asset_urls) {
        Invoke-WebRequest -Uri $asset_url.browser_download_url -OutFile $asset_url.name
    }
}

# Download YouTube APK
Invoke-WebRequest -Uri ($yt_url -replace '0$', '1') -OutFile "youtube-v$version.apk"

# Read patches from file
$lines = Get-Content -Path "./patches.txt"

# Process patches
$include_patches = @()
$exclude_patches = @()
foreach ($line in $lines) {
    if ($line -match "^[+-]\s*(.*)") {
        $patch_name = $matches[1]
        if ($line.StartsWith("+")) {
            $include_patches += "--include", $patch_name
        }
        elseif ($line.StartsWith("-")) {
            $exclude_patches += "--exclude", $patch_name
        }
    }
}

# Apply patches using Revanced tools
java -jar revanced-cli*.jar patch `
    --merge revanced-integrations*.apk `
    --patch-bundle revanced-patches*.jar `
    @($exclude_patches) `
    @($include_patches) `
    --out "patched-youtube-v$version.apk" `
    "youtube-v$version.apk"

# Sign the patched APK
$apksigner = Get-ChildItem -Path "$env:ANDROID_SDK_ROOT/build-tools" -Filter apksigner.exe -Recurse | Sort-Object LastWriteTime -Descending | Select-Object -First 1
& $apksigner.FullName sign `
    --ks public.jks `
    --ks-key-alias public `
    --ks-pass pass:public `
    --key-pass pass:public `
    --in "patched-youtube-v$version.apk" `
    --out "youtube-revanced-v$version.apk"

# Obtain highest supported version information using revanced-cli
$package_info = java -jar revanced-cli*.jar list-versions -f com.google.android.youtube revanced-patches*.jar
$highest_supported_version = [regex]::Matches($package_info, '\d+(\.\d+)+') | Select-Object -ExpandProperty Value | Sort-Object -Descending | Select-Object -First 1

# Remove all lines containing version information
(Get-Content -Path "version.txt") -notmatch '[0-9.]+' | Set-Content -Path "version.txt"

# Write highest supported version to version.txt
if ($highest_supported_version -eq $version) {
    "Same $highest_supported_version version" >> "version.txt"
}
elseif ($highest_supported_version -ne $version) {
    "Supported version is $highest_supported_version , Pls update!" >> "version.txt"
}

# Upload version.txt to Github
$gitConfigEmail = "$env:GITHUB_ACTOR_ID+$env:GITHUB_ACTOR@users.noreply.github.com"
$gitConfigName = (Invoke-RestMethod -Uri "https://api.github.com/users/$($env:GITHUB_ACTOR)" | Select-Object -ExpandProperty name)
git config --global user.email "$gitConfigEmail" > $null
git config --global user.name "$gitConfigName" > $null
git add "version.txt" > $null
git commit -m "Update version" --author="." > $null
git push origin main > $null
