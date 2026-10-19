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
$previousAdminToken = $env:SAKHI_ADMIN_REVIEW_TOKEN
$previousGoogleDriveClientId = $env:SAKHI_GOOGLE_DRIVE_CLIENT_ID
$previousGoogleDriveClientSecret = $env:SAKHI_GOOGLE_DRIVE_CLIENT_SECRET
$previousGoogleDriveRefreshToken = $env:SAKHI_GOOGLE_DRIVE_REFRESH_TOKEN
$previousGoogleDriveRedirectUri = $env:SAKHI_GOOGLE_DRIVE_REDIRECT_URI
$env:NODE_ENV = 'development'
$env:SAKHI_OTP_MODE = 'development'
$env:SAKHI_PREVIEW_MINIMUM_AGE_YEARS = '13'
if ([string]::IsNullOrWhiteSpace($env:SAKHI_ADMIN_REVIEW_TOKEN)) {
  $env:SAKHI_ADMIN_REVIEW_TOKEN = 'sakhi-local-dev-super-admin-token-2026'
}
$env:SAKHI_ADMIN_REVIEWER_LABEL = 'Local Super Admin Reviewer'
$env:SAKHI_MANUAL_REVIEW_POLICY_APPROVED = 'true'
$env:SAKHI_MANUAL_REVIEW_EVIDENCE_PROCEDURE_APPROVED = 'true'
$env:SAKHI_MANUAL_REVIEW_CONSENT_VERSION = 'dev-manual-review-v1'
$env:SAKHI_MANUAL_REVIEW_CONSENT_TEXT = 'I consent to submitting my Sakhi development profile for local Super Admin eligibility verification.'
$env:SAKHI_MANUAL_REVIEW_DESCRIPTION = 'Your account request will appear in the local Super Admin review queue for verification.'
$env:SAKHI_MANUAL_REVIEW_DATA_HANDLING_DESCRIPTION = 'Only your display name, date of birth, and masked phone/email are shown to the local Super Admin reviewer.'
$env:SAKHI_MANUAL_REVIEW_RETENTION_DESCRIPTION = 'Review records are stored only in your local sakhi_dev PostgreSQL database.'
if ([string]::IsNullOrWhiteSpace($env:PORT)) { $env:PORT = '3001' }
if ([string]::IsNullOrWhiteSpace($env:HOST)) { $env:HOST = '127.0.0.1' }
. (Join-Path $PSScriptRoot 'Load-LocalGoogleDriveEnvironment.ps1')
Push-Location $backendRoot
try {
  Write-Host 'Sakhi DEV/TEST ONLY mode: OTP codes are echoed to the local app; no SMS is sent.'
  Write-Host 'Super Admin Reviewer Token: sakhi-local-dev-super-admin-token-2026'
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
  if ($null -eq $previousAdminToken) { Remove-Item Env:SAKHI_ADMIN_REVIEW_TOKEN -ErrorAction SilentlyContinue } else { $env:SAKHI_ADMIN_REVIEW_TOKEN = $previousAdminToken }
  if ($null -eq $previousGoogleDriveClientId) { Remove-Item Env:SAKHI_GOOGLE_DRIVE_CLIENT_ID -ErrorAction SilentlyContinue } else { $env:SAKHI_GOOGLE_DRIVE_CLIENT_ID = $previousGoogleDriveClientId }
  if ($null -eq $previousGoogleDriveClientSecret) { Remove-Item Env:SAKHI_GOOGLE_DRIVE_CLIENT_SECRET -ErrorAction SilentlyContinue } else { $env:SAKHI_GOOGLE_DRIVE_CLIENT_SECRET = $previousGoogleDriveClientSecret }
  if ($null -eq $previousGoogleDriveRefreshToken) { Remove-Item Env:SAKHI_GOOGLE_DRIVE_REFRESH_TOKEN -ErrorAction SilentlyContinue } else { $env:SAKHI_GOOGLE_DRIVE_REFRESH_TOKEN = $previousGoogleDriveRefreshToken }
  if ($null -eq $previousGoogleDriveRedirectUri) { Remove-Item Env:SAKHI_GOOGLE_DRIVE_REDIRECT_URI -ErrorAction SilentlyContinue } else { $env:SAKHI_GOOGLE_DRIVE_REDIRECT_URI = $previousGoogleDriveRedirectUri }
  Pop-Location
}
