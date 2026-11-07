param(
  [ValidateSet('dev', 'test')]
  [string]$Environment = 'dev',
  [ValidateSet('App', 'Migrator', 'Both')]
  [string]$Purpose = 'App'
)

$ErrorActionPreference = 'Stop'

$nodeDir = Join-Path $env:LOCALAPPDATA 'Programs\node-v24.22.0-win-x64'
if (!(Test-Path -LiteralPath (Join-Path $nodeDir 'node.exe'))) {
  throw 'Node.js 24.22.0 was not found in the expected user-local location.'
}
$env:PATH = $nodeDir + ';' + $env:PATH
$env:SAKHI_ENV = $Environment

$credentialPath = Join-Path $env:LOCALAPPDATA 'Sakhi\credentials\sakhi-backend-db-credentials.dpapi.json'
if (!(Test-Path -LiteralPath $credentialPath)) {
  throw 'The user-local DPAPI credential store is missing.'
}
$credentialStore = Get-Content -LiteralPath $credentialPath -Raw | ConvertFrom-Json

function Get-SakhiSecret([string]$RoleName) {
  $encrypted = $credentialStore.PSObject.Properties[$RoleName].Value
  if ([string]::IsNullOrWhiteSpace($encrypted)) {
    throw 'A required local Sakhi credential is missing.'
  }
  $secure = ConvertTo-SecureString -String $encrypted
  $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
  try {
    return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
  } finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
    $secure.Dispose()
  }
}

$database = if ($Environment -eq 'test') { 'sakhi_test' } else { 'sakhi_dev' }
$appRole = if ($Environment -eq 'test') { 'sakhi_test_app' } else { 'sakhi_dev_app' }
$migratorRole = if ($Environment -eq 'test') { 'sakhi_test_migrator' } else { 'sakhi_dev_migrator' }

if ($Purpose -eq 'App' -or $Purpose -eq 'Both') {
  $appPassword = Get-SakhiSecret $appRole
  $env:SAKHI_APP_DATABASE_URL = ('postgresql://{0}:{1}@127.0.0.1:5432/{2}?schema=public' -f $appRole, $appPassword, $database)
  $appPassword = $null
}
if ($Purpose -eq 'Migrator' -or $Purpose -eq 'Both') {
  $migrationPassword = Get-SakhiSecret $migratorRole
  $env:SAKHI_MIGRATOR_DATABASE_URL = ('postgresql://{0}:{1}@127.0.0.1:5432/{2}?schema=public' -f $migratorRole, $migrationPassword, $database)
  $migrationPassword = $null
}

if ($Purpose -eq 'App' -and $appRole -ne ('sakhi_' + $Environment + '_app')) {
  throw 'Application database role selection failed closed.'
}
if ($Purpose -eq 'Migrator' -and $migratorRole -ne ('sakhi_' + $Environment + '_migrator')) {
  throw 'Migration database role selection failed closed.'
}
