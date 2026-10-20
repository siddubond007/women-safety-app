$ErrorActionPreference = 'Stop'
$backendRoot = Split-Path -Parent $PSScriptRoot
$projectRef = 'wmlpokholjfadyohdlgo'
$poolerHost = 'aws-0-ap-south-1.pooler.supabase.com'
$poolerUser = "sakhi_staging_migrator.$projectRef"

Write-Host 'Sakhi Supabase staging bootstrap. This script only targets the dedicated staging project.'
Write-Host 'It refuses to run if public already contains application tables or a Prisma migration ledger.'
$securePassword = Read-Host 'Enter the sakhi_staging_migrator password you created in Supabase SQL Editor' -AsSecureString
$pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
try {
  $rawPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
  if ($rawPassword.Length -lt 32 -or $rawPassword.Contains('REPLACE_WITH') -or $rawPassword.Contains('[YOUR-PASSWORD]')) {
    throw 'Enter the actual staging migration password (at least 32 characters), not a template placeholder.'
  }
  $encodedPassword = [System.Uri]::EscapeDataString($rawPassword)
  $env:SAKHI_ENV = 'staging'
  $env:SAKHI_MIGRATOR_DATABASE_URL = "postgresql://${poolerUser}:${encodedPassword}@${poolerHost}:5432/postgres?schema=public&sslmode=require"
} finally {
  [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
  $securePassword.Dispose()
  $rawPassword = $null
  $encodedPassword = $null
}

Push-Location $backendRoot
try {
  & node .\scripts\audit-staging-baseline.cjs
  if ($LASTEXITCODE -ne 0) { throw 'The checked-in staging baseline does not cover all existing migrations; no database changes were attempted.' }

  & node .\scripts\staging-preflight.cjs
  if ($LASTEXITCODE -ne 0) { throw 'Staging preflight failed; no schema changes were attempted.' }

  Write-Host 'Applying a single transaction containing the current Prisma schema baseline...'
  & .\node_modules\.bin\prisma.cmd db execute --file .\prisma\staging\baseline.sql
  if ($LASTEXITCODE -ne 0) { throw 'Staging baseline failed. Do not rerun blindly; inspect Supabase before continuing.' }

  $migrationNames = @(
    '20261015163000_stage1_foundation',
    '20261015170000_dev_auth_sessions',
    '20261016090000_audit_event_id_returning_privilege',
    '20261016120000_eligibility_status_domain',
    '20261016140000_eligibility_consent_sessions_support',
    '20261016150000_eligibility_provider_callback_events',
    '20261017121500_admin_manual_review_decisions',
    '20261017123000_eligibility_submissions',
    '20261018090000_module2_core_domain',
    '20261018090000_module2_profile_social_settings',
    '20261019120000_module3_social_wall_and_drive_media'
  )

  foreach ($migrationName in $migrationNames) {
    Write-Host ('Recording existing migration as part of the fresh staging baseline: ' + $migrationName)
    & .\node_modules\.bin\prisma.cmd migrate resolve --applied $migrationName
    if ($LASTEXITCODE -ne 0) { throw ('Could not record baseline migration ' + $migrationName + '. Stop and inspect the staging migration ledger.') }
  }

  Write-Host 'Adding only non-personal policy/category metadata (no fake accounts or posts)...'
  & .\node_modules\.bin\prisma.cmd db execute --file .\prisma\staging\static-data.sql
  if ($LASTEXITCODE -ne 0) { throw 'Staging static metadata seed failed. Do not run the synthetic development seed.' }

  & .\node_modules\.bin\prisma.cmd db execute --file .\prisma\staging\runtime-grants.sql
  if ($LASTEXITCODE -ne 0) { throw 'Could not apply runtime-role grants. Do not start the hosted API yet.' }

  & .\node_modules\.bin\prisma.cmd migrate status
  if ($LASTEXITCODE -ne 0) { throw 'Staging migration status check failed.' }

  Write-Host 'Staging schema bootstrap completed.' -ForegroundColor Green
  Write-Host 'No local dev/test database was targeted, and no synthetic member accounts were seeded.'
} finally {
  Remove-Item Env:SAKHI_MIGRATOR_DATABASE_URL -ErrorAction SilentlyContinue
  Remove-Item Env:SAKHI_ENV -ErrorAction SilentlyContinue
  Pop-Location
}
