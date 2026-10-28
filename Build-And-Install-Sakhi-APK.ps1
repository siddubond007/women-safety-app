param(
    [string]$RepoRoot = $PSScriptRoot,
    [string]$ApiBaseUrl = "https://sakhi-staging-api.onrender.com/api/v1",
    [string]$OutputDirectory = (Join-Path $env:USERPROFILE "Downloads"),
    [switch]$SkipClean,
    [switch]$Install
)

$ErrorActionPreference = "Stop"

function Invoke-Flutter {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)

    & $script:FlutterPath @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Flutter command failed (exit $LASTEXITCODE): flutter $($Arguments -join ' ')"
    }
}

$AppDir = Join-Path $RepoRoot "app"
if (-not (Test-Path -LiteralPath $AppDir -PathType Container)) {
    throw "Could not find app/ directory at $AppDir"
}

$flutterCommand = Get-Command "flutter.bat" -ErrorAction SilentlyContinue
if ($flutterCommand) {
    $script:FlutterPath = $flutterCommand.Source
} elseif (Test-Path -LiteralPath "D:\Development\flutter\bin\flutter.bat") {
    $script:FlutterPath = "D:\Development\flutter\bin\flutter.bat"
} else {
    throw "Flutter was not found. Install/configure Flutter or add flutter.bat to PATH."
}

Write-Host "=== Sakhi v1.2.0+3 Staging APK Build & Verification ===" -ForegroundColor Cyan
Write-Host "Repository: $RepoRoot"
Write-Host "API: $ApiBaseUrl"
Write-Host "Installation is OFF by default. Use -Install only when you explicitly want to install to a connected phone."

Push-Location $AppDir
try {
    if (-not $SkipClean) {
        Write-Host "[1/5] Cleaning generated Flutter build output..." -ForegroundColor Yellow
        Invoke-Flutter -Arguments @("clean")
    } else {
        Write-Host "[1/5] Skipping flutter clean as requested." -ForegroundColor Yellow
    }

    Write-Host "[2/5] Resolving Flutter dependencies..." -ForegroundColor Yellow
    Invoke-Flutter -Arguments @("pub", "get")

    Write-Host "[3/5] Running static analysis..." -ForegroundColor Yellow
    Invoke-Flutter -Arguments @("analyze", "--no-pub")

    Write-Host "[4/5] Running Flutter tests..." -ForegroundColor Yellow
    Invoke-Flutter -Arguments @("test", "--no-pub")

    Write-Host "[5/5] Building release APK against the staging API..." -ForegroundColor Yellow
    Invoke-Flutter -Arguments @(
        "build", "apk", "--release",
        "--dart-define=SAKHI_BACKEND_ENABLED=true",
        "--dart-define=SAKHI_STAGING_TEST_MODE=true",
        "--dart-define=SAKHI_API_BASE_URL=$ApiBaseUrl"
    )

    $BuiltApk = Join-Path $AppDir "build\app\outputs\flutter-apk\app-release.apk"
    if (-not (Test-Path -LiteralPath $BuiltApk -PathType Leaf)) {
        throw "APK build did not produce $BuiltApk"
    }

    $BuiltHash = (Get-FileHash -LiteralPath $BuiltApk -Algorithm SHA256).Hash
    if (-not (Test-Path -LiteralPath $OutputDirectory -PathType Container)) {
        New-Item -ItemType Directory -Path $OutputDirectory | Out-Null
    }

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $OutputApk = Join-Path $OutputDirectory ("Sakhi_Module5_Staging_Release_" + $timestamp + ".apk")
    $suffix = 1
    while (Test-Path -LiteralPath $OutputApk) {
        $OutputApk = Join-Path $OutputDirectory ("Sakhi_Module5_Staging_Release_" + $timestamp + "_" + $suffix + ".apk")
        $suffix++
    }

    Copy-Item -LiteralPath $BuiltApk -Destination $OutputApk
    $CopiedHash = (Get-FileHash -LiteralPath $OutputApk -Algorithm SHA256).Hash
    if ($BuiltHash -ne $CopiedHash) {
        throw "Copied APK hash mismatch. The output copy must not be shared."
    }

    Write-Host "[SUCCESS] Verified staging APK: $OutputApk" -ForegroundColor Green
    Write-Host "SHA-256: $CopiedHash" -ForegroundColor Cyan

    if ($Install) {
        $adbCommand = Get-Command "adb.exe" -ErrorAction SilentlyContinue
        if (-not $adbCommand) {
            $adbCommand = Get-Command "adb" -ErrorAction SilentlyContinue
        }
        if (-not $adbCommand) {
            throw "The -Install switch was requested, but ADB was not found."
        }

        $deviceLines = & $adbCommand.Source devices
        if ($LASTEXITCODE -ne 0) {
            throw "ADB could not enumerate devices."
        }
        $connected = @($deviceLines | Select-String -Pattern "\tdevice$")
        if ($connected.Count -eq 0) {
            throw "The -Install switch was requested, but no authorized Android device is connected."
        }

        $confirmation = Read-Host "Type INSTALL to install this exact verified APK on the connected device"
        if ($confirmation -cne "INSTALL") {
            Write-Host "Installation cancelled; the verified APK was kept at $OutputApk." -ForegroundColor Yellow
        } else {
            & $adbCommand.Source install -r $OutputApk
            if ($LASTEXITCODE -ne 0) {
                throw "ADB installation failed (exit $LASTEXITCODE)."
            }
            Write-Host "APK installation completed." -ForegroundColor Green
        }
    } else {
        Write-Host "No installation attempted. Pass -Install to opt in explicitly." -ForegroundColor Yellow
    }
} finally {
    Pop-Location
}
