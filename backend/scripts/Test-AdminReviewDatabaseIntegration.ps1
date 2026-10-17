$ErrorActionPreference = 'Stop'

$backendRoot = Split-Path -Parent $PSScriptRoot
$repoRoot = Split-Path -Parent $backendRoot
$requiredBranch = 'feat/admin-eligibility-review-backend'
$branch = (& git -C $repoRoot branch --show-current).Trim()
if ($branch -ne $requiredBranch) {
  throw "Expected branch '$requiredBranch'; found '$branch'. No test database writes were started."
}

$environmentNames = @(
  'PATH',
  'SAKHI_ENV',
  'SAKHI_APP_DATABASE_URL',
  'SAKHI_MIGRATOR_DATABASE_URL',
  'SAKHI_DB_INTEGRATION',
  'NODE_ENV',
  'HOST',
  'PORT',
  'SAKHI_OTP_MODE',
  'SAKHI_PREVIEW_MINIMUM_AGE_YEARS',
  'SAKHI_ADMIN_REVIEW_TOKEN',
  'SAKHI_ADMIN_REVIEWER_LABEL',
  'SAKHI_MANUAL_REVIEW_POLICY_APPROVED',
  'SAKHI_MANUAL_REVIEW_EVIDENCE_PROCEDURE_APPROVED',
  'SAKHI_MANUAL_REVIEW_CONSENT_VERSION',
  'SAKHI_MANUAL_REVIEW_CONSENT_TEXT',
  'SAKHI_MANUAL_REVIEW_DESCRIPTION',
  'SAKHI_MANUAL_REVIEW_DATA_HANDLING_DESCRIPTION',
  'SAKHI_MANUAL_REVIEW_RETENTION_DESCRIPTION'
)
$previous = @{}
foreach ($name in $environmentNames) {
  $item = Get-Item -Path ('Env:' + $name) -ErrorAction SilentlyContinue
  $previous[$name] = if ($null -eq $item) { $null } else { $item.Value }
}
$locationPushed = $false
$rng = $null

try {
  Write-Host 'Preparing only the idempotent synthetic Sakhi test fixtures in sakhi_test...'
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'seed.ps1') -Environment test
  if ($LASTEXITCODE -ne 0) {
    throw 'Synthetic test-fixture seed failed. No integration tests were started.'
  }

  . (Join-Path $PSScriptRoot 'Load-LocalDbEnvironment.ps1') -Environment test -Purpose Both
  $env:NODE_ENV = 'development'
  $env:HOST = '127.0.0.1'
  $env:SAKHI_OTP_MODE = 'disabled'
  $env:SAKHI_DB_INTEGRATION = 'true'
  $env:SAKHI_ADMIN_REVIEWER_LABEL = 'Synthetic Integration Reviewer'

  # Ephemeral test-only token; never written to source control or printed.
  $bytes = New-Object byte[] 48
  $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
  $rng.GetBytes($bytes)
  $env:SAKHI_ADMIN_REVIEW_TOKEN = [Convert]::ToBase64String($bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
  [Array]::Clear($bytes, 0, $bytes.Length)

  # These values exist only in the isolated in-process test and are not an
  # approval for any running backend, identity procedure, or production policy.
  $env:SAKHI_MANUAL_REVIEW_POLICY_APPROVED = 'true'
  $env:SAKHI_MANUAL_REVIEW_EVIDENCE_PROCEDURE_APPROVED = 'true'
  $env:SAKHI_MANUAL_REVIEW_CONSENT_VERSION = 'integration-test-v1'
  $env:SAKHI_MANUAL_REVIEW_CONSENT_TEXT = 'TEST ONLY: synthetic fixtures; no real identity evidence is collected.'
  $env:SAKHI_MANUAL_REVIEW_DESCRIPTION = 'TEST ONLY: exercise the manual-review API state machine with synthetic accounts.'
  $env:SAKHI_MANUAL_REVIEW_DATA_HANDLING_DESCRIPTION = 'TEST ONLY: no real member or identity evidence data is used.'
  $env:SAKHI_MANUAL_REVIEW_RETENTION_DESCRIPTION = 'TEST ONLY: integration fixtures are deleted by the migrator cleanup step.'

  Push-Location $backendRoot
  $locationPushed = $true
  Write-Host 'Running real API routes against local sakhi_test with app-role access.'
  Write-Host 'Synthetic fixtures are removed after the test using the local test migrator role.'
  & npm.cmd run test:db-admin-review
  $testExit = $LASTEXITCODE
  if ($testExit -ne 0) {
    throw "Admin-review database integration tests failed with exit code $testExit."
  }
  Write-Host 'Admin-review database integration test passed.'
} finally {
  if ($locationPushed) { Pop-Location }
  if ($null -ne $rng) { $rng.Dispose() }
  foreach ($name in $environmentNames) {
    $value = $previous[$name]
    if ($null -eq $value) {
      Remove-Item -Path ('Env:' + $name) -ErrorAction SilentlyContinue
    } else {
      Set-Item -Path ('Env:' + $name) -Value $value
    }
  }
}
