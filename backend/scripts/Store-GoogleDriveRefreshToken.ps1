$ErrorActionPreference = 'Stop'

$raw = [Console]::In.ReadToEnd()
if ([string]::IsNullOrWhiteSpace($raw)) { throw 'No token payload was supplied.' }
try { $payload = $raw | ConvertFrom-Json } catch { throw 'The token payload is invalid.' }
$refreshToken = [string]$payload.refreshToken
if ([string]::IsNullOrWhiteSpace($refreshToken) -or $refreshToken.Length -lt 20) {
  throw 'The refresh token is missing or invalid.'
}

$credentialPath = Join-Path $env:LOCALAPPDATA 'Sakhi\credentials\google-drive-credentials.dpapi.json'
if (!(Test-Path -LiteralPath $credentialPath)) {
  throw 'The local Google Drive credential store is missing. Configure the OAuth client first.'
}
$store = Get-Content -LiteralPath $credentialPath -Raw | ConvertFrom-Json
if ([string]::IsNullOrWhiteSpace([string]$store.clientId) -or [string]::IsNullOrWhiteSpace([string]$store.clientSecret)) {
  throw 'OAuth client credentials are missing from the local store.'
}

$tokenSecure = ConvertTo-SecureString -String $refreshToken -AsPlainText -Force
$store.refreshToken = ConvertFrom-SecureString -SecureString $tokenSecure
$tokenSecure.Dispose()

$temporaryPath = $credentialPath + '.tmp'
$store | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath $temporaryPath -Encoding UTF8
Move-Item -LiteralPath $temporaryPath -Destination $credentialPath -Force
Write-Output 'Google Drive refresh token stored securely.'
