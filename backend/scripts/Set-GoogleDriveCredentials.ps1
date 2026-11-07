$ErrorActionPreference = 'Stop'

$credentialDirectory = Join-Path $env:LOCALAPPDATA 'Sakhi\credentials'
$credentialPath = Join-Path $credentialDirectory 'google-drive-credentials.dpapi.json'
New-Item -ItemType Directory -Force -Path $credentialDirectory | Out-Null

Write-Host 'Enter the OAuth Client ID from Google Cloud Console.'
$clientId = (Read-Host 'OAuth Client ID').Trim()
if ([string]::IsNullOrWhiteSpace($clientId) -or $clientId -notmatch '\.apps\.googleusercontent\.com$') {
  throw 'The OAuth Client ID does not look valid.'
}

Write-Host 'Enter the NEW enabled OAuth client secret. Input is hidden.'
$clientSecretSecure = Read-Host 'OAuth Client Secret' -AsSecureString
if ($clientSecretSecure.Length -lt 8) {
  $clientSecretSecure.Dispose()
  throw 'The OAuth client secret appears too short.'
}

$existingRefreshToken = $null
if (Test-Path -LiteralPath $credentialPath) {
  try {
    $existing = Get-Content -LiteralPath $credentialPath -Raw | ConvertFrom-Json
    $existingRefreshToken = $existing.refreshToken
  } catch {
    throw 'The existing Google Drive credential store is unreadable. Back it up before replacing it.'
  }
}

$clientIdSecure = ConvertTo-SecureString -String $clientId -AsPlainText -Force
$store = [ordered]@{
  clientId = ConvertFrom-SecureString -SecureString $clientIdSecure
  clientSecret = ConvertFrom-SecureString -SecureString $clientSecretSecure
  refreshToken = $existingRefreshToken
}
$temporaryPath = $credentialPath + '.tmp'
$store | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath $temporaryPath -Encoding UTF8
Move-Item -LiteralPath $temporaryPath -Destination $credentialPath -Force
$clientSecretSecure.Dispose()
$clientIdSecure.Dispose()

Write-Host ''
Write-Host 'Google Drive OAuth credentials saved with Windows DPAPI for this Windows user.'
Write-Host 'The credential file is outside the repository and must not be copied to another Windows account.'
Write-Host 'The refresh token will be saved automatically after OAuth consent completes.'
