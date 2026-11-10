# Sakhi Stage 3C — Member Identity and Transaction Context Acceptance

Date: 2026-11-10

## Scope completed

Stage 3C establishes the trusted member identity contract and the transaction-local PostgreSQL identity foundation, then proves adoption in one sensitive member-owned read path.

### Implemented

1. `backend/src/auth/member-identity.ts`
   - Defines an immutable `AuthenticatedMemberIdentity` containing the canonical member account UUID and persisted session UUID.
   - Validates UUID shape and normalizes UUID casing.
2. `AuthenticationService.authenticateMemberIdentity()`
   - Calls the existing persisted-session authentication path.
   - Derives account and session identity only from the validated session record; caller-supplied account IDs are not accepted.
3. `PrismaService.withMemberIdentity()`
   - Starts a Prisma interactive transaction.
   - Sets `app.account_id` using `set_config(..., true)` inside that transaction.
   - Runs the supplied callback using the same transaction client.
   - Rejects malformed identity before opening the transaction.
4. `Module2Service.getMenstrualCycleTracker()`
   - Resolves identity from the validated Bearer session.
   - Reads cycle logs, daily logs, and tracker preferences through one identity-scoped transaction client.
   - Retains explicit `accountId` predicates as defense in depth.
5. Focused tests cover identity immutability/validation, trusted session-derived identity, transaction context setup, malformed identity rejection, and service adoption.

## Verification

- Prisma Client generation: passed.
- TypeScript `tsc --noEmit -p tsconfig.json`: passed.
- Focused Stage 3C tests: 4 files, 8 tests passed.
- Related Module 2 / Module 3 regression suite: 11 files passed, 65 tests passed; 2 files / 3 tests skipped because their DB integration prerequisites were not enabled.
- `git diff --check`: passed at final review (see worktree status).

## Explicit limitations — not a database isolation acceptance

- No RLS policy or migration was added in Stage 3C.
- No runtime role grants, FORCE ROW LEVEL SECURITY settings, or database ownership changes were made.
- No live PostgreSQL test proved that one member cannot read another member's rows.
- Only the menstrual tracker read operation has been migrated to `withMemberIdentity`; other member-owned service operations remain to be migrated in later work.
- Existing menstrual tracker write, delete, recalculation, and export paths were not migrated as part of this stage.
- The service-level and transaction tests use mocks; they verify application wiring, not PostgreSQL enforcement.

Therefore Stage 3C is accepted as the identity/transaction-context foundation only. Sakhi must not be described as having complete member-level RLS isolation or production-ready cross-account database protection.

## Change isolation

- Worktree: `/workspaces/sakhi-stage3c-member-identity-20261110`
- Branch: `feat/stage3c-member-identity-context-20261110`
- Base commit: `81f9d69925c4051c26f015886bf176fc1dca3fb1`
- No commit, merge, migration, staging/production database operation, Render deployment, or `main` update was performed.
