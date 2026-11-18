# Initial Super Admin bootstrap â€” staging operator runbook

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

The staging MFA integration must never use the schema-migrator credential for teardown. The separate `sakhi_staging_fixture_cleanup` login is a restricted, non-owner cleanup identity.

The live staging preflight already found this role with the required login restrictions, database CONNECT, and public-schema USAGE. **Do not recreate it, rotate its password, or add role memberships as part of this PR.** If a future preflight finds the role missing or its attributes differ, stop and obtain separate approval before changing live role configuration.

The migration permits only the existing Supabase-managed membership where `postgres` is a member of `sakhi_staging_fixture_cleanup`, granted by `supabase_admin` with ADMIN enabled and INHERIT/SET disabled. It rejects membership granted to the cleanup role and every other membership shape. Do not add any other membership, ownership, schema CREATE, database CREATE, or TRUNCATE privilege.

## Owner-aware application of the two admin migrations

The live staging ownership inspection found:

- `sakhi_staging_migrator` owns `admin_staff_accounts` and `_prisma_migrations`.
- Supabase `postgres` owns `admin_staff_sessions`, `admin_staff_mfa`, `admin_staff_backup_codes`, and `admin_staff_recovery_requests`.
- The restricted migrator has no direct table privileges on those four child tables and cannot create their RLS policies or change their grants.
- Supabase `postgres` is not a superuser. It can `SET ROLE sakhi_staging_migrator` for the account-table operations, then reset to `postgres` for child-table operations.

Do not transfer ownership or grant the migrator broader privileges to work around this. The reviewed migration explicitly preflights the owner split and the `SET ROLE` capability, applies account-table grants and policies under `sakhi_staging_migrator`, then applies child-table grants and policies as `postgres`. The two PR #49 migrations must be applied in the Supabase SQL Editor while the execution role is `postgres`, then recorded as applied using the existing restricted Prisma migrator. Do not run `prisma migrate deploy` for these two migrations on staging.

After the PR is separately approved for the staging database change, use the exact migration SQL from the reviewed PR branch and apply them in this order:

1. `backend/prisma/migrations/20261117140000_single_use_admin_bootstrap_credential/migration.sql`
2. `backend/prisma/migrations/20261117150000_staging_mfa_fixture_cleanup_role/migration.sql`

Confirm the SQL Editor is executing as the **non-superuser `postgres` login** (not `supabase_admin`). The migration checks this session identity, the actual table owners, and the `SET ROLE` capability before making changes. Execute each complete file as-is, including its transaction boundaries. Do not edit the SQL in the editor and do not continue if either migration reports an error. The migration files are available on the reviewed branch: [bootstrap credential migration](https://github.com/siddubond007/women-safety-app/blob/fix/staging-super-admin-bootstrap-20261117/backend/prisma/migrations/20261117140000_single_use_admin_bootstrap_credential/migration.sql) and [fixture-cleanup migration](https://github.com/siddubond007/women-safety-app/blob/fix/staging-super-admin-bootstrap-20261117/backend/prisma/migrations/20261117150000_staging_mfa_fixture_cleanup_role/migration.sql).

Only after both SQL files have completed successfully, use the protected operator environment with the existing `SAKHI_STAGING_MIGRATOR_DATABASE_URL` supplied as `SAKHI_MIGRATOR_DATABASE_URL`, the pinned Supabase CA, `SAKHI_ENV=staging`, and `NODE_ENV=production`. From the backend directory, record the two already-applied migrations:

```powershell
$env:SAKHI_ALLOW_STAGING_ADMIN_MIGRATION_RESOLVE = "YES_APPLY_20261117_ADMIN_BOOTSTRAP_AND_FIXTURE_CLEANUP"
npx prisma migrate resolve --applied 20261117140000_single_use_admin_bootstrap_credential
npx prisma migrate resolve --applied 20261117150000_staging_mfa_fixture_cleanup_role
npx prisma migrate status
Remove-Item Env:SAKHI_ALLOW_STAGING_ADMIN_MIGRATION_RESOLVE
```

The staging Prisma guard permits this approval phrase only for those two exact `--applied` targets. It does not authorize `migrate deploy`, `--rolled-back`, arbitrary SQL execution, or other migration names. Never place database URLs or passwords in chat, source files, shell transcripts, or CI logs.

After the migration ledger is verified, the separate MFA lifecycle job may be configured only after its own approval. Add this secret to the protected GitHub Actions `staging` environment:

- `SAKHI_STAGING_FIXTURE_CLEANUP_DATABASE_URL`: the Supabase session-pooler URL for user `sakhi_staging_fixture_cleanup.wmlpokholjfadyohdlgo`, database `postgres`, port `5432`, TLS `sslmode=verify-full`, and schema `public`.

Keep `SAKHI_STAGING_MIGRATOR_DATABASE_URL` separate and never expose it to the MFA integration job. The MFA workflow is manual-dispatch-only and must use only the dedicated fixture-cleanup secret for teardown. Do not add the GitHub secret or run the staging MFA job until separately approved.

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
2. On the first-time registration screen, enter the plaintext one-time token, Super Admin full name, email, and the password you want to use (minimum 12 characters).
3. Submit registration. The backend stores only the scrypt password hash; the plaintext password is not returned or displayed.
4. Enroll an authenticator and verify its current six-digit TOTP code. Privileged sign-in is not available until MFA verification succeeds.
5. Save the ten single-use recovery codes in a password manager. The one-time bootstrap access token is setup-only; do not treat it as a normal sign-in credential.
6. Return to the Admin Portal sign-in screen and sign in with the email, the password chosen in step 2, and your authenticator TOTP code.
7. Verify a second bootstrap attempt is rejected and the database shows one consumed bootstrap record.
8. Remove the bootstrap enable flag and remove the digest/expiry variables from Render. Keep no reusable bootstrap token configured.

## Recovery / expiry

If the credential expires before successful bootstrap, do not reuse it. Disable the bootstrap flag, generate a fresh random token and digest, set a new expiry, and confirm that no bootstrap row was consumed. If a bootstrap record exists or a Super Admin account exists, bootstrap is permanently closed; use the separately authorized staff recovery process instead.

Never delete the bootstrap record or reset `consumed_at` to reopen bootstrap. Any emergency recovery requires a reviewed, auditable database procedure and independent authorization.
