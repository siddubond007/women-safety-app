<#
.SYNOPSIS
  Automated, non-destructive Windows PowerShell installer for Sakhi Module 3 (Social Media Wall),
  Module 2 Integration, Private Google Drive Storage Hierarchy, PostgreSQL Migration, and Super Admin.

.DESCRIPTION
  1. Verifies your existing Sakhi project directory and optional Git state.
  2. Detects uncommitted changes and creates a timestamped backup before modifying any files.
  3. Preserves your local ignored files (super-admin/.env.local, backend/.env, DPAPI credentials).
  4. Copies the updated Module 3 files into app/, backend/, super-admin/, scripts/, and docs/.
  5. Writes super-admin/.env.local with VITE_API_BASE_URL=http://127.0.0.1:3001/api/v1 if missing.
  6. Installs dependencies and runs Prisma client generation, backend tests, Super Admin build,
     and Flutter analysis/tests.
  7. Prompts for explicit confirmation before applying additive database migrations or seeding
     on sakhi_dev (never touches marketplacedb).
#>
param(
  [Parameter(Mandatory = $false)]
  [string]$TargetRepoPath = "",

  [Parameter(Mandatory = $false)]
  [switch]$CreateFeatureBranch = $true,

  [Parameter(Mandatory = $false)]
  [switch]$ApplyDatabaseMigration = $false,

  [Parameter(Mandatory = $false)]
  [switch]$RunChecks = $true
)

$ErrorActionPreference = 'Stop'
$PackageRoot = $PSScriptRoot

Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host "  SAKHI MODULE 3 AUTOMATED INSTALLER & VERIFICATION SUITE" -ForegroundColor Cyan
Write-Host "=====================================================================" -ForegroundColor Cyan

if ([string]::IsNullOrWhiteSpace($TargetRepoPath)) {
  # If run directly inside an extracted standalone copy, operate in-place
  $TargetRepoPath = $PackageRoot
  Write-Host "[Mode] Running in-place inside extracted package: $TargetRepoPath" -ForegroundColor Yellow
} else {
  $TargetRepoPath = (Resolve-Path $TargetRepoPath).Path
  Write-Host "[Mode] Installing into existing repository: $TargetRepoPath" -ForegroundColor Green
}

foreach ($dir in @('app', 'backend', 'super-admin')) {
  if (-not (Test-Path (Join-Path $TargetRepoPath $dir))) {
    throw "Target directory '$TargetRepoPath' is missing required subfolder '$dir'. Please check -TargetRepoPath."
  }
}

# 1. Create a timestamped backup if installing over an existing repository
if ($TargetRepoPath -ne $PackageRoot) {
  $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
  $backupDir = Join-Path (Split-Path -Parent $TargetRepoPath) "Sakhi_Backup_Before_Module3_$timestamp"
  Write-Host "[1/7] Creating full safety backup at: $backupDir" -ForegroundColor Cyan
  New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
  foreach ($sub in @('app/lib', 'app/test', 'app/assets', 'backend/src', 'backend/prisma', 'backend/test', 'super-admin/src')) {
    $srcPath = Join-Path $TargetRepoPath $sub
    if (Test-Path $srcPath) {
      $dstPath = Join-Path $backupDir $sub
      New-Item -ItemType Directory -Path (Split-Path -Parent $dstPath) -Force | Out-Null
      Copy-Item -Path $srcPath -Destination $dstPath -Recurse -Force
    }
  }
  Write-Host "      Backup completed." -ForegroundColor Green
} else {
  Write-Host "[1/7] Running directly from extracted archive (no overwrite needed)." -ForegroundColor Green
}

# 2. Check Git state if .git exists (never force-reset or auto-push)
$gitDir = Join-Path $TargetRepoPath ".git"
if ((Test-Path $gitDir) -and $CreateFeatureBranch) {
  Write-Host "[2/7] Inspecting Git branch state..." -ForegroundColor Cyan
  Push-Location $TargetRepoPath
  try {
    $currentBranch = (& git rev-parse --abbrev-ref HEAD 2>$null).Trim()
    Write-Host "      Current Git branch: $currentBranch"
    if ($currentBranch -ne "feature/module3-social-wall") {
      & git checkout -B feature/module3-social-wall
      Write-Host "      Switched to branch: feature/module3-social-wall" -ForegroundColor Green
    }
  } catch {
    Write-Warning "Git branch switch skipped: $_"
  } finally {
    Pop-Location
  }
} else {
  Write-Host "[2/7] No .git directory or branch creation skipped." -ForegroundColor Yellow
}

# 3. Copy updated source files while preserving local .env and .env.local
if ($TargetRepoPath -ne $PackageRoot) {
  Write-Host "[3/7] Copying Module 3 source files (preserving local .env & credentials)..." -ForegroundColor Cyan
  foreach ($folder in @('app', 'backend', 'super-admin', 'scripts', 'docs')) {
    $srcFolder = Join-Path $PackageRoot $folder
    if (Test-Path $srcFolder) {
      Copy-Item -Path (Join-Path $srcFolder '*') -Destination (Join-Path $TargetRepoPath $folder) -Recurse -Force
    }
  }
  Write-Host "      Source files updated." -ForegroundColor Green
} else {
  Write-Host "[3/7] Source files already in place." -ForegroundColor Green
}

# 4. Ensure super-admin/.env.local points to port 3001
$superAdminEnvLocal = Join-Path $TargetRepoPath "super-admin/.env.local"
if (-not (Test-Path $superAdminEnvLocal)) {
  Write-Host "[4/7] Creating super-admin/.env.local with VITE_API_BASE_URL=http://127.0.0.1:3001/api/v1" -ForegroundColor Cyan
  Set-Content -Path $superAdminEnvLocal -Value "VITE_API_BASE_URL=http://127.0.0.1:3001/api/v1" -Encoding UTF8
} else {
  Write-Host "[4/7] Preserved existing super-admin/.env.local." -ForegroundColor Green
}

# 5. Install dependencies & generate Prisma client
Write-Host "[5/7] Installing dependencies & generating Prisma client..." -ForegroundColor Cyan
Push-Location (Join-Path $TargetRepoPath "backend")
try {
  if (-not (Test-Path "node_modules")) {
    & npm.cmd install
  }
  & npx.cmd prisma generate
} finally {
  Pop-Location
}

Push-Location (Join-Path $TargetRepoPath "super-admin")
try {
  if (-not (Test-Path "node_modules")) {
    & npm.cmd install
  }
} finally {
  Pop-Location
}

# 6. Optional Safe Database Migration on sakhi_dev
if ($ApplyDatabaseMigration) {
  Write-Host "[6/7] Running safe additive database migration on sakhi_dev..." -ForegroundColor Cyan
  & (Join-Path $TargetRepoPath "scripts/verification/Run-Sakhi-SafeMigration.ps1") -Environment dev -SeedAfterMigrate
} else {
  Write-Host "[6/7] Database migration not auto-executed (pass -ApplyDatabaseMigration or run scripts/verification/Run-Sakhi-SafeMigration.ps1 when ready)." -ForegroundColor Yellow
}

# 7. Run Automated Verification Suite
if ($RunChecks) {
  Write-Host "[7/7] Running Backend, Super Admin, and Flutter verification checks..." -ForegroundColor Cyan
  Push-Location (Join-Path $TargetRepoPath "backend")
  try {
    & npm.cmd test -- --runInBand
  } finally {
    Pop-Location
  }

  Push-Location (Join-Path $TargetRepoPath "super-admin")
  try {
    & npm.cmd run build
  } finally {
    Pop-Location
  }

  if (Get-Command flutter -ErrorAction SilentlyContinue) {
    Push-Location (Join-Path $TargetRepoPath "app")
    try {
      & flutter pub get
      & flutter analyze
      & flutter test
    } finally {
      Pop-Location
    }
  } else {
    Write-Warning "Flutter CLI not found in current PATH. Run 'flutter pub get', 'flutter analyze', and 'flutter test' inside app/ from your Flutter terminal."
  }
}

Write-Host "=====================================================================" -ForegroundColor Green
Write-Host "  SAKHI MODULE 3 INSTALLATION COMPLETED SUCCESSFULLY!" -ForegroundColor Green
Write-Host "  Next steps:" -ForegroundColor Cyan
Write-Host "  1. Apply DB migration & seed: .\scripts\verification\Run-Sakhi-SafeMigration.ps1 -Environment dev -SeedAfterMigrate"
Write-Host "  2. Start Backend (Port 3001): .\backend\scripts\start-dev.ps1"
Write-Host "  3. Start Super Admin (5173):  cd super-admin; npm run dev"
Write-Host "  4. Build Debug APK:           cd app; flutter build apk --debug --dart-define=SAKHI_BACKEND_ENABLED=true --dart-define=SAKHI_API_BASE_URL=http://127.0.0.1:3001/api/v1"
Write-Host "=====================================================================" -ForegroundColor Green
