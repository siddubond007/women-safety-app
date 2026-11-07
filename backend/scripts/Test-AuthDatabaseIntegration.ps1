param()

$ErrorActionPreference = 'Stop'
$backendRoot = Split-Path -Parent $PSScriptRoot

$previous = @{
  PATH = $env:PATH
  SAKHI_ENV = $env:SAKHI_ENV
  SAKHI_APP_DATABASE_URL = $env:SAKHI_APP_DATABASE_URL
  NODE_ENV = $env:NODE_ENV
  SAKHI_OTP_MODE = $env:SAKHI_OTP_MODE
  SAKHI_PREVIEW_MINIMUM_AGE_YEARS = $env:SAKHI_PREVIEW_MINIMUM_AGE_YEARS
  SAKHI_DB_INTEGRATION = $env:SAKHI_DB_INTEGRATION
  HOST = $env:HOST
}

try {
  . (Join-Path $PSScriptRoot 'Load-LocalDbEnvironment.ps1') -Environment test -Purpose App
  $env:NODE_ENV = 'development'
  $env:SAKHI_OTP_MODE = 'development'
  $env:SAKHI_PREVIEW_MINIMUM_AGE_YEARS = '13'
  $env:SAKHI_DB_INTEGRATION = 'true'
  $env:HOST = '127.0.0.1'

  Push-Location $backendRoot
  try {
    Write-Host 'Running real authentication integration flow against local sakhi_test only.'
    Write-Host 'The test uses a synthetic phone number; OTP echo is local only and no SMS is sent.'
    & npm.cmd run test:db-integration
    if ($LASTEXITCODE -ne 0) {
      throw ('Database-backed authentication integration test failed with exit code ' + $LASTEXITCODE)
    }
  } finally {
    Pop-Location
  }
} finally {
  foreach ($name in @('SAKHI_ENV', 'SAKHI_APP_DATABASE_URL', 'NODE_ENV', 'SAKHI_OTP_MODE', 'SAKHI_PREVIEW_MINIMUM_AGE_YEARS', 'SAKHI_DB_INTEGRATION', 'HOST')) {
    $value = $previous[$name]
    if ($null -eq $value) {
      Remove-Item -Path ('Env:' + $name) -ErrorAction SilentlyContinue
    } else {
      Set-Item -Path ('Env:' + $name) -Value $value
    }
  }
  $env:PATH = $previous.PATH
}
