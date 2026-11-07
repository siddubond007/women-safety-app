param(
  [Parameter(Mandatory = $true)]
  [ValidateSet('sakhi_dev_app', 'sakhi_dev_migrator', 'sakhi_test_app', 'sakhi_test_migrator')]
  [string]$Role
)

$ErrorActionPreference = 'Stop'
$credentialPath = Join-Path $env:LOCALAPPDATA 'Sakhi\credentials\sakhi-backend-db-credentials.dpapi.json'
if (!(Test-Path -LiteralPath $credentialPath)) {
  throw 'The user-local DPAPI credential store is missing.'
}
$credentialStore = Get-Content -LiteralPath $credentialPath -Raw | ConvertFrom-Json
$encrypted = $credentialStore.PSObject.Properties[$Role].Value
if ([string]::IsNullOrWhiteSpace($encrypted)) {
  throw 'The requested local Sakhi credential is missing.'
}

$secure = ConvertTo-SecureString -String $encrypted
$pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
try {
  $password = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
  Set-Clipboard -Value $password
} finally {
  [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
  $secure.Dispose()
  $password = $null
}

Write-Output ('Password copied to clipboard for ' + $Role + '. The value was not printed.')
Write-Output 'Paste it only into the matching role Password and Confirm Password fields in pgAdmin.'
Write-Output 'Clear the clipboard after use; never paste this value into chat or source control.'
