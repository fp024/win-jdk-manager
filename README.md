# 윈도우 JDK 매니저

Windows 환경에서 여러 버전의 JDK를 자동으로 관리하고 업데이트하는 스크립트 모음



## 개요

기존에는 JDK를 업데이트할 때 수동으로 다운로드 링크를 확인하고, 파일을 다운로드하고, 압축을 풀고, junction link를 연결하는 작업을 반복했는데, 이 프로젝트는 이 과정을 자동화함.

## 파일 구성

| 파일 | 설명 |
|------|------|
| `version.properties` | 지원할 JDK 버전과 다운로드 링크가 담긴 설정 파일 |
| `update-version-props.ps1` | Adoptium API를 통해 최신 다운로드 링크로 업데이트 |
| `update-jdk.ps1` | JDK 다운로드, 압축 해제, junction link 생성 자동화 |
| `update-version-props.bat` | update-version-props.ps1 래퍼 |
| `update-jdk.bat` | update-jdk.ps1 래퍼 |

## 사용법

### 1. 다운로드 링크 최신화
```powershell
.\update-version-props.bat
# 또는
.\update-version-props.ps1
```
Adoptium API에서 최신 JDK 다운로드 링크를 가져와 `version.properties`를 업데이트.

### 2. JDK 업데이트
```powershell
# 모든 지원 버전 업데이트
.\update-jdk.bat all

# 특정 버전만 업데이트
.\update-jdk.bat 17

# 강제 재다운로드 (기존 파일 무시)
.\update-jdk.bat 17 -Force
```

## 동작 방식

1. `version.properties`에서 지원 버전과 다운로드 URL 읽기
2. 동일한 zip 파일이 이미 있으면 다운로드 생략 (재다운로드는 `-Force` 옵션)
3. `jdks\archive\{버전}\` 디렉토리에 파일 다운로드
4. 임시 폴더에 압축 해제 후 내부 폴더를 `latest`로 이동
5. jdks 폴더에 junction link 생성 (`jdks\17` → `jdks\archive\17\latest`)

## 폴더 구조

```
C:\JDK\                          # junction link → C:\git\win-jdk-manager
  ├── jdks/                      # JDK 설치 폴더 (.gitignore에 포함)
  │   ├── 8/                     # junction link → archive/8/latest
  │   ├── 17/                    # junction link → archive/17/latest
  │   ├── 21/                    # junction link → archive/21/latest
  │   ├── 25/                    # junction link → archive/25/latest
  │   └── archive/
  │       ├── 8/
  │       │   ├── OpenJDK8U-xxx.zip  # 다운로드한 파일
  │       │   └── latest/            # 압축 해제된 JDK (bin, lib, ...)
  │       ├── 17/
  │       │   ├── OpenJDK17U-xxx.zip
  │       │   └── latest/
  │       ├── 21/
  │       │   └── ...
  │       └── 25/
  │           └── ...
  │
  ├── version.properties
  ├── update-version-props.ps1
  ├── update-version-props.bat
  ├── update-jdk.ps1
  └── update-jdk.bat
```

## 특징

- **스마트 다운로드**: 동일 파일이 있으면 다운로드 생략, 압축만 다시 풀기
- **자동 정리**: 이전 버전의 zip 파일과 latest 디렉토리 자동 삭제
- **Junction Link**: 버전별 폴더가 항상 최신 JDK를 가리킴
- **배치 래퍼**: PowerShell 실행 정책 문제 없이 바로 실행 가능

## 설치 가이드

### 1. 저장소 클론
```cmd
cd C:\git
git clone https://github.com/fp024/win-jdk-manager
```

### 2. C:\JDK로 Junction Link 생성
관리자 권한 명령 프롬프트에서 실행:
```cmd
mklink /J C:\JDK C:\git\win-jdk-manager\jdks
```

이렇게 하면 `C:\JDK`로 접근할 수 있고, 환경 변수에서도 `C:\JDK\17\bin` 같은 경로를 사용할 수 있음.

### 3. JDK 다운로드
```cmd
cd C:\JDK
.\update-jdk.bat all
```





## 후기

Linux용으로는 아래 리포지토리에서 먼저 진행해봤었는데, 

* https://github.com/fp024/simple-jdk-manager 

윈도우 환경용으로도 진행해보고 싶어서 코파일럿과 함께 열심히 진행했다..😅 

이제 진짜 편하게 잘 쓸 수 있을 것 같다. 👍

