# Sakhi Backend — Stage 1 Foundation

**Status:** Development/test backend. The local `sakhi_test` database has the tracked migrations through the manual-review submission schema applied as of 2026-10-17. The admin-review API is local dev/test only and is not production authentication or evidence review.

## Scope

This stage includes the NestJS + TypeScript foundation, PostgreSQL 17/Prisma 7 schema and health checks, plus a **development-only authentication API** and the Flutter debug adapter. Local test OTPs, profile/draft-consent persistence and short-lived revocable development sessions are implemented. This is not production authentication.

It implements OTP request/resend/verify, development session validation/logout, profile and draft-policy acknowledgement persistence, opt-in product-update preference storage, fail-closed provider configuration, explicit consent-gated manual-review submissions, a local shared-token reviewer queue/history/decision API, account eligibility-status updates and decision audit records. The Flutter integration remains opt-in with a debug-only build define. It does **not** send SMS, prove phone possession through a carrier, provide real provider-based eligibility verification, collect/store identity evidence, or grant protected production access. Individual admin accounts, RBAC/MFA, production auth, SOS dispatch, location persistence, complaints, messaging, commerce, and wellness data are outside this stage.

The follow-up migration adds hashed bearer-session records and a separate optional product-update preference. The seed still does not create **MemberConsent** rows because fixture data must never imply that a user accepted legal terms. The profile API only records the app's explicitly submitted draft acknowledgement in dev/test; it does not publish draft policies or mark them approved.

The policy records seeded by the demo are explicitly **DRAFT**; this stage does not invent approved Terms/Privacy content or a production minimum age.

## Local databases and permissions

The following databases are dedicated to Sakhi and created separately from all other project databases:

- **sakhi_dev** — development database, owned by **sakhi_dev_migrator**.
- **sakhi_test** — automated-test database, owned by **sakhi_test_migrator**.

Separate login roles exist for each environment:

- **sakhi_dev_app** and **sakhi_test_app** — runtime identities.
- **sakhi_dev_migrator** and **sakhi_test_migrator** — migration/seed identities.

All four roles are non-superusers and have no CREATEDB, CREATEROLE, replication, or RLS-bypass privilege. Runtime roles cannot create tables; Stage 1 readiness performs only SELECT 1. Later feature migrations must grant only the table privileges each route needs. Database URLs are validated against the exact environment, role, loopback host, and database name before the API or migration config can run. The wrappers never issue a database drop/reset command.

The database passwords are generated randomly and stored as Windows DPAPI-encrypted values under:

    %LOCALAPPDATA%\Sakhi\credentials\sakhi-backend-db-credentials.dpapi.json

They are scoped to the Windows account that created them. **Before the first migration or live database check, assign each stored password to its matching PostgreSQL login role in pgAdmin.** For each role:

1. In a normal PowerShell window, from this directory, run (replace the role argument with the role you are setting):

   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\scripts\copy-db-password.ps1" -Role sakhi_dev_migrator
   ```

2. In pgAdmin, expand **Login/Group Roles**, right-click the same role, choose **Properties → Definition**, paste the copied value into **Password** and **Confirm password**, then save.
3. Repeat for **sakhi_dev_app**, **sakhi_test_migrator**, and **sakhi_test_app**. Never paste the value into chat or source control. Clear the clipboard after use (Set-Clipboard -Value "") and clear Windows clipboard history if enabled.

The clipboard helper never prints the credential. Do not use the postgres superuser as the API runtime identity.

## Toolchain

Node.js **v24.22.0** is installed side-by-side under the current Windows user's %LOCALAPPDATA%\Programs directory. The existing system Node installation and system PATH remain unchanged. The PowerShell wrappers prepend that specific runtime locally.

PostgreSQL must be running on 127.0.0.1:5432. The repository contains no database password or committed secret .env file.

## Commands (PowerShell, from this directory)

After role passwords have been assigned in pgAdmin:

```powershell
# Apply tracked migrations without resets/drops
.\scripts\db-migrate.ps1 -Environment dev
.\scripts\db-migrate.ps1 -Environment test

# Seed only fictional, idempotent records into the selected Sakhi database
.\scripts\seed.ps1 -Environment test

# Build and run tests
.\scripts\build.ps1
.\scripts\test.ps1 -Environment test

# Start the API locally
.\scripts\start-dev.ps1
```

For the end-to-end Flutter development setup, see [DEV_INTEGRATION.md](./DEV_INTEGRATION.md).

db-migrate.ps1 uses prisma migrate deploy; it does not call migrate reset, db push, or any database deletion command. The test runner uses the test environment for configuration and never targets the development database for fixture inserts. A safe schema-only fallback URL lets Prisma formatting/client generation run without credentials; that fallback is deliberately not an authenticatable credential and is rejected by the runtime configuration.

## Development API endpoints

| Method | Route                             | Behavior                                                                                    |
| ------ | --------------------------------- | ------------------------------------------------------------------------------------------- |
| GET    | /api/v1/health/live               | Process liveness; no database access                                                        |
| GET    | /api/v1/health/ready              | Minimal database probe; sanitized 503 if unavailable                                        |
| POST   | /api/v1/auth/otp/request          | Generates a local test OTP when dev mode is explicitly enabled; no SMS                      |
| POST   | /api/v1/auth/otp/resend           | Rate-limited replacement test code; no SMS                                                  |
| POST   | /api/v1/auth/otp/verify           | Validates/consumes a code and issues a hashed-at-rest, short-lived local session            |
| POST   | /api/v1/auth/profile              | Saves profile, draft Terms/Privacy acknowledgement, and separate optional update preference |
| GET    | /api/v1/auth/me                   | Reads the account bound to a valid bearer session                                           |
| POST   | /api/v1/auth/logout               | Revokes the current bearer session                                                          |
| GET    | /api/v1/eligibility/configuration | Returns provider and policy as explicitly unavailable                                       |
| GET    | /api/v1/eligibility/status        | Authenticated provider readiness and canonical manual-review/account status                 |
| POST   | /api/v1/eligibility/start         | Creates an explicit consented submission only when the local manual-review policy is enabled |
| GET    | /api/v1/admin-review/session      | Validates the local dev/test reviewer token                                                 |
| GET    | /api/v1/admin-review/queue        | Lists explicit pending submissions with masked contact details                              |
| GET    | /api/v1/admin-review/history      | Returns persisted decision audit history                                                   |
| POST   | /api/v1/admin-review/submissions/{submissionId}/decision | Persists an approval/rejection and updates account status                 |
| GET    | /api/docs                         | Development/test OpenAPI documentation                                                      |

The development OTP mode is deliberately restricted to SAKHI_ENV=dev or test, non-production runtime and HOST=127.0.0.1. The development start wrapper sets that mode for the process and labels its temporary age-13 rule; the API refuses to echo codes when it is disabled. A real phone can reach the host loopback API via adb reverse tcp:3000 tcp:3000, without exposing the API on the LAN. Do not change HOST to 0.0.0.0 for OTP echo.

## Safeguards

- Stage 1 rejects production mode, remote database hosts, unexpected database names, mismatched app/migration roles, invalid connection strings, and a schema-generation placeholder password.
- The Prisma datasource configuration defaults only to a dummy local Sakhi target for commands such as prisma format and prisma generate; it cannot authenticate. Database-changing commands must be run through the environment wrapper.
- The seed refuses production mode, requires an explicit SAKHI_ENV, verifies the exact migration role and target database, creates only a reserved fictitious phone number and an .invalid email, and is idempotent.
- Seeded policy records are draft-only. The seed does not create consent, OTPs, sessions, or audit records.
- Request bodies are size-limited; a global whitelist/validation pipe rejects unknown properties. Structured logs redact common authentication/contact fields and never serialize request bodies or query strings. Error responses do not expose driver errors or connection details.
- Development code echo is not SMS delivery and not carrier verification. It uses short expiry, per-challenge hashed codes, attempt limits and request throttling. It can run only on loopback in dev/test.
- Bearer tokens are generated with cryptographic randomness; only SHA-256 digests are stored in PostgreSQL; sessions have a 12-hour expiry and can be revoked.
- Profile writes require the authenticated development session, a real (non-future) accepted-at timestamp, matching draft policy metadata and only the temporary age-13 dev/test rule. Production startup is disabled.
- Eligibility APIs always fail closed with provider unavailable. They do not create an external provider session, collect identity evidence, or infer a user's eligibility.
- No external SMS provider, production identity provider, production credential, real person fixture, or production-sensitive feature storage is configured.


## Manual eligibility-review database integration test

The test database is migrated through the explicit eligibility-submission schema. To exercise the actual NestJS routes against `sakhi_test`, run this from the repository root in PowerShell:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\backend\scripts\Test-AdminReviewDatabaseIntegration.ps1"
```

The runner checks the feature branch, performs only the idempotent synthetic seed in `sakhi_test`, configures ephemeral test-only policy/reviewer values inside the test process, and exercises submission, queue, approval, rejection, status and audit history through HTTP routes. It deletes the synthetic accounts, sessions, consents, submissions and test audit events afterward using the local `sakhi_test_migrator` role. It does not reset/drop a database, touch `sakhi_dev`/`marketplacedb`, enable a live backend policy, or create any identity evidence. These synthetic settings are test fixtures, not actual policy/legal approval.

## Local Google Drive media storage (dev/test only)

The optional media pipeline stores real JPG, PNG, or WebP file bytes in the Google Drive account that completes the local OAuth flow. Actual image bytes live in Drive; the backend uses the existing PostgreSQL `audit_events` records to retain the owner, purpose, Drive file ID, MIME type, byte size and backend media URL. This feature does not add a database migration or change database grants. Verification-evidence uploads are intentionally not enabled.

### One-time setup on Windows

1. In Google Cloud Console, enable Google Drive API, configure the OAuth consent screen and add the Google account as a test user. Configure the `drive.file` scope:
   `https://www.googleapis.com/auth/drive.file`.
2. Create/use a Web application OAuth client. Its authorized redirect URI must be exactly:
   `http://127.0.0.1:3001/api/v1/integrations/google-drive/callback`
3. From `backend/`, run:
   ```powershell
   .\scripts\Set-GoogleDriveCredentials.ps1
   ```
   Enter the OAuth client ID and the active client secret at the hidden prompt. The script encrypts both using Windows DPAPI and saves them outside the repository at `%LOCALAPPDATA%\Sakhi\credentials\google-drive-credentials.dpapi.json`. Do not commit or share this file or the secret.
4. Start the local backend using `.\scripts\start-dev.ps1 -Environment dev`. The wrapper loads the DPAPI credentials and defaults the backend to `127.0.0.1:3001`.
5. Open `http://127.0.0.1:3001/api/v1/integrations/google-drive/connect` in the same Windows browser, sign in using the configured test user, and approve Sakhi's Drive access. The callback stores the refresh token using DPAPI. Confirm:
   `http://127.0.0.1:3001/api/v1/integrations/google-drive/status`
   should report `configured: true` and `connected: true`.

The `SAKHI_GOOGLE_DRIVE_*` settings are backend-process variables only; never expose them to Flutter, Vite, or GitHub.

### Upload contract and current limitations

- Authenticated multipart endpoint: `POST /api/v1/module2/media/binary-upload`, with one `file` field and a `purpose` field of `avatar` or `post`.
- Accepted content: JPG/JPEG, PNG or WebP, at most 10 MiB. The backend checks both MIME type and file signature.
- The actual binary is uploaded to a private `Sakhi Media` folder in the connected Drive account. The Drive file ID and ownership metadata are saved to the existing PostgreSQL audit metadata; profile-photo URLs and community post image references use the backend media URL.
- Metadata-only `media/presign` and JSON placeholder `media/upload` routes are disabled and reject calls rather than claiming an image was stored.
- The local OAuth application remains in Testing. Google OAuth refresh tokens issued while an external app remains in Testing expire after seven days for non-basic scopes, so reconnect Drive when the status endpoint reports it is no longer connected.
- This is a local development integration, not a production-ready media authorization/CDN layer. The opaque backend media URL is not currently protected by per-user authorization. Do not upload verification evidence or other sensitive media; add authorization, retention, deletion and production OAuth review before deployment.
