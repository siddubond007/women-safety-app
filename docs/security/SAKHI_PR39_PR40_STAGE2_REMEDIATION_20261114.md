# Sakhi PR #39/#40 — Stage 2 Controlled Remediation

Date: 2026-11-14  
Workspace: `/workspaces/sakhi-pr40-recovery-20261114`  
Branch: `review/pr40-stage1b-recovery-20261114`  
Base HEAD (unchanged): `76f2350bee639911c2eb0d7449161f18a04142a9`

## Scope and safety boundary

This stage implements the six findings from the PR #39/#40 review on top of the existing November 14 recovery work. The prior Stage 1 retention SYSTEM audit RLS migration and its tests were preserved; Stage 1 was not recreated and the November 14 checkpoint was not regenerated.

No commit, push, PR update, merge, deployment, live staging database connection, or staging mutation was performed. All PostgreSQL 17 migration and database-backed tests used a disposable clone of the preserved local test cluster. The original source volume was mounted read-only for cloning and was not modified.

## Findings and remediation

### 1. Legacy complaint-evidence metadata sanitization

`backend/src/complaints/complaint-evidence-retention.worker.ts`

- Added a bounded PostgreSQL JSONB query for terminal complaints already marked `media_purged_at IS NOT NULL` that still contain legacy metadata or unpurged evidence references.
- The query selects only dirty rows, so previously sanitized rows do not consume the batch and starve later records.
- Already-purged evidence is reduced to the opaque evidence ID, purge marker, zero byte size, and fixed purge filename.
- Any remaining unpurged legacy object must have a valid evidence ID, Drive ID, SHA-256 receipt, and positive byte size; the worker verifies/deletes it through the storage provider before sanitizing its metadata.
- The update compares the original JSON evidence snapshot and purge timestamp, preventing a concurrent change from being silently overwritten.
- Metadata cleanup and its SYSTEM audit event are committed together. The worker does not repeat Drive deletion for items already marked purged.

Regression coverage:
- `backend/test/complaint-evidence-retention.worker.spec.ts`
- `backend/test/retention-deletion.database.integration.spec.ts`

The PostgreSQL integration fixture covers both already-purged legacy evidence and a remaining unpurged legacy object. It confirms only the latter is sent to Drive deletion and both records end with sanitized metadata.

### 2. Retention SYSTEM audit RLS

Preserved the existing Stage 1 migration:

`backend/prisma/migrations/20261114110000_scope_retention_system_audit/migration.sql`

It retains the OTP SYSTEM event exception and adds only the two exact retention/deletion SYSTEM event shapes, with NULL actor, transaction-local system-job context, exact action/target/outcome, correlation requirements, and redacted metadata constraints. The `PrismaService` system-job context and member/admin transaction reset are preserved in the Stage 1 work.

The existing Stage 1 negative audit test and the new Stage 2 contract assertions remain in place. The migration was applied successfully to the disposable PostgreSQL 17 clone, and the retention/deletion database integration passed.

### 3. MFA recovery migration consistency

`backend/prisma/migrations/20261109230000_admin_security_baseline_p0/migration.sql`

Expired `PENDING` and `APPROVED` recovery requests are transitioned to `EXPIRED` before the duplicate-active-request preflight and partial unique index creation. The preflight and index therefore agree on which rows are active. Still-valid duplicates continue to fail closed rather than selecting a winner.

A PostgreSQL 17 transaction test inserted two synthetic expired requests for one synthetic staff account, ran the status normalization, verified both became `EXPIRED`, and successfully recreated the partial unique index. The test transaction was rolled back.

### 4. `service_role` column-level privileges

The P0 migration now:

- Revokes table-level privileges from Supabase `service_role` as before.
- Enumerates every column on the five staff-security tables and revokes all column-level privileges.
- Checks effective table privileges for SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, and TRIGGER.
- Checks effective column privileges for SELECT, INSERT, UPDATE, and REFERENCES.

A PostgreSQL 17 negative setup granted `SELECT` on the MFA `encrypted_secret` column only to a synthetic `service_role`. The exact P0 runtime-grant block revoked it, and the effective column privilege postflight passed. All setup was rolled back.

### 5. Registration directory bio synchronization

`backend/src/auth/auth.service.ts`

The saved `MemberProfile.bio` is now carried into the registration result and the `CommunityDirectoryProfile.create` projection. The service test verifies the bio is preserved in the directory create call. The database-backed authentication flow also passed on PostgreSQL 17.

### 6. Retention RLS policy semantic verification

`backend/prisma/migrations/20261113140000_retention_deletion_runtime_grants/migration.sql`

The postflight now verifies, for all nine expected lifecycle policies:

- The policy exists and is PERMISSIVE.
- Its role set is exactly `PUBLIC`.
- Its command is the expected `ALL` or `SELECT` command.
- `USING` and `WITH CHECK` presence is appropriate to the command.
- Required account, participant, admin-role, and status predicate tokens remain present.
- PostgreSQL 17 canonicalized predicate fingerprints match the expected `USING` and `WITH CHECK` expressions exactly after whitespace normalization.
- No unexpected permissive policy applies to the lifecycle tables and broadens runtime access.

The migration passed against the PostgreSQL 17 catalog. A negative test temporarily weakened a lifecycle policy to `USING (true) WITH CHECK (true)`; the postflight rejected it, and the test transaction rolled back.

## Verification evidence

### Focused application tests

- Legacy retention worker unit tests: 10 passed after the final strict-boolean regression additions.
- P0 migration contract tests: 8 passed.
- Stage 1/Stage 2 remediation contract tests: 8 passed.
- Authentication service tests: 8 passed.

### PostgreSQL 17 database-backed tests

- Authentication database integration: 1 passed.
- Synthetic retention/deletion database integration: 1 passed, including the legacy metadata path; worker reported `examined=2`, `purged=1`, `legacyMetadataSanitized=1`.
- Staff MFA role-boundary integration: 1 passed.
- Retention/deletion runtime-grant and policy-semantic migration: applied successfully.
- Existing scoped SYSTEM audit RLS migration: applied successfully.
- P0 runtime-grant block with planted column-only service-role grant: passed.
- Expired MFA recovery normalization and partial unique-index test: passed.
- Weakened-policy negative postflight test: rejected the weakened policy as expected.

All PostgreSQL 17 fixtures were synthetic. The full staff MFA lifecycle was not run against staging; it remains a separate staging-only gate.

### Final backend validation

- Backend Vitest suite after final review correction: **261 passed, 14 skipped**; 42 test files passed, 9 skipped (51 total).
- Backend typecheck: passed.
- Prisma schema validation: passed.
- Backend production build: passed.
- `git diff --check`: passed.

The expected safe-failure log messages from existing Drive-unavailable unit tests were emitted during the full suite; the suite exited successfully.

## Source and commit accounting

No new commit was created. The exact branch HEAD remains:

`76f2350bee639911c2eb0d7449161f18a04142a9`

There are no staged changes. The Stage 2 remediation remains uncommitted and unpushed in the existing recovery workspace. PR #39 and PR #40 remote heads were not changed.

Stage 1 files remain present in the same worktree. Stage 2 source changes are in:

- `backend/prisma/migrations/20261109230000_admin_security_baseline_p0/migration.sql`
- `backend/prisma/migrations/20261113140000_retention_deletion_runtime_grants/migration.sql`
- `backend/src/auth/auth.service.ts`
- `backend/src/complaints/complaint-evidence-retention.worker.ts`
- `backend/test/admin-security-p0-migration.contract.spec.ts`
- `backend/test/authentication-service-request-otp.spec.ts`
- `backend/test/complaint-evidence-retention.worker.spec.ts`
- `backend/test/retention-deletion.database.integration.spec.ts`
- `backend/test/pr40-stage1b-remediation.contract.spec.ts`

This report records local remediation and verification only. It does not declare PR #39/#40 merged, deployed, or staging-approved.

## Final combined review correction — strict legacy purge flag handling (2026-11-14)

A final source review identified that JavaScript truthiness could incorrectly treat a malformed JSON value such as `"isPurged": "false"` as already purged. The retention worker now treats an evidence record as already purged only when `isPurged === true`; all other values follow the verified deletion path and must supply a valid evidence ID, Drive ID, SHA-256 receipt, and positive byte size. This is applied consistently to both the legacy already-marked-purged reconciliation path and the normal due-retention path.

Two regression tests cover malformed string flags in both paths. The focused worker suite passed 10/10 tests, and the full backend suite passed 261 tests with 14 integration tests skipped. Backend typecheck, Prisma validation, production build, and `git diff --check` passed. No SQL migration or database schema changed in this final correction; PostgreSQL 17 integration was therefore not rerun for this TypeScript-only boolean-handling change. The earlier PostgreSQL 17 evidence above remains evidence for the preceding database/migration remediation, not for this final unit-level correction.
