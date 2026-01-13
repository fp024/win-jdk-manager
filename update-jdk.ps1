param(
    [Parameter(Mandatory=$true)]
    [string]$Version,
    [string]$PropsFile = "version.properties",
    [switch]$Force
)

# update-jdk.ps1: JDK Auto Update Script
# Usage: 
#   .\update-jdk.ps1 all           - Update all supported versions
#   .\update-jdk.ps1 17            - Update only JDK 17
#   .\update-jdk.ps1 17 -Force     - Force re-download

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Set default jdks path
$script:jdksPath = ".\jdks"

function Initialize-JdksFolder {
    # Create jdks folder
    if (-not (Test-Path -LiteralPath $script:jdksPath)) {
        New-Item -ItemType Directory -Path $script:jdksPath | Out-Null
        Write-Host "📁 Created jdks directory: $script:jdksPath"
    }
    
    # Create jdks/archive folder
    $archiveBase = Join-Path $script:jdksPath "archive"
    if (-not (Test-Path -LiteralPath $archiveBase)) {
        New-Item -ItemType Directory -Path $archiveBase | Out-Null
        Write-Host "📁 Created archive directory: $archiveBase"
    }
}

function Get-SupportedVersions {
    param([string]$FilePath)
    
    if (-not (Test-Path -LiteralPath $FilePath)) {
        throw "Property file not found: $FilePath"
    }
    
    $fileText = Get-Content -LiteralPath $FilePath -Raw
    $match = [regex]::Match($fileText, 'SUPPORTED_VERSIONS="([^"]+)"')
    if (-not $match.Success) {
        throw "SUPPORTED_VERSIONS not found"
    }
    
    return $match.Groups[1].Value.Split(' ', [System.StringSplitOptions]::RemoveEmptyEntries)
}

function Get-JdkUrl {
    param([string]$FilePath, [string]$Ver)
    
    $fileText = Get-Content -LiteralPath $FilePath -Raw
    $match = [regex]::Match($fileText, "JDK_URL_${Ver}=(.+)")
    if (-not $match.Success) {
        throw "JDK_URL_${Ver} not found"
    }
    
    return $match.Groups[1].Value.Trim()
}

function Update-Jdk {
    param([string]$Ver, [string]$Url, [bool]$ForceDownload)
    
    $archivePath = Join-Path $script:jdksPath "archive\$Ver"
    
    # Create archive directory
    if (-not (Test-Path -LiteralPath $archivePath)) {
        New-Item -ItemType Directory -Path $archivePath | Out-Null
        Write-Host "📁 Created directory: $archivePath"
    }
    
    # Extract filename
    $fileName = Split-Path -Leaf $Url
    $zipPath = Join-Path $archivePath $fileName
    $latestPath = Join-Path $archivePath "latest"
    
    Write-Host ""
    Write-Host "🔄 Starting JDK $Ver update..."
    
    # Check if same file already exists
    $needDownload = $true
    if (Test-Path -LiteralPath $zipPath) {
        if ($ForceDownload) {
            Write-Host "🔄 Using force download option - deleting existing file..."
            Remove-Item -LiteralPath $zipPath -Force | Out-Null
        }
        else {
            Write-Host "✅ Same file already exists: $fileName"
            Write-Host "   (Use -Force option to re-download)"
            $needDownload = $false
        }
    }
    
    # Delete previous latest directory
    if (Test-Path -LiteralPath $latestPath) {
        Write-Host "🗑️  Deleting previous latest directory..."
        Remove-Item -LiteralPath $latestPath -Recurse -Force | Out-Null
    }
    
    if ($needDownload) {
        # Delete previous zip files (files from different versions)
        $existingZips = Get-ChildItem -LiteralPath $archivePath -Filter "*.zip" -ErrorAction SilentlyContinue
        foreach ($zip in $existingZips) {
            Write-Host "🗑️  Deleting previous file: $($zip.Name)"
            Remove-Item -LiteralPath $zip.FullName -Force | Out-Null
        }
        
        # Download file
        Write-Host "📥 Download URL: $Url"
        Write-Host "📥 Downloading..."
        try {
            Invoke-WebRequest -Uri $Url -OutFile $zipPath -UseBasicParsing -ErrorAction Stop | Out-Null
            Write-Host "✅ Download complete: $fileName"
        }
        catch {
            throw "Download failed: $_"
        }
    }
    
    # Extract archive (extract to temp folder and move inner folder to latest)
    Write-Host "📦 Extracting..."
    $tempExtract = Join-Path $archivePath "temp_extract"
    try {
        if (Test-Path -LiteralPath $tempExtract) {
            Remove-Item -LiteralPath $tempExtract -Recurse -Force | Out-Null
        }
        Expand-Archive -LiteralPath $zipPath -DestinationPath $tempExtract -Force -ErrorAction Stop
        
        # Move single folder from archive to latest
        $innerFolders = Get-ChildItem -Path $tempExtract -Directory
        if ($innerFolders.Count -eq 1) {
            Move-Item -LiteralPath $innerFolders[0].FullName -Destination $latestPath
            Remove-Item -LiteralPath $tempExtract -Force | Out-Null
        } else {
            # If not single folder, rename temp_extract itself to latest
            Rename-Item -LiteralPath $tempExtract -NewName "latest"
        }
        Write-Host "✅ Extraction complete"
    }
    catch {
        # Clean up on extraction failure
        if (Test-Path -LiteralPath $tempExtract) {
            Remove-Item -LiteralPath $tempExtract -Recurse -Force | Out-Null
        }
        Remove-Item -LiteralPath $zipPath -Force | Out-Null
        throw "Extraction failed: $_"
    }
    
    # Create/update junction link (jdks/{version} -> jdks/archive/{version}/latest)
    $junctionPath = Join-Path $script:jdksPath $Ver
    if (Test-Path -LiteralPath $junctionPath) {
        Write-Host "🔗 Deleting existing junction..."
        cmd /c rmdir "$junctionPath" 2>$null
    }
    Write-Host "🔗 Creating junction link: $junctionPath -> $latestPath"
    cmd /c mklink /J "$junctionPath" "$latestPath" | Out-Null
    
    Write-Host "✨ JDK $Ver update complete!"
}

# Main logic
try {
    # Initialize jdks folder structure
    Initialize-JdksFolder
    
    $supportedVersions = Get-SupportedVersions -FilePath $PropsFile
    
    if ($Version -eq "all") {
        Write-Host "🚀 Starting update for all supported versions..."
        Write-Host "Supported versions: $($supportedVersions -join ', ')"
        
        foreach ($ver in $supportedVersions) {
            $url = Get-JdkUrl -FilePath $PropsFile -Ver $ver
            Update-Jdk -Ver $ver -Url $url -ForceDownload $Force.IsPresent
        }
        
        Write-Host ""
        Write-Host "🎉 All versions updated successfully!"
    }
    else {
        if ($supportedVersions -notcontains $Version) {
            throw "Unsupported version. Supported versions: $($supportedVersions -join ', ')"
        }
        
        Write-Host "🚀 Starting JDK $Version update..."
        $url = Get-JdkUrl -FilePath $PropsFile -Ver $Version
        Update-Jdk -Ver $Version -Url $url -ForceDownload $Force.IsPresent
    }
}
catch {
    Write-Error "Error occurred: $_"
    exit 1
}
