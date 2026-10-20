param(
  [ValidateSet('dev', 'test', 'staging')]
  [string]$Environment = 'dev'
)

$ErrorActionPreference = 'Stop'
$backendRoot = Split-Path -Parent $PSScriptRoot
Push-Location $backendRoot

try {
  if ($Environment -eq 'staging') {
    $projectRef = 'wmlpokholjfadyohdlgo'
    $poolerHost = 'aws-0-ap-south-1.pooler.supabase.com'
    $poolerUser = "sakhi_staging_migrator.$projectRef"
    $securePassword = Read-Host 'Enter the sakhi_staging_migrator password' -AsSecureString
    $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
    try {
      $rawPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
      if ($rawPassword.Length -lt 32 -or $rawPassword.Contains('REPLACE_WITH') -or $rawPassword.Contains('[YOUR-PASSWORD]')) {
        throw 'Enter the actual staging migration password (at least 32 characters), not a template placeholder.'
      }
      $encodedPassword = [System.Uri]::EscapeDataString($rawPassword)
      $env:SAKHI_ENV = 'staging'
      $env:SAKHI_MIGRATOR_DATABASE_URL = "postgresql://$($poolerUser):$encodedPassword@$($poolerHost):5432/postgres?schema=public&sslmode=require"
    } finally {
      [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
      $securePassword.Dispose()
      $rawPassword = $null
      $encodedPassword = $null
    }

    # The original migration files intentionally remain restricted to local DBs.
    # This preflight guarantees they are already recorded as applied to the baseline.
    & node .\scripts\staging-preflight.cjs migrations
    if ($LASTEXITCODE -ne 0) {
      throw 'Staging baseline preflight failed; no new migrations were run.'
    }
  } else {
    . (Join-Path $PSScriptRoot 'Load-LocalDbEnvironment.ps1') -Environment $Environment -Purpose Migrator
  }

  & npm.cmd run db:migrate:deploy
  if ($LASTEXITCODE -ne 0) {
    throw ('Migration deploy failed with code ' + $LASTEXITCODE + '. No reset or drop command is run by this wrapper.')
  }

  if ($Environment -eq 'staging') {
    # New migrations may create objects; reapply only the explicit runtime grants.
    & .\node_modules\.bin\prisma.cmd db execute --file .\prisma\staging\runtime-grants.sql
    if ($LASTEXITCODE -ne 0) {
      throw 'Staging migrations completed but runtime grants failed. Do not deploy/restart the app until grants are repaired.'
    }
  }
} finally {
  Remove-Item Env:SAKHI_MIGRATOR_DATABASE_URL -ErrorAction SilentlyContinue
  Remove-Item Env:SAKHI_ENV -ErrorAction SilentlyContinue
  Pop-Location
}
