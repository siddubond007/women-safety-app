# Initial Super Admin bootstrap — staging operator runbook

This process is for the first Super Admin on the dedicated Sakhi staging environment only. It is not a normal staff-login method.

## Security model

- Generate a random one-time token with at least 256 bits of entropy.
- Store only its SHA-256 digest in the Render backend environment.
- Configure an absolute UTC expiry no more than 24 hours ahead.
- The backend compares the submitted token to the digest using a timing-safe comparison.
- On successful bootstrap, a singleton database row is created and consumed in the same serializable transaction as Super Admin account creation and the audit event.
- The database trigger makes consumption irreversible. A second request, concurrent request, or later retry is rejected.
- The token does not create an authenticated session. The new Super Admin must enroll and verify TOTP before any privileged session can be issued.
- The bootstrap endpoint is not enabled by setting a plaintext token. The legacy `SAKHI_STAGING_FULL_ADMIN_TOKEN` variable is not read by the hardened implementation.

## Dedicated MFA fixture-cleanup database role

The staging MFA integration must never use the schema-migrator credential for teardown. The schema migrator owns schema objects and can perform destructive DDL; it is not a test-cleanup identity.

Before applying the dedicated fixture-cleanup migration, create a separate login role in the Supabase SQL editor. Generate a 32-byte random password locally and do not commit or paste it into chat:

```powershell
$cleanupPassword = [Convert]::ToHexString([Security.Cryptography.RandomNumberGenerator]::GetBytes(32)).ToLowerInvariant()
```

Run the following SQL after replacing the password placeholder locally:

```sql
CREATE ROLE sakhi_staging_fixture_cleanup
  LOGIN PASSWORD '<64-character lowercase hex password generated locally>'
  NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;

GRANT CONNECT ON DATABASE postgres TO sakhi_staging_fixture_cleanup;
GRANT USAGE ON SCHEMA public TO sakhi_staging_fixture_cleanup;
```

Do not grant this role membership in another role, ownership of any table, schema CREATE, database CREATE, or TRUNCATE. The reviewed fixture-cleanup migration grants only the required column-level SELECT and row-filtered DELETE privileges across the five staff-security tables. Its postflight checks fail if the role can own or truncate those tables.

After the migration has been reviewed and applied, add this secret to the protected GitHub Actions `staging` environment:

- `SAKHI_STAGING_FIXTURE_CLEANUP_DATABASE_URL`: the Supabase session-pooler URL for user `sakhi_staging_fixture_cleanup.wmlpokholjfadyohdlgo`, database `postgres`, port `5432`, TLS `sslmode=verify-full`, and schema `public`.

Use the locally generated 64-character hex password in that URL. Keep `SAKHI_STAGING_MIGRATOR_DATABASE_URL` separate and never expose it to the MFA integration job. The MFA workflow is manual-dispatch-only and must use only the dedicated fixture-cleanup secret for teardown.

Do not create the role, add the GitHub secret, or apply the migration until the operator has separately approved the staging database change.

## Generate the credential locally

Use a trusted local terminal. Do not paste the plaintext token into chat, GitHub, source files, issue comments, CI logs, or a shared document.

PowerShell example:

```powershell
$token = [Convert]::ToBase64String([Security.Cryptography.RandomNumberGenerator]::GetBytes(32)).TrimEnd('=').Replace('+','-').Replace('/','_')
$bytes = [Text.Encoding]::UTF8.GetBytes($token)
$sha = [Security.Cryptography.SHA256]::HashData($bytes)
$digest = [Convert]::ToHexString($sha).ToLowerInvariant()
$expiresAt = (Get-Date).ToUniversalTime().AddHours(2).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
```

Keep `$token` in a secure password manager or secure temporary local secret store until first bootstrap completes. Never print it to terminal output or transcript. The digest is safe to configure as an environment value; the plaintext is what the operator enters into the protected setup form.

## Configure Render backend environment

Only after the implementation PR is reviewed, merged, deployed, and the migration has been applied, configure these variables on the Sakhi staging backend:

- `SAKHI_ENV=staging`
- `NODE_ENV=production`
- `SAKHI_STAGING_FULL_ADMIN_ENABLED=true`
- `SAKHI_STAGING_FULL_ADMIN_TOKEN_SHA256=<64-character lowercase SHA-256 digest>`
- `SAKHI_STAGING_FULL_ADMIN_TOKEN_EXPIRES_AT=<absolute UTC ISO-8601 expiry>`

Do not add the plaintext token to Render. Confirm the deployed backend release contains the new schema and code before enabling the flag.

## Complete initial setup

1. Open the official Sakhi staging Admin Portal over HTTPS.
2. Select **First-time staff setup / initial bootstrap**.
3. Enter the plaintext token locally, then the initial Super Admin name and email.
4. Complete authenticator enrollment and verify the current six-digit TOTP code.
5. Save the one-time staff access token and ten backup codes in a password manager.
6. Complete the initial password setup and sign in using email/username, password, and TOTP.
7. Verify a second bootstrap attempt is rejected and the database shows one consumed bootstrap record.
8. Remove the bootstrap enable flag and remove the digest/expiry variables from Render. Keep no reusable bootstrap token configured.

## Recovery / expiry

If the credential expires before successful bootstrap, do not reuse it. Disable the bootstrap flag, generate a fresh random token and digest, set a new expiry, and confirm that no bootstrap row was consumed. If a bootstrap record exists or a Super Admin account exists, bootstrap is permanently closed; use the separately authorized staff recovery process instead.

Never delete the bootstrap record or reset `consumed_at` to reopen bootstrap. Any emergency recovery requires a reviewed, auditable database procedure and independent authorization.
