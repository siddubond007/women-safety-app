# Sakhi Stage 3D — Core Private Menstrual Data RLS Acceptance

Date: 2026-11-10
Branch: `feat/stage3d-core-private-rls-20261110`
Base commit: `81f9d69925c4051c26f015886bf176fc1dca3fb1`

## 1. Accepted scope

Stage 3D implements PostgreSQL member-level row isolation for the Sakhi menstrual-tracker private-data domain:

- `menstrual_cycle_logs`
- `menstrual_daily_logs`
- `menstrual_tracker_preferences`

This is a deliberately bounded domain slice. It does not claim that every Sakhi member-owned table has RLS. Member notifications, profiles, sessions, consent, safety records, direct messages, media, business enquiries, complaints, and other ownership domains require their own access-path and policy stages.

## 2. Implementation

- Added migration `20261110170000_stage3d_member_level_menstrual_rls`.
- Migration preflights table existence and UUID `account_id` columns.
- Removed the three previous role-only runtime policies.
- Enabled and forced RLS on all three protected tables.
- Added `USING` and `WITH CHECK` predicates that require both an allowed runtime role and `account_id = NULLIF(current_setting('app.account_id', true), '')::uuid`.
- Missing transaction identity returns no matching rows and rejects cross-account writes.
- Migration rejects configured runtime roles with `SUPERUSER`/`BYPASSRLS` and rejects protected tables owned by runtime roles.
- Runtime grants remain least-privilege table grants already provisioned by the earlier migration; RLS constrains visible/mutable rows.

## 3. Service-path conversion

All menstrual-tracker database operations in `Module2Service` now use `PrismaService.withMemberIdentity()`:

- Read tracker cycles, daily logs and preferences.
- Create/update cycle logs.
- Recalculate cycle history using the same transaction client.
- Delete cycle logs and recalculate history in the same transaction.
- Upsert and delete daily logs.
- Upsert tracker preferences.
- Delete all three categories of member tracker data in one identity-scoped transaction.
- Notification inbox reads of menstrual tracker preferences use an identity-scoped transaction.
- Export obtains its private data through the scoped tracker read path.

The canonical identity is derived from the existing persisted-session authentication path. The account identifier supplied by request payloads is not used to establish the RLS context. Explicit account predicates remain as defense in depth.

## 4. Real PostgreSQL verification

A disposable PostgreSQL 17 instance inside the Codespace was used. A fresh `sakhi_test` database was created with a separate non-superuser migration role and non-superuser runtime role. The full repository migration chain was applied:

- 23 migrations found.
- All 23 migrations applied successfully, including Stage 3D.
- `prisma migrate status`: database schema is up to date.
- Runtime role verification: `rolsuper = false`, `rolbypassrls = false`.
- Protected table ownership: `sakhi_test_migrator`, not the runtime role.
- All three protected tables report `relrowsecurity = true` and `relforcerowsecurity = true`.

The Stage 3D integration test ran against the actual migrated `sakhi_test` tables as `sakhi_test_app` and passed. For each of the three tables it verified:

- Member A can read A's rows.
- Member A cannot read B's rows.
- Member A cannot insert a row owned by B (PostgreSQL SQLSTATE `42501`).
- Member A cannot update or delete B's rows.
- Missing transaction-local identity returns zero visible rows.
- A subsequent transaction can set Member B's identity and see only B's rows, confirming transaction-local identity does not persist across transactions.

## 5. Build and test verification

- `npx prisma validate`: passed.
- `npx tsc --noEmit -p tsconfig.json`: passed.
- `node scripts/build.mjs`: passed.
- Focused Stage 3C + Stage 3D + Module 2 tests: 7 files, 24 tests passed.
- Full backend Vitest suite: 31 files passed, 176 tests passed, 4 files / 6 tests skipped by the repository's existing optional integration-test gating.
- Stage 3D real PostgreSQL integration test was separately enabled and passed against the migrated test database; it is skipped by default in the full suite unless `SAKHI_STAGE3D_RLS_TEST_URL` is provided.
- `git diff --check`: passed after final formatting.

## 6. Security assumptions and limitations

- The transaction-local `app.account_id` setting is trusted application context. The app role must not expose arbitrary SQL execution to untrusted callers; a party able to execute arbitrary SQL as the runtime role can set custom PostgreSQL GUCs. RLS is defense in depth around authenticated service paths, not a substitute for preventing SQL injection or arbitrary query execution.
- This migration does not change Supabase/Render, staging, production, secrets, or hosted role grants.
- No production/staging migration, deployment, merge to `main`, or APK release was performed.
- This stage proves the three menstrual-tracker tables only. It is not a claim of complete RLS coverage across the Sakhi database.

## 7. Final disposition

**Stage 3D accepted for the bounded menstrual-tracker private-data scope above.**

All implementation changes remain isolated and uncommitted on `feat/stage3d-core-private-rls-20261110`. The original Stage 3C worktree and `origin/main` remain unchanged.
