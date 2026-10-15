param(
  [ValidateSet('dev', 'test')]
  [string]$Environment = 'dev'
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Load-LocalDbEnvironment.ps1') -Environment $Environment -Purpose Migrator
$backendRoot = Split-Path -Parent $PSScriptRoot
Push-Location $backendRoot
try {
  & npm.cmd run db:migrate:deploy
  if ($LASTEXITCODE -ne 0) {
    throw ('Migration deploy failed with code ' + $LASTEXITCODE + '. No reset or drop command is run by this wrapper.')
  }
} finally {
  Remove-Item Env:SAKHI_MIGRATOR_DATABASE_URL -ErrorAction SilentlyContinue
  Remove-Item Env:SAKHI_ENV -ErrorAction SilentlyContinue
  Pop-Location
}
