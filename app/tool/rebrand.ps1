[CmdletBinding()]
param(
    [string]$AppName,
    [string]$ShortName,
    [string]$Tagline,
    [string]$Description,
    [string]$LogoPath,
    [string]$IconPath
)

$ErrorActionPreference = 'Stop'
$appRoot = Split-Path -Parent $PSScriptRoot
$configPath = Join-Path $appRoot 'branding\brand.json'

function Write-Utf8NoBom {
    param([string]$Path, [string]$Content)
    $encoding = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($Path, $Content, $encoding)
}

function ConvertTo-DartString {
    param([string]$Value)
    $escaped = ([string]$Value).Replace('\', '\\').Replace("'", "\'").Replace('$', '\$')
    $escaped = $escaped.Replace([char]13, '\r').Replace([char]10, '\n')
    return "'" + $escaped + "'"
}

function ConvertTo-DartColor {
    param([string]$Value)
    if ($Value -notmatch '^#?([0-9A-Fa-f]{6})$') {
        throw "Expected a six-digit RGB color like #79318A; received: $Value"
    }
    return 'Color(0xFF' + $Matches[1].ToUpperInvariant() + ')'
}

function ConvertTo-XmlText {
    param([string]$Value)
    return [System.Security.SecurityElement]::Escape([string]$Value)
}

function Set-YamlQuotedValue {
    param([string]$Content, [string]$Key, [string]$Value)
    $pattern = '(?m)^([ \t]*' + [regex]::Escape($Key) + '[ \t]*")[^"]+(".*)$'
    $safeValue = ([string]$Value).Replace('$', '$$')
    return [regex]::Replace($Content, $pattern, ('$1' + $safeValue + '$2'))
}

function Normalize-LauncherIcon {
    param([string]$Path)
    Add-Type -AssemblyName System.Drawing
    $source = [System.Drawing.Image]::FromFile($Path)
    $temporary = $Path + '.square.tmp.png'
    try {
        if ($source.Width -eq $source.Height) {
            return
        }
        # Pad rather than crop or stretch; transparent space protects the icon
        # when Android applies its circular or squircle launcher mask.
        $side = [int][Math]::Ceiling([Math]::Max($source.Width, $source.Height) / 0.72)
        $canvas = [System.Drawing.Bitmap]::new(
            $side, $side, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
        )
        $graphics = [System.Drawing.Graphics]::FromImage($canvas)
        try {
            $graphics.Clear([System.Drawing.Color]::Transparent)
            $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            $graphics.DrawImage(
                $source,
                [int](($side - $source.Width) / 2),
                [int](($side - $source.Height) / 2),
                $source.Width,
                $source.Height
            )
            $canvas.Save($temporary, [System.Drawing.Imaging.ImageFormat]::Png)
        }
        finally {
            $graphics.Dispose()
            $canvas.Dispose()
        }
    }
    finally {
        $source.Dispose()
    }
    Move-Item -LiteralPath $temporary -Destination $Path -Force
}

if (-not (Test-Path -LiteralPath $configPath)) {
    throw "Brand profile not found: $configPath"
}
$brand = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
$previousAppName = [string]$brand.appName
if (-not [string]::IsNullOrWhiteSpace($AppName)) { $brand.appName = $AppName.Trim() }
if (-not [string]::IsNullOrWhiteSpace($ShortName)) {
    $brand.shortName = $ShortName.Trim()
}
elseif ($brand.appName -ne $previousAppName -and $brand.shortName -eq $previousAppName) {
    $brand.shortName = $brand.appName
}
if (-not [string]::IsNullOrWhiteSpace($Tagline)) { $brand.tagline = $Tagline.Trim() }
if (-not [string]::IsNullOrWhiteSpace($Description)) { $brand.description = $Description.Trim() }

foreach ($colorName in @('primary', 'darkText', 'mutedText', 'background', 'ivory', 'lavender', 'pink', 'progressInactive')) {
    $colorValue = [string]$brand.colors.$colorName
    if ($colorValue -notmatch '^#[0-9A-Fa-f]{6}$') {
        throw "Invalid color in brand.json for '$colorName': $colorValue"
    }
}

foreach ($item in @(
    @{ Source = $LogoPath; Key = 'logoAsset'; Label = 'logo' },
    @{ Source = $IconPath; Key = 'iconAsset'; Label = 'icon' }
)) {
    if (-not [string]::IsNullOrWhiteSpace($item.Source)) {
        $resolved = (Resolve-Path -LiteralPath $item.Source).Path
        if ([System.IO.Path]::GetExtension($resolved).ToLowerInvariant() -ne '.png') {
            throw "The new $($item.Label) must be a PNG file: $resolved"
        }
        $assetKey = [string]$item.Key
        $assetRelativePath = [string]$brand.$assetKey
        $destination = Join-Path $appRoot $assetRelativePath.Replace('/', '\')
        if ([System.IO.Path]::GetFullPath($resolved) -ne [System.IO.Path]::GetFullPath($destination)) {
            Copy-Item -LiteralPath $resolved -Destination $destination -Force
        }
    }
}
$iconFile = Join-Path $appRoot 'assets\brand\app_icon.png'
if (Test-Path -LiteralPath $iconFile) {
    Normalize-LauncherIcon -Path $iconFile
}

Write-Utf8NoBom -Path $configPath -Content ($brand | ConvertTo-Json -Depth 8)

$dartTemplate = @'
import 'package:flutter/material.dart';

/// Generated from branding/brand.json by tool/rebrand.ps1.
abstract final class AppBrand {
  static const String appName = __APP_NAME__;
  static const String shortName = __SHORT_NAME__;
  static const String tagline = __TAGLINE__;
  static const String description = __DESCRIPTION__;

  /// Keep these filenames stable; replace their contents when rebranding.
  static const String logoAsset = 'assets/brand/app_logo.png';
  static const String iconAsset = 'assets/brand/app_icon.png';
  static const String logoSemanticsLabel = __LOGO_SEMANTICS_LABEL__;

  static const Color primaryColor = __PRIMARY_COLOR__;
  static const Color darkTextColor = __DARK_TEXT_COLOR__;
  static const Color mutedTextColor = __MUTED_TEXT_COLOR__;
  static const Color backgroundColor = __BACKGROUND_COLOR__;
  static const Color ivoryColor = __IVORY_COLOR__;
  static const Color lavenderColor = __LAVENDER_COLOR__;
  static const Color pinkColor = __PINK_COLOR__;
  static const Color progressInactiveColor = __PROGRESS_INACTIVE_COLOR__;
}
'@

$replacements = @{
    '__APP_NAME__' = (ConvertTo-DartString ([string]$brand.appName))
    '__SHORT_NAME__' = (ConvertTo-DartString ([string]$brand.shortName))
    '__TAGLINE__' = (ConvertTo-DartString ([string]$brand.tagline))
    '__DESCRIPTION__' = (ConvertTo-DartString ([string]$brand.description))
    '__LOGO_SEMANTICS_LABEL__' = (ConvertTo-DartString (([string]$brand.appName) + ' — ' + ([string]$brand.tagline)))
    '__PRIMARY_COLOR__' = (ConvertTo-DartColor ([string]$brand.colors.primary))
    '__DARK_TEXT_COLOR__' = (ConvertTo-DartColor ([string]$brand.colors.darkText))
    '__MUTED_TEXT_COLOR__' = (ConvertTo-DartColor ([string]$brand.colors.mutedText))
    '__BACKGROUND_COLOR__' = (ConvertTo-DartColor ([string]$brand.colors.background))
    '__IVORY_COLOR__' = (ConvertTo-DartColor ([string]$brand.colors.ivory))
    '__LAVENDER_COLOR__' = (ConvertTo-DartColor ([string]$brand.colors.lavender))
    '__PINK_COLOR__' = (ConvertTo-DartColor ([string]$brand.colors.pink))
    '__PROGRESS_INACTIVE_COLOR__' = (ConvertTo-DartColor ([string]$brand.colors.progressInactive))
}
foreach ($key in $replacements.Keys) {
    $dartTemplate = $dartTemplate.Replace($key, [string]$replacements[$key])
}
Write-Utf8NoBom -Path (Join-Path $appRoot 'lib\core\branding\app_brand.dart') -Content $dartTemplate

$androidManifestPath = Join-Path $appRoot 'android\app\src\main\AndroidManifest.xml'
$androidManifest = Get-Content -LiteralPath $androidManifestPath -Raw -Encoding UTF8
$androidManifest = [regex]::Replace($androidManifest, 'android:label="[^"]+"', 'android:label="@string/app_name"')
Write-Utf8NoBom -Path $androidManifestPath -Content $androidManifest

$stringsPath = Join-Path $appRoot 'android\app\src\main\res\values\strings.xml'
$escapedName = ConvertTo-XmlText ([string]$brand.appName)
if (Test-Path -LiteralPath $stringsPath) {
    $strings = Get-Content -LiteralPath $stringsPath -Raw -Encoding UTF8
    $safeName = $escapedName.Replace('$', '$$')
    $strings = [regex]::Replace($strings, '(<string\s+name="app_name">).*?(</string>)', ('$1' + $safeName + '$2'))
}
else {
    $strings = '<?xml version="1.0" encoding="utf-8"?>' + [Environment]::NewLine +
        '<resources>' + [Environment]::NewLine +
        '    <string name="app_name">' + $escapedName + '</string>' + [Environment]::NewLine +
        '</resources>' + [Environment]::NewLine
}
Write-Utf8NoBom -Path $stringsPath -Content $strings

$infoPath = Join-Path $appRoot 'ios\Runner\Info.plist'
$info = Get-Content -LiteralPath $infoPath -Raw -Encoding UTF8
$safeName = $escapedName.Replace('$', '$$')
$info = [regex]::Replace($info, '(?s)(<key>CFBundleDisplayName</key>\s*<string>).*?(</string>)', ('$1' + $safeName + '$2'))
$shortXmlName = ConvertTo-XmlText ([string]$brand.shortName)
$safeShortName = $shortXmlName.Replace('$', '$$')
$info = [regex]::Replace($info, '(?s)(<key>CFBundleName</key>\s*<string>).*?(</string>)', ('$1' + $safeShortName + '$2'))
Write-Utf8NoBom -Path $infoPath -Content $info

$webManifestPath = Join-Path $appRoot 'web\manifest.json'
$webManifest = Get-Content -LiteralPath $webManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$webManifest.name = [string]$brand.appName
$webManifest.short_name = [string]$brand.shortName
$webManifest.description = [string]$brand.description
$webManifest.theme_color = [string]$brand.colors.primary
$webManifest.background_color = [string]$brand.colors.background
Write-Utf8NoBom -Path $webManifestPath -Content ($webManifest | ConvertTo-Json -Depth 12)

$pubspecPath = Join-Path $appRoot 'pubspec.yaml'
$pubspec = Get-Content -LiteralPath $pubspecPath -Raw -Encoding UTF8
$pubspec = Set-YamlQuotedValue -Content $pubspec -Key 'adaptive_icon_background:' -Value ([string]$brand.colors.background)
$pubspec = Set-YamlQuotedValue -Content $pubspec -Key 'background_color:' -Value ([string]$brand.colors.background)
$pubspec = Set-YamlQuotedValue -Content $pubspec -Key 'theme_color:' -Value ([string]$brand.colors.primary)
Write-Utf8NoBom -Path $pubspecPath -Content $pubspec

Write-Host ''
Write-Host 'Brand settings synchronized.' -ForegroundColor Green
Write-Host 'The app name, tagline, colors, native display labels, and web metadata have been updated.'
Write-Host 'Resolving dependencies and generating launcher icons...'

$flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
$flutterPath = if ($flutterCommand) { $flutterCommand.Source } else { 'D:\Development\flutter\bin\flutter.bat' }
if (-not (Test-Path -LiteralPath $flutterPath)) {
    throw "Could not find Flutter at '$flutterPath'. Files are synchronized; install Flutter or update the Flutter path, then run pub get and dart run flutter_launcher_icons from the app directory."
}
$dartPath = Join-Path (Split-Path -Parent $flutterPath) 'dart.bat'
if (-not (Test-Path -LiteralPath $dartPath)) {
    throw "Could not find dart.bat next to Flutter at '$flutterPath'. Files are synchronized; run pub get and dart run flutter_launcher_icons manually."
}
Push-Location $appRoot
try {
    & $flutterPath pub get
    if ($LASTEXITCODE -ne 0) { throw "flutter pub get failed with exit code $LASTEXITCODE" }
    & $dartPath run flutter_launcher_icons
    if ($LASTEXITCODE -ne 0) { throw "flutter_launcher_icons failed with exit code $LASTEXITCODE" }
}
finally {
    Pop-Location
}
Write-Host ''
Write-Host 'Rebranding complete. Review generated icon files in git diff, then run flutter analyze, flutter test, and flutter build apk --release.' -ForegroundColor Green
