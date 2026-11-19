# Sakhi Stage 4 — RBAC Remediation and Member-Data Isolation Readiness

**Audit date:** 2026-11-19  
**Implementation branch:** `security/stage4a-remediation-stage4b-rls-20261119`  
**Base checkpoint:** `checkpoint/remote-stage3c-mfa-pr54-20261119`  
**Scope:** Stage 4A staff RBAC and Stage 4B member-data isolation/RLS.  
**Deployment status:** Source changes are committed to the isolated branch. The new Prisma migrations have not been applied to staging or production.

## Executive status

Stage 4A code remediations and Stage 4B RLS least-privilege hardening have been prepared on a dedicated branch. The current Supabase project `sakhi-friend-testing` (PostgreSQL 17.11.0.003, project ref `wmlpokholjfadyohdlgo`) already has the Stage 3D and Stage 5 member-data RLS migrations applied.

Live read-only inspection on 2026-11-19 found:

- 60 tables in the `public` schema.
- 50 tables have RLS enabled and forced.
- 10 remaining RLS-disabled tables are global configuration/reference tables or `_prisma_migrations`; the inspected tables had no SELECT grant for `anon`, `authenticated`, or `service_role`.
- The dedicated `sakhi_staging_app` role is not SUPERUSER and does not have BYPASSRLS.
- The built-in Supabase `service_role` does have BYPASSRLS. It still had SELECT grants on nine protected tables: `account_deletion_requests`, `admin_auth_sessions`, `community_circle_memberships`, `community_circle_posts`, `member_push_tokens`, `member_wellness_preferences`, `menstrual_cycle_logs`, `menstrual_daily_logs`, and `menstrual_tracker_preferences`. This is a real least-privilege gap: RLS cannot constrain a role that bypasses RLS.
- A new migration revokes all table privileges from `PUBLIC`, `anon`, `authenticated`, and `service_role` on all 50 protected member/admin tables, while retaining the dedicated backend role's required access. Its postflight fails if any prohibited grant remains.
- The security advisor also reported one mutable-search-path warning for the bootstrap credential trigger function. A new migration pins that function to `search_path = pg_catalog`.

The new migrations are deliberately not marked applied here. They must be deployed through the repository's reviewed Prisma migration pipeline so the database migration history and checked-in migration files remain aligned.

## Stage 4A — Admin RBAC

### Implemented in this branch

1. **Role-change permission reset**
   - Every actual role change starts from the destination role's default permissions and allowed routes.
   - Only explicit, validated boolean overrides are then applied.
   - Previous-role grants cannot leak into the new role through partial permission updates.

2. **Complaint-reviewer clearance hydration**
   - A persisted row that marks a non-`SUPER_ADMIN` / non-`COMPLAINT_REVIEWER` as an authorized complaint reviewer is rejected during hydration.
   - Hydration no longer trusts a contradictory persisted boolean as an alternate reviewer authorization path.

3. **Self-service privilege changes**
   - A staff member cannot change their own role, status, granular permissions, complaint-reviewer clearance or security clearance through the staff-update endpoint.
   - Another Super Admin must perform those changes.

4. **Super Admin promotion governance**
   - Single-actor creation or promotion to `SUPER_ADMIN` is blocked until an independent two-person approval workflow exists.
   - Existing Super Admin accounts can continue to manage lower-privilege staff.
   - This is a fail-closed interim governance control; it intentionally means additional Super Admin provisioning is unavailable until the separate approval workflow is implemented.

5. **Database role constraints**
   - Prisma no longer supplies implicit defaults for `AdminStaffAccount.role` or `status`.
   - The migration preflights existing rows and adds allow-list constraints for the seven roles, three statuses and reviewer-clearance/role pairing.
   - Live staging preflight on 2026-11-19 found one active `SUPER_ADMIN` row and no invalid role/status/clearance rows.

### Tests added

- Role transitions from `SUPER_ADMIN` to every lower-privilege role with partial overrides.
- Invalid persisted complaint-reviewer clearance.
- Valid reviewer clearance for an eligible role.
- Malformed permission override rejection before persistence.
- Self-modification denial.
- Single-actor Super Admin create/promotion denial.
- Migration contract tests for role/status defaults and constraints.

## Stage 4B — Member-data isolation / RLS

### Existing foundation verified

The following migrations are present in source and were listed as applied in the live Supabase migration history:

- `20261110170000_stage3d_member_level_menstrual_rls`
- `20261111190000_member_owned_data_rls`
- `20261111200000_public_directory_profile_rls`
- `20261111210000_member_block_target_visibility`
- `20261111220000_member_auxiliary_rls`
- `20261111230000_confidential_backend_only_rls`

The existing design uses transaction-local PostgreSQL settings such as `app.account_id`, `app.session_id`, `app.admin_staff_id`, and `app.admin_role`. `PrismaService` wraps authenticated delegate operations in transactions and sets these values locally, so connection-pool reuse does not leave member identity attached to the next request.

The source includes:
- Stage 3D PostgreSQL isolation contract tests.
- Stage 5 PostgreSQL member-data RLS tests.
- AsyncLocalStorage request identity isolation tests.
- Prisma transaction-local identity tests.
- Migration preflight/postflight checks for table existence, UUID ownership columns, runtime-role attributes, table ownership and forced RLS.

### New Stage 4B hardening

The new migration `20261119160000_revoke_data_api_roles_from_member_data`:

- Revokes all privileges from PostgreSQL `PUBLIC`.
- Revokes all table privileges from `anon`, `authenticated`, and `service_role` for the 50 protected member/admin tables.
- Preserves the separate `sakhi_staging_app` backend grant contract.
- Verifies that the prohibited roles have no SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES or TRIGGER table privileges.
- Verifies that the dedicated backend role retains essential access to member accounts, member profiles and admin staff accounts.

This is required because Supabase `service_role` has BYPASSRLS; policy predicates alone cannot protect rows from that role.

### Public configuration tables

Ten tables currently have RLS disabled. The live grant inspection found no SELECT privilege for `anon`, `authenticated`, or `service_role` on these tables. They are global reference/configuration data, not member-owned records. Their backend-only access remains controlled by the dedicated application DB role and backend service authorization. `_prisma_migrations` has no grants to the application or Data API roles.

### Known advisory items

- The Supabase security advisor currently reports one mutable-search-path warning for `public.guard_admin_bootstrap_credential_consumption()`. The new search-path migration addresses it, pending deployment.
- Performance advisors report repeated `current_setting()` RLS init-plan warnings, eight unindexed foreign keys and multiple permissive policies on a small number of tables. The multiple-policy cases are intentional additive paths for directory username availability, recipient notification delivery and incoming-block visibility; they require ongoing policy review because PostgreSQL combines permissive policies with OR semantics.
- The RLS integration tests are present but require explicit database connection variables. The current generic validation workflow does not automatically run the live Stage 5 RLS integration suite. Do not expose staging DB secrets to arbitrary pull-request code.

## Live staging verification

Read-only checks performed against project `sakhi-friend-testing`:

- PostgreSQL: 17.11.0.003.
- Applied migration history includes the Stage 3D/Stage 5 RLS sequence and the Stage 3C legacy MFA-flag removal migration.
- 50 public tables have both `relrowsecurity` and `relforcerowsecurity`.
- `sakhi_staging_app`, `sakhi_staging_migrator`, and `sakhi_staging_fixture_cleanup` are non-superuser roles without BYPASSRLS, CREATEDB, CREATEROLE or REPLICATION.
- `service_role` is a Supabase-managed BYPASSRLS role; least-privilege table grants are therefore separately required.
- One active Super Admin exists; no invalid staff role/status/reviewer-clearance rows were found.
- No Edge Functions are deployed in this project.

The Supabase SQL connector could not assume `sakhi_staging_app` because its own connection is not allowed to SET ROLE or SET SESSION AUTHORIZATION to that role. This is a tooling privilege boundary, not evidence of an RLS failure. The repository's dedicated PostgreSQL integration tests remain the authoritative role-switched verification path.

## Pending verification and release gates

1. Run Prisma schema validation, TypeScript typecheck, full backend unit suite, backend build, Super Admin build/lint, and Flutter analyze/tests through GitHub Actions.
2. Run the new Stage 4A migration on isolated PostgreSQL 17 and verify the role-change regression tests.
3. Run Stage 5 RLS integration using a protected, explicitly scoped staging test environment; do not pass staging secrets to untrusted pull-request code.
4. Apply the three new Prisma migrations only through the reviewed staging migration pipeline, then confirm Prisma migration history and Supabase security advisors.
5. Confirm all nine previously identified `service_role` grants are removed and the dedicated backend role retains its required access.
6. Re-run RLS cross-account tests, including no-identity denial, own-account visibility, foreign-account invisibility, update/delete isolation, directory privacy and audit-read restrictions.

## Explicitly not done

- No PR was merged.
- No Render deployment was triggered.
- No staging or production migration was applied from this branch.
- No member, admin, complaint, session or MFA data was changed.
- No Codespace/local filesystem recovery is claimed.
