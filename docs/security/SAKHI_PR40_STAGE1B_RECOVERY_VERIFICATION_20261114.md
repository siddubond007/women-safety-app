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

The current PR #40 source already contains the MFA integration cleanup guard from commit `e735bc41f5f3fa3040c27bc317b482e970fe0d3f`: it requires the app and migrator URLs to use `127.0.0.1`, `/sakhi_test`, and the same port. That source was left intact; no cleanup operation was run against a non-local database.

## Next approved step

Proceed with Stage 1D: synchronize this recovered PR #40 head with PR #39 head `378fb40d8e547e76348349b1be24d406a462d4f7`, preserve PR #40's existing base branch `fix/staging-p0-managed-role-preflight-20261113`, run post-sync validation, and push the update to the existing PR #40 head branch. Keep PR #39 and PR #40 open. Do not merge either PR into the release branch, deploy, or modify a live database.
