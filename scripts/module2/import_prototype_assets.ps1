[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $PrototypeZip,

    [string] $RepoRoot = ''
)

$ErrorActionPreference = 'Stop'

# Resolve the script location after parameter binding. Some invocation styles
# evaluate default parameter expressions before $PSScriptRoot is populated.
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $scriptFile = $MyInvocation.MyCommand.Path
    if ([string]::IsNullOrWhiteSpace($scriptFile)) {
        $scriptFile = $PSCommandPath
    }
    if ([string]::IsNullOrWhiteSpace($scriptFile)) {
        throw 'Cannot determine the import script path; pass -RepoRoot explicitly.'
    }
    $RepoRoot = (Resolve-Path (Join-Path (Split-Path -Parent $scriptFile) '..\..')).Path
} else {
    $RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
}

$zipPath = (Resolve-Path -LiteralPath $PrototypeZip).Path
$appRoot = Join-Path $RepoRoot 'app'
$targetAssets = Join-Path $appRoot 'assets'
$assetCatalogue = Join-Path $appRoot 'lib\core\constants\app_assets.dart'
$pubspecPath = Join-Path $appRoot 'pubspec.yaml'

foreach ($requiredPath in @($appRoot, $targetAssets, $assetCatalogue, $pubspecPath)) {
    if (-not (Test-Path -LiteralPath $requiredPath)) {
        throw "Required Sakhi path not found: $requiredPath"
    }
}

$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("sakhi-module2-assets-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempRoot | Out-Null

try {
    Expand-Archive -LiteralPath $zipPath -DestinationPath $tempRoot -Force
    $sourceAssets = Join-Path $tempRoot 'sakhi_ui_prototype\assets'
    if (-not (Test-Path -LiteralPath $sourceAssets -PathType Container)) {
        throw "The ZIP does not contain sakhi_ui_prototype\assets. Confirm you selected the approved Sakhi UI prototype archive."
    }

    $sourceFiles = @(Get-ChildItem -LiteralPath $sourceAssets -File -Recurse)
    if ($sourceFiles.Count -lt 20) {
        throw "Only $($sourceFiles.Count) prototype asset files were found; expected the full brand/icon/image bundle. No copy was performed."
    }

    # Only merge the prototype's assets into app/assets. Do not replace Dart,
    # authentication, onboarding, backend, database, or application configuration.
    Copy-Item -Path (Join-Path $sourceAssets '*') -Destination $targetAssets -Recurse -Force

    $catalogueText = Get-Content -LiteralPath $assetCatalogue -Raw
    $requiredAssets = @(
        [regex]::Matches($catalogueText, "'(assets/[^']+)'") |
        ForEach-Object { $_.Groups[1].Value } |
        Sort-Object -Unique
    )
    $missing = @(
        $requiredAssets | Where-Object {
            -not (Test-Path -LiteralPath (Join-Path $appRoot ($_ -replace '/', '\')) -PathType Leaf)
        }
    )

    if ($missing.Count -gt 0) {
        Write-Host 'Required assets still missing:' -ForegroundColor Red
        $missing | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
        throw "Asset import incomplete. $($missing.Count) referenced assets are missing."
    }

    $pubspecText = Get-Content -LiteralPath $pubspecPath -Raw
    $requiredDirectories = @($requiredAssets | ForEach-Object { ($_ -replace '/', '\') -replace '\\[^\\]+$', '' } | Sort-Object -Unique)
    $unregisteredDirectories = @(
        $requiredDirectories | Where-Object {
            $yamlPath = $_ -replace '\\', '/'
            $pubspecText -notmatch [regex]::Escape("- $yamlPath/")
        }
    )

    Write-Host "Copied $($sourceFiles.Count) prototype asset files into app/assets." -ForegroundColor Green
    Write-Host "Verified $($requiredAssets.Count) paths referenced by AppAssets." -ForegroundColor Green
    if ($unregisteredDirectories.Count -gt 0) {
        Write-Host 'Review pubspec.yaml asset registrations for:' -ForegroundColor Yellow
        $unregisteredDirectories | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
        throw 'One or more AppAssets directories are not registered in pubspec.yaml.'
    }

    Write-Host ''
    Write-Host 'Next: run flutter pub get, flutter analyze, flutter test, and flutter build apk --release from app/.' -ForegroundColor Cyan
    Write-Host 'When the asset checks are clean, review and commit only the new/changed files under app/assets/ to the Module 2 branch.'
}
finally {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
