$ytUrl = "https://www.dropbox.com/scl/fi/wqnuqe65xd0bxn3ed2ous/com.google.android.youtube_18.45.43-1541152192_minAPI26-arm64-v8a-armeabi-v7a-x86-x86_64-nodpi-_apkmirror.com.apk?rlkey=fkujhctrb1dko978htdl0r9bi&dl=0"

$version = [regex]::Match($ytUrl, '\d+(\.\d+)+').Value

$repositories = @{
    "revanced-cli" = "revanced/revanced-cli"
    "revanced-patches" = "revanced/revanced-patches"
    "revanced-integrations" = "revanced/revanced-integrations"
}

foreach ($repo in $repositories.Keys) {
    $response = Invoke-RestMethod -Uri "https://api.github.com/repos/$($repositories[$repo])/releases/latest" -Debug

    $assetUrls = $response.assets | Where-Object { $_.name -match $repo } | ForEach-Object { "$($_.browser_download_url) $($_.name)" }

    foreach ($url in $assetUrls) {
        $urlParts = $url -split ' '
        Invoke-WebRequest -Uri $urlParts[0] -OutFile $urlParts[1] -UseBasicParsing -Debug
    }
}

Invoke-WebRequest -Uri "$($ytUrl -replace '0$', '1')" -OutFile "youtube-v$version.apk" -UseBasicParsing -Debug

$lines = Get-Content -Path .\patches.txt

$includePatches = @()
$excludePatches = @()

foreach ($line in $lines) {
    if ($line -match '^([+|-])\s*(.+)') {
        $patchName = $Matches[2]

        if ($Matches[1] -eq '+') {
            $includePatches += "--include", $patchName
        } elseif ($Matches[1] -eq '-') {
            $excludePatches += "--exclude", $patchName
        }
    }
}

java -jar revanced-cli*.jar patch `
    --merge revanced-integrations*.apk `
    --patch-bundle revanced-patches*.jar `
    $($excludePatches + $includePatches) `
    --out "patched-youtube-v$version.apk" `
    "youtube-v$version.apk"

$apksigner = Get-ChildItem -Path "$env:ANDROID_SDK_ROOT/build-tools" -Filter apksigner -Recurse | Sort-Object LastWriteTime -Descending | Select-Object -First 1
& $apksigner.FullName sign --ks public.jks `
    --ks-key-alias public `
    --ks-pass pass:public `
    --key-pass pass:public `
    --in "patched-youtube-v$version.apk" `
    --out "youtube-revanced-v$version.apk"

$packageInfo = java -jar revanced-cli*.jar list-versions -f com.google.android.youtube revanced-patches*.jar
$highestSupportedVersion = [regex]::Matches($packageInfo, '\d+(\.\d+)+') | ForEach-Object { $_.Value } | Sort-Object -Descending | Select-Object -First 1

(Get-Content -Path .\version.txt) -notmatch '[0-9.]' | Set-Content -Path .\version.txt

if ($highestSupportedVersion -eq $version) {
    Add-Content -Path .\version.txt -Value "Same $highestSupportedVersion version"
} elseif ($highestSupportedVersion -ne $version) {
    Add-Content -Path .\version.txt -Value "Supported version is $highestSupportedVersion, Pls update!"
}

git config --global user.email "$env:GITHUB_ACTOR_ID+$env:GITHUB_ACTOR@users.noreply.github.com" -Debug
git config --global user.name "$((gh api "/users/$env:GITHUB_ACTOR" | ConvertFrom-Json).name)" -Debug
git add version.txt -Debug
git commit -m "Update version" --author=. -Debug
git push origin main -Debug
