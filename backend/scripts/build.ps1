$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Load-LocalDbEnvironment.ps1') -Environment dev -Purpose Both
$backendRoot = Split-Path -Parent $PSScriptRoot
Push-Location $backendRoot
try {
  & npm.cmd run build
  if ($LASTEXITCODE -ne 0) {
    throw ('Build exited with code ' + $LASTEXITCODE)
  }
} finally {
  Remove-Item Env:SAKHI_APP_DATABASE_URL -ErrorAction SilentlyContinue
  Remove-Item Env:SAKHI_MIGRATOR_DATABASE_URL -ErrorAction SilentlyContinue
  Remove-Item Env:SAKHI_ENV -ErrorAction SilentlyContinue
  Pop-Location
}
