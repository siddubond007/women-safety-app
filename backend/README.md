# Sakhi Backend — Stage 1 Foundation

**Status:** Development/test backend with a separately gated, shared-token staging-test path for invited friend testing. The staging API uses the dedicated Supabase staging project and never runs migrations during ordinary app startup. The staging admin portal is a test-only operator tool, not production authentication or an identity-evidence system.

## Scope

This stage includes the NestJS + TypeScript foundation, PostgreSQL 17/Prisma 7 schema and health checks, a development authentication API, and a separately gated staging-test authentication path for invited friend testing. Local OTP echo remains loopback-only; hosted staging uses an explicit shared test code and never sends SMS. Neither mode is production authentication.

It implements OTP request/resend/verify, session validation/logout, profile and draft-policy acknowledgement persistence, opt-in product-update preference storage, fail-closed provider configuration, explicit consent-gated manual-review submissions, a local or explicitly gated staging-test shared-token reviewer queue/history/decision API, account eligibility-status updates and decision audit records. The Flutter integration is opt-in for local backend testing and uses a separate explicit staging-test build define for invited staging testers. It does **not** send SMS, prove phone possession through a carrier, provide real provider-based eligibility verification, collect/store identity evidence, or grant protected production access. Individual admin accounts, RBAC/MFA, production auth, SOS dispatch, location persistence, complaints, messaging, commerce, and wellness data are outside this stage.

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
| GET    | /api/v1/admin-review/session      | Validates the local reviewer token or the explicitly gated staging-test reviewer token       |
| GET    | /api/v1/admin-review/queue        | Lists explicit pending submissions with masked contact details                              |
| GET    | /api/v1/admin-review/history      | Returns persisted decision audit history                                                   |
| POST   | /api/v1/admin-review/submissions/{submissionId}/decision | Persists an approval/rejection and updates account status                 |
| GET    | /api/docs                         | Development/test OpenAPI documentation                                                      |

The local development OTP echo mode is deliberately restricted to SAKHI_ENV=dev or test, non-production runtime and HOST=127.0.0.1. The development start wrapper sets that mode for the process and labels its temporary age-13 rule; the API refuses to echo codes when it is disabled. Hosted staging test mode is a separate path that requires explicit staging configuration, a protected shared OTP code and a dedicated staging database; it sends no SMS and does not prove phone ownership. A real phone can reach the host loopback API via adb reverse tcp:3000 tcp:3000, without exposing the API on the LAN. Do not change HOST to 0.0.0.0 for OTP echo.

## Safeguards

- The backend rejects unconfigured production mode, unexpected database hosts/names, mismatched database roles, invalid connection strings, and schema-generation placeholder credentials. The only hosted exception is the separately validated staging environment with the dedicated Supabase staging target and explicitly configured friend-test settings.
- The Prisma datasource configuration defaults only to a dummy local Sakhi target for commands such as prisma format and prisma generate; it cannot authenticate. Database-changing commands must be run through the environment wrapper.
- The local seed refuses production and staging, requires an explicit SAKHI_ENV, verifies the exact migration role and target database, creates only reserved fictitious local records, and is idempotent. The admin API's demo-member/demo-post seed endpoint is also blocked against the shared staging database.
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

## Hosted friend testing without SMS

The repository root contains a Render Blueprint (`render.yaml`) for the staging API service and its separate static Super Admin frontend, connected to the existing Supabase staging project. It does not create a new database or run migrations. The baseline has already been applied to the dedicated project; do not rerun `bootstrap-staging.ps1`.

For invited-friend testing only, the API supports `SAKHI_OTP_MODE=staging_test`. This is not production authentication:
- Set `SAKHI_STAGING_TEST_PHONE_ALLOWLIST=+91*` to allow any valid 10-digit Indian mobile number (starting 6–9), or provide a comma-separated E.164 allowlist for invited testers.
- `SAKHI_STAGING_TEST_OTP_CODE` is a six-digit shared code stored only in the backend host's protected environment. It is never returned by an API response and no SMS is sent.
- `SAKHI_STAGING_TEST_MINIMUM_AGE_YEARS` must be `18`.
- `+91*` means any Indian mobile number can be used with the same shared code, so anyone who knows the code can impersonate a test account by entering its number. Use only this option for an isolated staging database with fictional profile data; otherwise use an exact phone allowlist. The code never establishes phone ownership, test login must not write `phone_verified_at` or change `verification_status` to VERIFIED, and no real/sensitive personal data should be stored.
- The mode is accepted only with `SAKHI_ENV=staging`, `NODE_ENV=production`, `HOST=0.0.0.0`, a valid database target, the configured allowlist, and the six-digit code. It remains disabled everywhere else by default.
- Share the code privately only with invited testers and rotate it after the test. Never put the code or tester phone list into Git, Dart compile-time defines, the APK, logs, or a `VITE_*` variable.

### Render Blueprint setup

At the repository root, select **New → Blueprint** in Render and connect the GitHub repository/branch containing `render.yaml`. Choose the free web-service plan. The Blueprint requests values for these secrets on initial creation:
- `SAKHI_APP_DATABASE_URL`: use the `sakhi_staging_app.wmlpokholjfadyohdlgo` role on the Supabase session pooler (port 5432), database `postgres`, and append `?schema=public&sslmode=verify-full&sslrootcert=prod-ca-2021.crt`. URL-encode the role password. Do not use the `postgres` superuser or the migrator role.
- `SAKHI_STAGING_TEST_PHONE_ALLOWLIST`: set to `+91*` for any valid Indian mobile number, or enter comma-separated E.164 numbers for invited testers. The wildcard must be the only value.
- `SAKHI_STAGING_TEST_OTP_CODE`: choose a six-digit code and keep it private.

The Blueprint builds from `backend/`, pins Node to `24.22.0`, and uses `/api/v1/health/ready` for its health check. Build-time Prisma generation runs with a local non-connecting configuration; it does not need the migration-role password. Render free web services can spin down after 15 minutes idle and may take about a minute to wake up. The API connects to Supabase, so database data persists independently of the Render instance.

After the service deploys, use its assigned HTTPS URL ending in `/api/v1` as the Flutter build's `SAKHI_API_BASE_URL`. Build the test APK with `--dart-define=SAKHI_STAGING_TEST_MODE=true`; this sets the test-only banner and an 18+ client registration rule. The base URL is not secret; the shared test code and allowlist are backend-only secrets.

This staging mode enables only app-navigation testing. It does not send messages, verify a real phone number, or perform real eligibility verification. Eligibility remains unverified; do not configure fake eligibility approval or treat this as production-ready authentication.

## Staging Super Admin — restricted friend-test operator mode

The root Render Blueprint now declares a staging API and a static admin frontend. The admin portal uses the configured `VITE_API_BASE_URL` at build time; it must point to the deployed API's `/api/v1` URL, not localhost.

The public staging admin API is enabled only when all the following are true together: `SAKHI_ENV=staging`, `NODE_ENV=production`, `SAKHI_OTP_MODE=staging_test`, `SAKHI_STAGING_ADMIN_REVIEW_ENABLED=true`, and a random `SAKHI_ADMIN_REVIEW_TOKEN` with at least 32 characters. The startup path still validates the dedicated Supabase staging URL and the existing OTP-test configuration. Keep the reviewer token in Render's protected backend environment and enter it only in the operator login page; do not place it in the mobile app, `VITE_*` settings, Git, APKs, or messages to friend testers.

In staging, Super Admin can read persisted member rows and the explicit eligibility submission queue. Direct account-state override, member-creation, and demo-seed operations remain blocked in the hosted environment. Review outcomes must go through the explicit manual eligibility-review endpoint and its consent/evidence-procedure gates. This is a shared-token test tool, not individual admin authentication/MFA; restrict the token to a trusted test operator, rotate it after the test, and never enable this gate in a production environment.

The Render Blueprint uses the default frontend origin `https://sakhi-super-admin.onrender.com` in `SAKHI_ADMIN_CORS_ORIGIN` and `https://sakhi-staging-api.onrender.com/api/v1` for `VITE_API_BASE_URL`. After the blueprint creates the services, confirm their actual assigned hostnames. If Render assigns different names, update the exact HTTPS origin on the API and the API base URL on the static site, then redeploy. CORS accepts only exact HTTPS origins in staging.

Before operating the staging admin:
1. Configure `SAKHI_ADMIN_REVIEW_TOKEN` as a unique random secret (minimum 32 characters) in the backend service's protected Render environment. Do not reuse the shared six-digit OTP code as the admin token.
2. Confirm the API health endpoint returns success, then check the admin site's `/api/v1/admin-review/session` connection via a token sign-in.
3. Verify member counts and pending-review rows reflect only existing Supabase staging records. Do not use the demo seed endpoint; it is blocked in staging.
4. Use only test accounts and approved manual-review procedure. The portal does not store or display identity evidence, and staging account management is read-only outside the formal eligibility workflow.

No database migration, schema reset, or seed operation is part of this setup.
