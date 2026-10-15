# Sakhi Backend — Stage 1 Foundation

**Status:** Initial implementation in the isolated **feature/backend-stage1-foundation** worktree. This is a development/test foundation, not production authentication.

## Scope

This stage provides NestJS + TypeScript, PostgreSQL 17 connectivity through Prisma ORM 7, the initial member/OTP metadata/consent/audit schema, safe synthetic seed tooling, health endpoints, OpenAPI docs, input validation, centralized safe errors, redacted structured request logs, and automated tests.

It deliberately does **not** implement OTP sending/verification APIs, member registration APIs, session/token issuance, eligibility verification, admin authentication/RBAC, SOS dispatch, location persistence, complaints, messaging, commerce, or wellness data. No client is connected yet.

The initial migration excludes **AuthSession** until the token/session architecture is approved. There is no optional marketing/update-consent persistence yet; that needs its own purpose and policy decision. The seed does not create **MemberConsent** rows, because fixture data must never imply that someone accepted legal terms.

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

db-migrate.ps1 uses prisma migrate deploy; it does not call migrate reset, db push, or any database deletion command. The test runner uses the test environment for configuration and never targets the development database for fixture inserts. A safe schema-only fallback URL lets Prisma formatting/client generation run without credentials; that fallback is deliberately not an authenticatable credential and is rejected by the runtime configuration.

## Stage 1 endpoints

| Method | Route                | Behavior                                                                             |
| ------ | -------------------- | ------------------------------------------------------------------------------------ |
| GET    | /api/v1/health/live  | Process liveness only; no database access                                            |
| GET    | /api/v1/health/ready | Executes a minimal SELECT 1; returns sanitized HTTP 503 if PostgreSQL is unavailable |
| GET    | /api/docs            | Development/test OpenAPI documentation                                               |

The API binds to 127.0.0.1 by default. Use HOST=0.0.0.0 only when explicitly needed for local device/emulator testing on a trusted network.

## Safeguards

- Stage 1 rejects production mode, remote database hosts, unexpected database names, mismatched app/migration roles, invalid connection strings, and a schema-generation placeholder password.
- The Prisma datasource configuration defaults only to a dummy local Sakhi target for commands such as prisma format and prisma generate; it cannot authenticate. Database-changing commands must be run through the environment wrapper.
- The seed refuses production mode, requires an explicit SAKHI_ENV, verifies the exact migration role and target database, creates only a reserved fictitious phone number and an .invalid email, and is idempotent.
- Seeded policy records are draft-only. The seed does not create consent, OTPs, sessions, or audit records.
- Request bodies are size-limited; a global whitelist/validation pipe rejects unknown properties. Structured logs redact common authentication/contact fields and never serialize request bodies or query strings. Error responses do not expose driver errors or connection details.
- No external SMS provider, storage provider, admin account, production credential, real person data, or sensitive feature storage is configured.
