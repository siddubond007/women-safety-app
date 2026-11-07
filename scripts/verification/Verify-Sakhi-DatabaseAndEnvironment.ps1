<#
.SYNOPSIS
  Verifies Sakhi PostgreSQL databases (sakhi_dev, sakhi_test), confirms marketplacedb
  is untouched, checks DPAPI credentials, Google Drive status, and active ports.
#>
param(
  [ValidateSet('dev', 'test')]
  [string]$Environment = 'dev'
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$BackendScripts = Join-Path $RepoRoot "backend/scripts"

Write-Host "=== 1. Checking Sakhi Local DPAPI Database Credentials ===" -ForegroundColor Cyan
. (Join-Path $BackendScripts "Load-LocalDbEnvironment.ps1") -Environment $Environment -Purpose Migrator

$dbUrl = $env:DATABASE_URL
if ([string]::IsNullOrWhiteSpace($dbUrl)) {
  throw "DATABASE_URL was not loaded by Load-LocalDbEnvironment.ps1."
}

if ($dbUrl -match "marketplacedb") {
  throw "SAFETY ABORT: DATABASE_URL points to marketplacedb! Refusing to proceed."
}
if ($dbUrl -notmatch "/sakhi_(dev|test)(\?|$)") {
  throw "SAFETY ABORT: DATABASE_URL does not target sakhi_dev or sakhi_test."
}
Write-Host "Verified safe target database in DATABASE_URL (sakhi_$Environment)." -ForegroundColor Green

Write-Host "=== 2. Checking Prisma Migration Status ===" -ForegroundColor Cyan
Push-Location (Join-Path $RepoRoot "backend")
try {
  & npx.cmd prisma migrate status
} finally {
  Pop-Location
  Remove-Item Env:DATABASE_URL -ErrorAction SilentlyContinue
  Remove-Item Env:SAKHI_MIGRATOR_DATABASE_URL -ErrorAction SilentlyContinue
}

Write-Host "=== 3. Checking Google Drive Local DPAPI Credentials ===" -ForegroundColor Cyan
. (Join-Path $BackendScripts "Load-LocalGoogleDriveEnvironment.ps1")
if ([string]::IsNullOrWhiteSpace($env:GOOGLE_DRIVE_CLIENT_ID) -or [string]::IsNullOrWhiteSpace($env:GOOGLE_DRIVE_REFRESH_TOKEN)) {
  Write-Warning "Google Drive credentials are not currently loaded in environment. Run backend/scripts/set-google-drive-credentials.ps1 if needed."
} else {
  Write-Host "Google Drive OAuth credentials are present locally." -ForegroundColor Green
}
Remove-Item Env:GOOGLE_DRIVE_CLIENT_ID -ErrorAction SilentlyContinue
Remove-Item Env:GOOGLE_DRIVE_CLIENT_SECRET -ErrorAction SilentlyContinue
Remove-Item Env:GOOGLE_DRIVE_REFRESH_TOKEN -ErrorAction SilentlyContinue

Write-Host "=== 4. Checking Local Ports 3001 (Backend) and 5173 (Super Admin) ===" -ForegroundColor Cyan
foreach ($port in @(3001, 5173)) {
  $conn = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
  if ($conn) {
    Write-Host "Port $port is ACTIVE (PID: $($conn[0].OwningProcess))." -ForegroundColor Green
  } else {
    Write-Host "Port $port is not currently listening." -ForegroundColor Yellow
  }
}
