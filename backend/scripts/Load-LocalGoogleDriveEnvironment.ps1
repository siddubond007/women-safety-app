$ErrorActionPreference = 'Stop'

$credentialPath = Join-Path $env:LOCALAPPDATA 'Sakhi\credentials\google-drive-credentials.dpapi.json'
if (!(Test-Path -LiteralPath $credentialPath)) {
  Write-Host 'Google Drive is not configured yet. Run scripts\Set-GoogleDriveCredentials.ps1, then restart the backend.'
  return
}

try {
  $store = Get-Content -LiteralPath $credentialPath -Raw | ConvertFrom-Json
} catch {
  throw 'The local Google Drive credential store is unreadable.'
}

function ConvertFrom-SakhiDpapiSecret([string]$EncryptedValue) {
  if ([string]::IsNullOrWhiteSpace($EncryptedValue)) { return $null }
  $secure = ConvertTo-SecureString -String $EncryptedValue
  $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
  try {
    return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
  } finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
    $secure.Dispose()
  }
}

$clientId = ConvertFrom-SakhiDpapiSecret ([string]$store.clientId)
$clientSecret = ConvertFrom-SakhiDpapiSecret ([string]$store.clientSecret)
$refreshToken = ConvertFrom-SakhiDpapiSecret ([string]$store.refreshToken)

if ([string]::IsNullOrWhiteSpace($clientId) -or [string]::IsNullOrWhiteSpace($clientSecret)) {
  throw 'Google Drive OAuth client credentials are missing. Run scripts\Set-GoogleDriveCredentials.ps1.'
}

$env:SAKHI_GOOGLE_DRIVE_CLIENT_ID = $clientId
$env:SAKHI_GOOGLE_DRIVE_CLIENT_SECRET = $clientSecret
if ([string]::IsNullOrWhiteSpace($refreshToken)) {
  Remove-Item Env:SAKHI_GOOGLE_DRIVE_REFRESH_TOKEN -ErrorAction SilentlyContinue
} else {
  $env:SAKHI_GOOGLE_DRIVE_REFRESH_TOKEN = $refreshToken
}

$env:SAKHI_GOOGLE_DRIVE_REDIRECT_URI = 'http://127.0.0.1:3001/api/v1/integrations/google-drive/callback'
Write-Host 'Google Drive OAuth client credentials loaded from the local DPAPI store.'
if ([string]::IsNullOrWhiteSpace($refreshToken)) {
  Write-Host 'Google Drive is not connected yet. After the backend starts, open http://127.0.0.1:3001/api/v1/integrations/google-drive/connect.'
} else {
  Write-Host 'Google Drive refresh token loaded from the local DPAPI store.'
}
