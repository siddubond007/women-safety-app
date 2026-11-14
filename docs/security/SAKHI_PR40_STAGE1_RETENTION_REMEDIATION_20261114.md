# Sakhi PR #40 — Stage 1 Retention Audit RLS Remediation

Date: 2026-11-14
Recovery branch: `review/pr40-stage1b-recovery-20261114`
PR #40 source baseline before this remediation: `76f2350bee639911c2eb0d7449161f18a04142a9`
Scope: local disposable PostgreSQL 17.11 only; no staging database, deployment, PR merge, or push.

## Authorization and environment safety

The user explicitly authorized a narrowly scoped retention audit-policy remediation in the existing recovery branch, with the requirements that RLS must not be weakened, staging privileges must not change, and there must be no merge or deployment.

The pre-existing anonymous PostgreSQL volume was preserved. A separate disposable volume and container were created from a copy. The previous database was retained as `sakhi_test_legacy_20261114`; a separate `sakhi_test` database was used for this work. The 33 existing migrations were applied to that clone as schema setup, followed by only the new additive migration described below. No live Supabase/staging connection was used.

## Root cause

The existing audit INSERT policy allowed:
- Member audit events matching the transaction-local member account ID.
- Admin audit events matching the transaction-local staff ID and role.
- One narrowly scoped SYSTEM OTP-request event.

The retention worker also emits two SYSTEM events:
- `module2.account.deletion_completed` targeting `account_deletion_request`.
- `module5.complaint.evidence.retention_purged` targeting an anonymized Module 5 complaint reference.

Those two worker events were rejected by the policy. The deletion worker correctly left a failed request queued instead of falsely reporting completion.

## Remediation

Added migration `20261114110000_scope_retention_system_audit`.

The existing OTP branch is retained. Two additional SYSTEM event shapes are allowed only when all of the following match:
- `actor_type='SYSTEM'` and `actor_id IS NULL`.
- The transaction-local `app.system_job` context is true.
- Exact action and target type.
- Exact expected outcome.
- Required redacted metadata flags and non-negative integer counts.
- Account deletion additionally requires `request_id=target_id`.
- Complaint retention requires an anonymized `#SKH-ANON-` target and a UUID correlation ID.

`PrismaService.withSystemAdminIdentity()` now sets `app.system_job=true` transaction-locally. Normal request and member-identity transactions explicitly set it to false. No database role, staff-security grant, or RLS bypass was added.

The account-deletion worker now uses its deletion-request ID as the audit correlation ID, allowing the policy to enforce `request_id=target_id`.

## MFA boundary

The P0 migration intentionally limits the five staff-security RLS policies to `sakhi_staging_app`. The local `sakhi_test_app` role has no matching policies. This boundary was preserved.

The full staff MFA lifecycle integration is now gated by the explicit `SAKHI_STAGING_MFA_DB_INTEGRATION=true` opt-in and requires:
- `SAKHI_ENV=staging`.
- `NODE_ENV=production`.
- Both app and migrator URLs to pass the repository's exact staging Supabase target validation.
- Matching staging host, database path, and port.
- The application connection principal to be `sakhi_staging_app`.

The full staff enrollment/TOTP/replay/recovery/session-revocation lifecycle was not run against staging in this remediation. It remains a separate staging verification gate; no staging staff account was created or changed.

A local PostgreSQL role-boundary integration test verifies all five staff-security tables have RLS enabled and forced, the policy list contains `sakhi_staging_app`, and does not contain `sakhi_test_app`.

## Verification

- Additive migration: applied successfully; database reports 34/34 migrations applied.
- Prisma migration status: schema up to date.
- Eight retention/deletion lifecycle tables: all eight still have RLS enabled and forced.
- Full forced-RLS table inventory: 49 tables.
- Authentication database integration: 1 passed after the Prisma transaction-context change.
- Retention/deletion database integration: 1 passed. Synthetic account deletion, member-media purge, complaint evidence purge, and both scoped audit events completed.
- Negative RLS assertion: an unrelated SYSTEM audit event was rejected inside the system-job transaction.
- Staff MFA role-boundary database integration: 1 passed across all five staff-security tables; all five policies are staging-role-only.
- Targeted unit/contract tests: 18 passed.
- Backend typecheck: passed.
- Prisma schema validation: passed.
- Backend build: passed.
- Full backend Vitest suite: 255 passed, 14 skipped (51 files; 42 passed, 9 skipped).
- Full staff MFA lifecycle integration: intentionally not run locally; staging-only gate documented above.

## Safety and remaining gate

- No staging/production database was accessed.
- No staging staff fixtures or credentials were created.
- No Google Drive object was created or deleted; the retention integration uses a mocked provider.
- No migration was applied to Supabase.
- No PR was pushed, merged, or deployed.
- No source changes have been committed yet.

Stage 1's local PostgreSQL and retention/deletion gaps are closed. The separate full staff MFA lifecycle remains a staging gate for the later staging MFA stage.
