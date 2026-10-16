param(
  [ValidateSet('dev', 'test')]
  [string]$Environment = 'test'
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Load-LocalDbEnvironment.ps1') -Environment $Environment -Purpose Both
$backendRoot = Split-Path -Parent $PSScriptRoot
Push-Location $backendRoot
try {
  & npm.cmd test
  if ($LASTEXITCODE -ne 0) {
    throw ('Tests exited with code ' + $LASTEXITCODE)
  }
} finally {
  Remove-Item Env:SAKHI_APP_DATABASE_URL -ErrorAction SilentlyContinue
  Remove-Item Env:SAKHI_MIGRATOR_DATABASE_URL -ErrorAction SilentlyContinue
  Remove-Item Env:SAKHI_ENV -ErrorAction SilentlyContinue
  Pop-Location
}
