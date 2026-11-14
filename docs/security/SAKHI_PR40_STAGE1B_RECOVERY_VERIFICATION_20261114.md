# Sakhi PR #40 — Stage 1B Recovery and Stage 1C Verification

Date: 2026-11-14
Recovery branch: `review/pr40-stage1b-recovery-20261114`
Starting PR #40 head: `93cf43ff4d5bd291af58aaba50db8d1a88fccdd8`

## Recovery provenance

The original local-only Stage 1B and Stage 1C commits (`f2023255bdd3e4b429155e93ada2f63890c904ff` and `b71a233532aaee488732280ba5e58ef98d1ada2f`) and the original `/workspaces/sakhi-pr40-remediation` worktree were not present in the friend-owned Codespace. They were not represented by remote refs. This branch therefore reconstructs the six recorded Stage 1B review remediations from the PR #40 source and the retained review findings; it does not claim to restore the original commit objects or reproduce their original hashes.

The separate worktree was created from the existing PR #40 remote head. Existing Sakhi worktrees, branches, untracked archives, and other local changes were not modified.

## Six Stage 1B findings addressed

1. **Unsafe broad synthetic cleanup:** removed wildcard complaint cleanup and display-name-based member deletion from the lifecycle integration setup. Cleanup is limited to the current test's generated IDs, and the migrator URL must match the app URL's loopback host, database path, and port.
2. **Incomplete RLS postflight:** the retention/deletion migration now verifies enabled and forced RLS on all eight affected lifecycle tables and checks the expected policies (including both business-directory policies).
3. **Migration atomicity:** the scoped audit-policy and retention/deletion-grants migrations now use explicit `BEGIN`/`COMMIT` boundaries.
4. **Evidence metadata not scrubbed:** purged complaint evidence records retain only the opaque evidence ID, purge marker, zero byte size, and purge label. Drive IDs, SHA-256 digests, original filenames, and arbitrary metadata are removed.
5. **Audit actor shape/validation:** the admin policy branch requires `actor_type='ADMIN'` and `actor_id` to match the transaction-local staff ID. The OTP system branch requires `actor_type='SYSTEM'`, `actor_id IS NULL`, the exact OTP action/target shape, matching request/target IDs, and the auth-lookup context. OTP audit writes explicitly persist a null actor ID.
6. **Directory bio regression:** public discovery regression coverage now asserts that the directory bio remains in the response. The existing directory projection/search/profile code already carries the bio; this recovery adds a test to prevent it regressing.

## Verification performed in this recovery worktree

- Backend TypeScript typecheck: passed.
- Prisma schema validation: passed.
- Backend build: passed.
- Full Vitest suite: 247 passed, 13 skipped (49 files; 41 passed and 8 integration files skipped).
- Focused Stage 1B regression suite: 15 passed; the database lifecycle integration test remained skipped because the unit-test invocation did not enable the DB integration environment.
- Isolated PostgreSQL 17.11: all 33 migration files applied successfully. Postflight query confirmed all eight lifecycle tables had RLS enabled and forced, with the expected policies present. The resulting audit policy expression was inspected and confirmed to include the matching ADMIN identity and NULL SYSTEM actor constraints.
- No live Supabase/staging database was accessed, no live Google Drive object was created/deleted, and no deployment or PR merge was performed.

## Prior Stage 1C evidence retained from the original work session

The prior Stage 1C run was recorded as PostgreSQL 17.12 with 33/33 migrations applied, 2/2 rollback tests passed, and 8/8 forced-RLS checks passed. The original Stage 1C commit object is unavailable in this Codespace, so that historical evidence is distinguished from the fresh PostgreSQL 17.11 migration run above.

## MFA cleanup safeguard

The current recovery source intentionally gates the full staff MFA lifecycle integration behind `SAKHI_STAGING_MFA_DB_INTEGRATION=true`, `SAKHI_ENV=staging`, and `NODE_ENV=production`. It validates both application and migrator URLs against the staging target and requires the runtime principal to be `sakhi_staging_app`. This is a staging-only verification gate; it was not executed against live staging during this local remediation.

## Stage 1D synchronization and post-sync validation

- Merged PR #39 head `378fb40d8e547e76348349b1be24d406a462d4f7` into the recovery branch using merge commit `0328dd5`.
- PR #40's existing base branch remains `fix/staging-p0-managed-role-preflight-20261113`; its head now contains the PR #39 head as an ancestor.
- Post-sync graph comparison: 0 commits behind and 10 commits ahead of the PR #39 base.
- Post-sync backend typecheck, Prisma validation, full Vitest suite, and backend build all passed.
- Post-sync full Vitest suite: 253 passed, 13 skipped (50 files; 42 passed and 8 integration files skipped).
- Fresh isolated PostgreSQL 17.11 verification after synchronization applied all 33 migrations; all eight lifecycle tables had forced RLS; valid SYSTEM/ADMIN audit actor shapes were accepted, while non-null SYSTEM actor IDs and mismatched ADMIN actor IDs were rejected by RLS.

Any push to the existing PR #40 head branch `fix/sakhi-runtime-db-isolation-20261113` requires separate, explicit authorization after final combined review. Keep PR #39 and PR #40 open. Do not merge either PR into the release branch, deploy, or modify a live database without separate authorization.

## Stage 1E retention audit follow-up (2026-11-14)

The follow-up remediation and evidence are recorded in [SAKHI_PR40_STAGE1_RETENTION_REMEDIATION_20261114.md](./SAKHI_PR40_STAGE1_RETENTION_REMEDIATION_20261114.md). It adds one narrowly scoped audit-policy migration and verifies it on the cloned disposable PostgreSQL 17.11 database: 34/34 migrations applied, 49 tables with forced RLS, retention/deletion DB integration 1/1 passed, authentication DB integration 1/1 passed, and the staff-MFA staging-role boundary 1/1 passed. The full staff MFA lifecycle remains an explicit staging-only verification gate.

This follow-up remains uncommitted and unpushed on the recovery branch. It did not modify PR #39/#40 remote refs, staging, or the release branch.
