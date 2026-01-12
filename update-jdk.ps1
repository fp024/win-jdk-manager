param(
    [Parameter(Mandatory=$true)]
    [string]$Version,
    [string]$PropsFile = "version.properties",
    [switch]$Force
)

# update-jdk.ps1: JDK 자동 업데이트 스크립트
# 사용법: 
#   .\update-jdk.ps1 all           - 모든 지원 버전 업데이트
#   .\update-jdk.ps1 17            - JDK 17만 업데이트
#   .\update-jdk.ps1 17 -Force     - 강제 재다운로드

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# jdks 기본 경로 설정
$script:jdksPath = ".\jdks"

function Initialize-JdksFolder {
    # jdks 폴더 생성
    if (-not (Test-Path -LiteralPath $script:jdksPath)) {
        New-Item -ItemType Directory -Path $script:jdksPath | Out-Null
        Write-Host "📁 jdks 디렉토리 생성: $script:jdksPath"
    }
    
    # jdks/archive 폴더 생성
    $archiveBase = Join-Path $script:jdksPath "archive"
    if (-not (Test-Path -LiteralPath $archiveBase)) {
        New-Item -ItemType Directory -Path $archiveBase | Out-Null
        Write-Host "📁 archive 디렉토리 생성: $archiveBase"
    }
}

function Get-SupportedVersions {
    param([string]$FilePath)
    
    if (-not (Test-Path -LiteralPath $FilePath)) {
        throw "프로퍼티 파일을 찾을 수 없습니다: $FilePath"
    }
    
    $fileText = Get-Content -LiteralPath $FilePath -Raw
    $match = [regex]::Match($fileText, 'SUPPORTED_VERSIONS="([^"]+)"')
    if (-not $match.Success) {
        throw "SUPPORTED_VERSIONS를 찾을 수 없습니다"
    }
    
    return $match.Groups[1].Value.Split(' ', [System.StringSplitOptions]::RemoveEmptyEntries)
}

function Get-JdkUrl {
    param([string]$FilePath, [string]$Ver)
    
    $fileText = Get-Content -LiteralPath $FilePath -Raw
    $match = [regex]::Match($fileText, "JDK_URL_${Ver}=(.+)")
    if (-not $match.Success) {
        throw "JDK_URL_${Ver}을(를) 찾을 수 없습니다"
    }
    
    return $match.Groups[1].Value.Trim()
}

function Update-Jdk {
    param([string]$Ver, [string]$Url, [bool]$ForceDownload)
    
    $archivePath = Join-Path $script:jdksPath "archive\$Ver"
    
    # 아카이브 디렉토리 생성
    if (-not (Test-Path -LiteralPath $archivePath)) {
        New-Item -ItemType Directory -Path $archivePath | Out-Null
        Write-Host "📁 디렉토리 생성: $archivePath"
    }
    
    # 파일명 추출
    $fileName = Split-Path -Leaf $Url
    $zipPath = Join-Path $archivePath $fileName
    $latestPath = Join-Path $archivePath "latest"
    
    Write-Host ""
    Write-Host "🔄 JDK $Ver 업데이트 시작..."
    
    # 동일한 파일이 이미 있는지 확인
    $needDownload = $true
    if (Test-Path -LiteralPath $zipPath) {
        if ($ForceDownload) {
            Write-Host "🔄 강제 다운로드 옵션 사용 - 기존 파일 삭제..."
            Remove-Item -LiteralPath $zipPath -Force | Out-Null
        }
        else {
            Write-Host "✅ 동일한 파일이 이미 존재함: $fileName"
            Write-Host "   (재다운로드하려면 -Force 옵션 사용)"
            $needDownload = $false
        }
    }
    
    # 이전 latest 디렉토리 정리
    if (Test-Path -LiteralPath $latestPath) {
        Write-Host "🗑️  이전 latest 디렉토리 삭제..."
        Remove-Item -LiteralPath $latestPath -Recurse -Force | Out-Null
    }
    
    if ($needDownload) {
        # 이전 zip 파일 삭제 (다른 버전의 파일들)
        $existingZips = Get-ChildItem -LiteralPath $archivePath -Filter "*.zip" -ErrorAction SilentlyContinue
        foreach ($zip in $existingZips) {
            Write-Host "🗑️  이전 파일 삭제: $($zip.Name)"
            Remove-Item -LiteralPath $zip.FullName -Force | Out-Null
        }
        
        # 파일 다운로드
        Write-Host "📥 다운로드 URL: $Url"
        Write-Host "📥 다운로드 중..."
        try {
            Invoke-WebRequest -Uri $Url -OutFile $zipPath -UseBasicParsing -ErrorAction Stop | Out-Null
            Write-Host "✅ 다운로드 완료: $fileName"
        }
        catch {
            throw "다운로드 실패: $_"
        }
    }
    
    # 압축 해제 (임시 폴더에 풀고 내부 폴더를 latest로 이동)
    Write-Host "📦 압축 해제 중..."
    $tempExtract = Join-Path $archivePath "temp_extract"
    try {
        if (Test-Path -LiteralPath $tempExtract) {
            Remove-Item -LiteralPath $tempExtract -Recurse -Force | Out-Null
        }
        Expand-Archive -LiteralPath $zipPath -DestinationPath $tempExtract -Force -ErrorAction Stop
        
        # 압축 내부의 단일 폴더를 latest로 이동
        $innerFolders = Get-ChildItem -Path $tempExtract -Directory
        if ($innerFolders.Count -eq 1) {
            Move-Item -LiteralPath $innerFolders[0].FullName -Destination $latestPath
            Remove-Item -LiteralPath $tempExtract -Force | Out-Null
        } else {
            # 단일 폴더가 아니면 temp_extract 자체를 latest로
            Rename-Item -LiteralPath $tempExtract -NewName "latest"
        }
        Write-Host "✅ 압축 해제 완료"
    }
    catch {
        # 압축 해제 실패 시 정리
        if (Test-Path -LiteralPath $tempExtract) {
            Remove-Item -LiteralPath $tempExtract -Recurse -Force | Out-Null
        }
        Remove-Item -LiteralPath $zipPath -Force | Out-Null
        throw "압축 해제 실패: $_"
    }
    
    # junction link 생성/갱신 (jdks/{버전} -> jdks/archive/{버전}/latest)
    $junctionPath = Join-Path $script:jdksPath $Ver
    if (Test-Path -LiteralPath $junctionPath) {
        Write-Host "🔗 기존 junction 삭제 중..."
        cmd /c rmdir "$junctionPath" 2>$null
    }
    Write-Host "🔗 junction link 생성: $junctionPath -> $latestPath"
    cmd /c mklink /J "$junctionPath" "$latestPath" | Out-Null
    
    Write-Host "✨ JDK $Ver 업데이트 완료!"
}

# 메인 로직
try {
    # jdks 폴더 구조 초기화
    Initialize-JdksFolder
    
    $supportedVersions = Get-SupportedVersions -FilePath $PropsFile
    
    if ($Version -eq "all") {
        Write-Host "🚀 모든 지원 버전 업데이트 시작..."
        Write-Host "지원 버전: $($supportedVersions -join ', ')"
        
        foreach ($ver in $supportedVersions) {
            $url = Get-JdkUrl -FilePath $PropsFile -Ver $ver
            Update-Jdk -Ver $ver -Url $url -ForceDownload $Force.IsPresent
        }
        
        Write-Host ""
        Write-Host "🎉 모든 버전 업데이트 완료!"
    }
    else {
        if ($supportedVersions -notcontains $Version) {
            throw "지원하지 않는 버전입니다. 지원 버전: $($supportedVersions -join ', ')"
        }
        
        Write-Host "🚀 JDK $Version 업데이트 시작..."
        $url = Get-JdkUrl -FilePath $PropsFile -Ver $Version
        Update-Jdk -Ver $Version -Url $url -ForceDownload $Force.IsPresent
    }
}
catch {
    Write-Error "오류 발생: $_"
    exit 1
}
