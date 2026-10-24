<#
.SYNOPSIS
  One-command Git branch installer, verifier, and Render/Supabase/APK handoff helper
  for Sakhi Module 4 (Emergency SOS & Personal Safety) + 168 Animated Women Quotations Loader.

.EXAMPLE
  .\Deploy-Sakhi-Module4-Branch.ps1 -TargetRepoPath "C:\Users\Siddhu\Desktop\Sakhi" -BranchName "feat/sakhi-module4-safety-sos"
#>
param(
  [Parameter(Mandatory = $false)]
  [string]$TargetRepoPath = "",

  [Parameter(Mandatory = $false)]
  [string]$BranchName = "feat/sakhi-module4-safety-sos",

  [Parameter(Mandatory = $false)]
  [switch]$RunChecks = $true,

  [Parameter(Mandatory = $false)]
  [switch]$CommitChanges = $true,

  [Parameter(Mandatory = $false)]
  [switch]$PushBranch = $false
)

$ErrorActionPreference = 'Stop'
$PackageRoot = $PSScriptRoot

Write-Host "=========================================================================" -ForegroundColor Cyan
Write-Host "  SAKHI MODULE 4 (SOS & SAFETY + 168 ANIMATED WOMEN QUOTES) DEPLOYER" -ForegroundColor Cyan
Write-Host "=========================================================================" -ForegroundColor Cyan

if ([string]::IsNullOrWhiteSpace($TargetRepoPath)) {
  $TargetRepoPath = $PackageRoot
  Write-Host "[Mode] Running in-place inside extracted directory: $TargetRepoPath" -ForegroundColor Yellow
} else {
  $TargetRepoPath = (Resolve-Path $TargetRepoPath).Path
  Write-Host "[Mode] Target Git Repository: $TargetRepoPath" -ForegroundColor Green
}

foreach ($dir in @('app', 'backend', 'super-admin')) {
  if (-not (Test-Path (Join-Path $TargetRepoPath $dir))) {
    throw "Target directory '$TargetRepoPath' is missing required folder '$dir'. Check -TargetRepoPath."
  }
}

# 1. Safety backup of existing repository before copying files
if ($TargetRepoPath -ne $PackageRoot) {
  $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
  $backupDir = Join-Path (Split-Path -Parent $TargetRepoPath) "Sakhi_Backup_Before_Module4_$timestamp"
  Write-Host "[1/6] Creating safety backup at: $backupDir" -ForegroundColor Cyan
  New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
  foreach ($sub in @('app/lib', 'app/test', 'app/assets', 'backend/src', 'backend/prisma', 'super-admin/src')) {
    $srcPath = Join-Path $TargetRepoPath $sub
    if (Test-Path $srcPath) {
      $dstPath = Join-Path $backupDir $sub
      New-Item -ItemType Directory -Path (Split-Path -Parent $dstPath) -Force | Out-Null
      Copy-Item -Path $srcPath -Destination $dstPath -Recurse -Force
    }
  }
  Write-Host "      Backup completed." -ForegroundColor Green
} else {
  Write-Host "[1/6] Operating in-place inside extracted archive." -ForegroundColor Green
}

# 2. Create or switch to the new Git branch
$gitDir = Join-Path $TargetRepoPath ".git"
if (Test-Path $gitDir) {
  Write-Host "[2/6] Switching to Git branch '$BranchName'..." -ForegroundColor Cyan
  Push-Location $TargetRepoPath
  try {
    & git checkout -B $BranchName
    Write-Host "      Active Git branch: $BranchName" -ForegroundColor Green
  } finally {
    Pop-Location
  }
} else {
  Write-Warning "[2/6] No .git directory found at $TargetRepoPath. Skipping branch checkout."
}

# 3. Copy updated source files into TargetRepoPath (preserving .env and .env.local)
if ($TargetRepoPath -ne $PackageRoot) {
  Write-Host "[3/6] Copying updated app/, backend/, super-admin/, scripts/, docs/, and render.yaml..." -ForegroundColor Cyan
  foreach ($folder in @('app', 'backend', 'super-admin', 'scripts', 'docs')) {
    $srcFolder = Join-Path $PackageRoot $folder
    if (Test-Path $srcFolder) {
      Copy-Item -Path (Join-Path $srcFolder '*') -Destination (Join-Path $TargetRepoPath $folder) -Recurse -Force
    }
  }
  $renderYaml = Join-Path $PackageRoot "render.yaml"
  if (Test-Path $renderYaml) {
    Copy-Item -Path $renderYaml -Destination (Join-Path $TargetRepoPath "render.yaml") -Force
  }
  Write-Host "      All Module 4 files and assets copied cleanly." -ForegroundColor Green
} else {
  Write-Host "[3/6] In-place mode: files already present." -ForegroundColor Green
}

# 4. Run Baseline Audit, Backend Build, Super-Admin Build, and Flutter Verification
if ($RunChecks) {
  Write-Host "[4/6] Running Staging Baseline Audit & Builds..." -ForegroundColor Cyan
  Push-Location (Join-Path $TargetRepoPath "backend")
  try {
    & node .\scripts\audit-staging-baseline.cjs
    if ($LASTEXITCODE -ne 0) { throw "Staging baseline audit failed." }
    if (Test-Path "node_modules") {
      & npx prisma generate
      & npm run build
    }
  } finally {
    Pop-Location
  }

  Push-Location (Join-Path $TargetRepoPath "super-admin")
  try {
    if (Test-Path "node_modules") {
      & npm run build
    }
  } finally {
    Pop-Location
  }

  Push-Location (Join-Path $TargetRepoPath "app")
  try {
    if (Get-Command flutter -ErrorAction SilentlyContinue) {
      & flutter pub get
      & flutter analyze
      & flutter test
    }
  } finally {
    Pop-Location
  }
  Write-Host "      All automated checks completed." -ForegroundColor Green
}

# 5. Stage & Commit on the Feature Branch
if ($CommitChanges -and (Test-Path $gitDir)) {
  Write-Host "[5/6] Staging and committing Module 4 changes on '$BranchName'..." -ForegroundColor Cyan
  Push-Location $TargetRepoPath
  try {
    & git add -A
    $status = & git status --porcelain
    if (-not [string]::IsNullOrWhiteSpace($status)) {
      & git commit -m "feat(module4): implement Emergency SOS & Personal Safety UI, live endpoints, Super-Admin console, and 168 animated women quotations loader"
      Write-Host "      Committed changes to branch '$BranchName'." -ForegroundColor Green
    } else {
      Write-Host "      Working tree is already clean." -ForegroundColor Yellow
    }
    if ($PushBranch) {
      & git push -u origin $BranchName
      Write-Host "      Pushed branch '$BranchName' to origin." -ForegroundColor Green
    }
  } finally {
    Pop-Location
  }
}

Write-Host "[6/6] Deployment preparation complete! See Sakhi_Gemini_Module4_Integration_Runbook.md for Supabase SQL and APK build steps." -ForegroundColor Green
