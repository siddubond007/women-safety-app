param(
  [ValidateSet('dev', 'test')]
  [string]$Environment = 'dev'
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Load-LocalDbEnvironment.ps1') -Environment $Environment -Purpose App
$backendRoot = Split-Path -Parent $PSScriptRoot
$previousOtpMode = $env:SAKHI_OTP_MODE
$previousPreviewAge = $env:SAKHI_PREVIEW_MINIMUM_AGE_YEARS
$previousNodeEnv = $env:NODE_ENV
$previousPort = $env:PORT
$previousHost = $env:HOST
$env:NODE_ENV = 'development'
$env:SAKHI_OTP_MODE = 'development'
$env:SAKHI_PREVIEW_MINIMUM_AGE_YEARS = '13'
if ([string]::IsNullOrWhiteSpace($env:PORT)) { $env:PORT = '3000' }
if ([string]::IsNullOrWhiteSpace($env:HOST)) { $env:HOST = '127.0.0.1' }
Push-Location $backendRoot
try {
  Write-Host 'Sakhi DEV/TEST ONLY mode: OTP codes are echoed to the local app; no SMS is sent.'
  Write-Host 'Minimum age 13 is a temporary local testing rule, not approved production policy.'
  & npm.cmd run start:dev
  if ($LASTEXITCODE -ne 0) {
    throw ('Backend process exited with code ' + $LASTEXITCODE)
  }
} finally {
  Remove-Item Env:SAKHI_APP_DATABASE_URL -ErrorAction SilentlyContinue
  Remove-Item Env:SAKHI_MIGRATOR_DATABASE_URL -ErrorAction SilentlyContinue
  Remove-Item Env:SAKHI_ENV -ErrorAction SilentlyContinue
  if ($null -eq $previousOtpMode) { Remove-Item Env:SAKHI_OTP_MODE -ErrorAction SilentlyContinue } else { $env:SAKHI_OTP_MODE = $previousOtpMode }
  if ($null -eq $previousPreviewAge) { Remove-Item Env:SAKHI_PREVIEW_MINIMUM_AGE_YEARS -ErrorAction SilentlyContinue } else { $env:SAKHI_PREVIEW_MINIMUM_AGE_YEARS = $previousPreviewAge }
  if ($null -eq $previousNodeEnv) { Remove-Item Env:NODE_ENV -ErrorAction SilentlyContinue } else { $env:NODE_ENV = $previousNodeEnv }
  if ($null -eq $previousPort) { Remove-Item Env:PORT -ErrorAction SilentlyContinue } else { $env:PORT = $previousPort }
  if ($null -eq $previousHost) { Remove-Item Env:HOST -ErrorAction SilentlyContinue } else { $env:HOST = $previousHost }
  Pop-Location
}
