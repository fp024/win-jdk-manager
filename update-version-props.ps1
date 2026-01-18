param(
    [string]$FilePath = "version.properties"
)

# Updates JDK_URL_* entries in a version.properties file using Adoptium API.
$ApiRoot = "https://api.adoptium.net/v3/assets/latest"

if (-not (Test-Path -LiteralPath $FilePath)) {
    Write-Error "File not found: $FilePath"
    exit 1
}

$fileText = Get-Content -LiteralPath $FilePath -Raw
$match = [regex]::Match($fileText, 'SUPPORTED_VERSIONS="([^"]+)"')
if (-not $match.Success) {
    Write-Error "SUPPORTED_VERSIONS not found in $FilePath"
    exit 1
}
$versions = $match.Groups[1].Value.Split(' ', [System.StringSplitOptions]::RemoveEmptyEntries)

$urls = @{}
$versionNames = @{}
foreach ($ver in $versions) {
    $url = "$ApiRoot/$ver/hotspot?architecture=x64&os=windows&image_type=jdk"
    $resp = Invoke-RestMethod -UseBasicParsing -Uri $url -Method Get
    if (-not $resp) {
        Write-Error "API response empty for version $ver"
        exit 1
    }
    $link = $resp[0].binary.package.link
    if (-not $link) {
        Write-Error "Could not read download link for version $ver"
        exit 1
    }
    $versionNames[$ver] = $resp[0].release_name
    try {
        $head = Invoke-WebRequest -UseBasicParsing -Uri $link -Method Head -ErrorAction Stop
        if ($head.StatusCode -ne 200) {
            Write-Error "Download link not valid (status $($head.StatusCode)) for version $ver"
            exit 1
        }
    }
    catch {
        Write-Error ("Download link check failed for version {0}: {1}" -f $ver, $_.Exception.Message)
        exit 1
    }
    $urls[$ver] = $link
}

$lines = Get-Content -LiteralPath $FilePath
$updatedVersions = @()

for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^JDK_URL_(\d+)=(.*)$') {
        $ver = $Matches[1]
        $currentUrl = $Matches[2]
        if ($urls.ContainsKey($ver)) {
            $newUrl = $urls[$ver]
            if ($currentUrl -ne $newUrl) {
                $lines[$i] = "JDK_URL_${ver}=${newUrl}"
                $updatedVersions += $ver
            }
            $urls.Remove($ver) | Out-Null
        }
    }
}

foreach ($kvp in $urls.GetEnumerator()) {
    $lines += "JDK_URL_$($kvp.Key)=$($kvp.Value)"
    $updatedVersions += $kvp.Key
}

if ($updatedVersions.Count -eq 0) {
    Write-Host "Already up to date."
}
else {
    Set-Content -LiteralPath $FilePath -Value $lines
    Write-Host "Updated versions:"
    $updatedVersions | Sort-Object | ForEach-Object { 
        $name = $versionNames[$_]
        Write-Host "  - JDK $($_): $name" 
    }
    Write-Host "Updated $FilePath"
}