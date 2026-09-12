# ============================================================
# build_offline.ps1 - Build gentix-apps-update.apk TANPA INTERNET
# Gentix Officer App - Flutter Release Build Script
# ============================================================

param(
    [string]$BuildMode = "release",
    [switch]$Clean = $false,
    [switch]$Verbose = $false
)

$ErrorActionPreference = "Stop"
$ProjectRoot = $PSScriptRoot

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  GENTIX APPS - Offline APK Build Script" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# --- 1. Validasi environment ---
Write-Host "[1/6] Validating environment..." -ForegroundColor Yellow

$FlutterPath = "D:\flutter\bin\flutter.bat"
$AndroidSdk = "D:\android-sdk"
$JavaHome = $env:JAVA_HOME

if (-not (Test-Path $FlutterPath)) {
    Write-Host "ERROR: Flutter not found at $FlutterPath" -ForegroundColor Red
    exit 1
}
if (-not (Test-Path $AndroidSdk)) {
    Write-Host "ERROR: Android SDK not found at $AndroidSdk" -ForegroundColor Red
    exit 1
}
if (-not $JavaHome) {
    Write-Host "ERROR: JAVA_HOME is not set" -ForegroundColor Red
    exit 1
}

Write-Host "  Flutter : $FlutterPath" -ForegroundColor Green
Write-Host "  Android SDK: $AndroidSdk" -ForegroundColor Green
Write-Host "  Java Home: $JavaHome" -ForegroundColor Green
Write-Host ""

# --- 2. Set env vars ---
Write-Host "[2/6] Setting environment variables..." -ForegroundColor Yellow
$env:ANDROID_HOME = $AndroidSdk
$env:ANDROID_SDK_ROOT = $AndroidSdk
Write-Host "  ANDROID_HOME=$env:ANDROID_HOME" -ForegroundColor Green
Write-Host ""

# --- 3. Verifikasi Gradle cache tersedia ---
Write-Host "[3/6] Checking Gradle 8.11.1 offline cache..." -ForegroundColor Yellow
$GradleDist = "$env:USERPROFILE\.gradle\wrapper\dists\gradle-8.11.1-all"
$GradleOk = Get-ChildItem -Path $GradleDist -Recurse -Filter "gradle-8.11.1-all.zip.ok" -ErrorAction SilentlyContinue

if (-not $GradleOk) {
    Write-Host "  WARNING: Gradle 8.11.1 cache not found!" -ForegroundColor Red
    Write-Host "  Please run this script with internet first to cache Gradle." -ForegroundColor Red
    exit 1
} else {
    Write-Host "  Gradle 8.11.1 cache: OK" -ForegroundColor Green
}
Write-Host ""

# --- 4. Verifikasi Flutter pub cache ---
Write-Host "[4/6] Checking Flutter pub cache..." -ForegroundColor Yellow
$PubCache = "$env:LOCALAPPDATA\Pub\Cache"
if (-not (Test-Path $PubCache)) {
    $PubCache = "$env:USERPROFILE\.pub-cache"
}
if (Test-Path $PubCache) {
    $pkgCount = (Get-ChildItem -Path "$PubCache\hosted" -Directory -ErrorAction SilentlyContinue | Measure-Object).Count
    Write-Host "  Pub cache at $PubCache ($pkgCount package sources)" -ForegroundColor Green
} else {
    Write-Host "  WARNING: Pub cache not found. Run 'flutter pub get' with internet first." -ForegroundColor Red
    exit 1
}
Write-Host ""

# --- 5. Clean jika diminta ---
if ($Clean) {
    Write-Host "[5/6] Cleaning previous build..." -ForegroundColor Yellow
    & flutter clean
    Write-Host "  Clean done." -ForegroundColor Green
} else {
    Write-Host "[5/6] Skipping clean (use -Clean to force clean)" -ForegroundColor DarkGray
}
Write-Host ""

# --- 6. Build APK ---
Write-Host "[6/6] Building release APK (offline)..." -ForegroundColor Yellow
Write-Host "  Mode: $BuildMode" -ForegroundColor Cyan
Write-Host ""

$BuildArgs = @("build", "apk", "--$BuildMode", "--no-pub")
if ($Verbose) {
    $BuildArgs += "--verbose"
}

& flutter @BuildArgs

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "BUILD FAILED! Exit code: $LASTEXITCODE" -ForegroundColor Red
    exit $LASTEXITCODE
}

# --- Copy & rename output ---
$SourceApk = "$ProjectRoot\build\app\outputs\flutter-apk\app-release.apk"
$DestApk   = "$ProjectRoot\build\app\outputs\flutter-apk\gentix-apps-update.apk"

if (Test-Path $SourceApk) {
    Copy-Item -Path $SourceApk -Destination $DestApk -Force
    $Size = [math]::Round((Get-Item $DestApk).Length / 1MB, 2)
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Green
    Write-Host "  BUILD SUCCESSFUL!" -ForegroundColor Green
    Write-Host "  APK: $DestApk" -ForegroundColor Green
    Write-Host "  Size: $Size MB" -ForegroundColor Green
    Write-Host "============================================" -ForegroundColor Green
    
    # Buka folder output di Explorer
    Start-Process explorer.exe -ArgumentList "/select,`"$DestApk`""
} else {
    Write-Host "ERROR: APK not found at expected location: $SourceApk" -ForegroundColor Red
    exit 1
}
