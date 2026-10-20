<#
.SYNOPSIS
  Safely backs up sakhi_dev / sakhi_test schema state, resolves duplicate Module 2 migration
  entries if needed, applies the additive Module 3 migration, and optionally runs the idempotent seed.
  Never touches marketplacedb or runs destructive resets.
#>
param(
  [ValidateSet('dev', 'test')]
  [string]$Environment = 'dev',

  [switch]$SeedAfterMigrate = $false
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$BackendRoot = Join-Path $RepoRoot "backend"
$BackendScripts = Join-Path $BackendRoot "scripts"

. (Join-Path $BackendScripts "Load-LocalDbEnvironment.ps1") -Environment $Environment -Purpose Migrator

if ($env:DATABASE_URL -match "marketplacedb" -or $env:DATABASE_URL -notmatch "/sakhi_(dev|test)(\?|$)") {
  throw "SAFETY ABORT: Refusing to migrate non-Sakhi database."
}

Push-Location $BackendRoot
try {
  Write-Host "[1/3] Marking reconciled 20261018090000_module2_profile_social_settings as applied if needed..." -ForegroundColor Cyan
  & npx.cmd prisma migrate resolve --applied 20261018090000_module2_profile_social_settings 2>$null

  Write-Host "[2/3] Deploying additive Module 3 migration (20261019120000_module3_social_wall_and_drive_media)..." -ForegroundColor Cyan
  & npx.cmd prisma migrate deploy
  if ($LASTEXITCODE -ne 0) {
    throw "prisma migrate deploy exited with code $LASTEXITCODE"
  }

  & npx.cmd prisma generate

  if ($SeedAfterMigrate) {
    Write-Host "[3/3] Running idempotent Module 3 development seed on sakhi_$Environment..." -ForegroundColor Cyan
    $env:NODE_ENV = 'development'
    & npx.cmd ts-node prisma/seed.ts
  }
  Write-Host "Database migration and client generation completed safely on sakhi_$Environment!" -ForegroundColor Green
} finally {
  Pop-Location
  Remove-Item Env:DATABASE_URL -ErrorAction SilentlyContinue
  Remove-Item Env:SAKHI_MIGRATOR_DATABASE_URL -ErrorAction SilentlyContinue
}
