# Sakhi Backend — Stage 1 Foundation

**Status:** Initial implementation in the isolated **feature/backend-stage1-foundation** worktree. This is a development/test foundation, not production authentication.

## Scope

This stage includes the NestJS + TypeScript foundation, PostgreSQL 17/Prisma 7 schema and health checks, plus a **development-only authentication API** and the Flutter debug adapter. Local test OTPs, profile/draft-consent persistence and short-lived revocable development sessions are implemented. This is not production authentication.

It implements OTP request/resend/verify, development session validation/logout, profile and draft-policy acknowledgement persistence, opt-in product-update preference storage, and fail-closed eligibility configuration/status/start endpoints. The Flutter integration is opt-in with a debug-only build define. It does **not** send SMS, prove phone possession through a carrier, provide real eligibility verification, grant protected production access, or implement admin authentication/RBAC, SOS dispatch, location persistence, complaints, messaging, commerce, or wellness data.

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
| GET    | /api/v1/eligibility/configuration     | Reports current provider/policy readiness; default implementation is unconfigured            |
| GET    | /api/v1/eligibility/status            | Authenticated status separate from phone/authentication verification                         |
| POST   | /api/v1/eligibility/start              | Requires current explicit consent and a legally approved provider; default returns 409       |
| POST   | /api/v1/eligibility/provider-callback  | Adapter-authenticated normalized results; disabled by default                               |
| POST   | /api/v1/eligibility/support-requests   | Stores category-only support/manual-review/appeal guidance intake; does not change status     |
| GET    | /api/v1/eligibility/support-requests   | Lists up to 20 support-request records belonging to the authenticated account                 |
| GET    | /api/docs                              | Development/test OpenAPI documentation                                                      |

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
- Eligibility provider adapter is disabled by default; a start request returns 409 without creating consent/session records or sending identity data. If a lawful, approved provider is later configured, the service requires versioned consent, separate biometric consent when required, HTTPS redirects to an explicit host allowlist, an opaque provider reference, and an unexpired session.
- The provider-callback route is unavailable until both provider and policy configuration are enabled. An approved adapter must authenticate the exact raw request bytes, enforce provider-specific signature/timestamp checks, and return only a normalized allowed outcome. The service accepts only active matching sessions and applies event claiming, session completion, canonical eligibility transition and redacted audit logging in one transaction. Duplicate event identifiers are idempotent; unknown, expired, terminal, malformed or unauthenticated callbacks do not grant access. No callback payload/body or identity attributes are persisted.
- Eligibility support intake stores only a bounded category and audit metadata; it neither captures free-text identity claims nor sets a review/eligibility decision. An exported verified-status guard is ready for protected controllers, but no protected community controller is currently wired to it.
- No external SMS provider, production identity provider, production credential, real person fixture, or production-sensitive feature storage is configured.
