# Stage 4 — Admin RBAC and member-data isolation

**Updated:** 2026-11-19  
**Working branch:** `security/stage4a-remediation-stage4b-rls-20261119`  
**Supabase project:** `sakhi-friend-testing` (`wmlpokholjfadyohdlgo`, ap-south-1)

## Stage 4A — Admin RBAC remediation

Implemented on the Stage 4 branch:

1. **Role-transition permission reset.** A real role change starts from the destination role's default permission set before explicit validated overrides are applied. Privileges from the previous role cannot leak into the new role.
2. **Same-role updates preserve custom permissions.** Re-submitting the current role with a partial permission patch does not erase unrelated custom permissions.
3. **Complaint-reviewer hydration fails closed.** Persisted reviewer clearance set on a role other than `SUPER_ADMIN` or `COMPLAINT_REVIEWER` is rejected during database hydration.
4. **Self privilege modification is blocked.** A staff member cannot change their own role, status, permissions or security clearance through the staff update route.
5. **Super Admin promotion/creation is guarded.** The existing service denies a direct create/promotion to `SUPER_ADMIN`; the system does not silently bypass its independent-approval boundary.
6. **Explicit database role/status.** Prisma no longer defines implicit defaults for `AdminStaffAccount.role` or `status`. Database constraints allow only the seven recognized roles and three recognized statuses, and enforce reviewer-clearance role consistency.

Regression tests cover Super Admin demotion to each lower role with partial overrides, same-role permission preservation, malformed permission values, invalid persisted reviewer clearance and self-modification denial.

## Stage 4B — Member-data isolation and RLS

The existing Stage 3D/Stage 5 policy set was retained and audited rather than duplicated.

- 50 protected member, complaint, audit and admin tables have RLS enabled and forced.
- The 10 public-schema tables without RLS are platform/configuration or Prisma migration metadata tables; the Supabase Data API roles have no SELECT grant on them.
- The dedicated `sakhi_staging_app` runtime role remains non-superuser and `NOBYPASSRLS`.
- Supabase `service_role` is `BYPASSRLS`; it must therefore have no direct table or column grants on protected Sakhi data.
- The Stage 4B migration revokes table-level and column-level privileges from `PUBLIC`, `anon`, `authenticated` and `service_role` across the 50 protected tables, while preserving the required `sakhi_staging_app` grants.
- Default privileges for future public-schema objects created by `postgres` and `sakhi_staging_migrator` are revoked for Data API roles and PUBLIC function execution.

### Platform-managed default privilege limitation

The Supabase-managed `supabase_admin` role still has its own default ACL entries for future public-schema tables, sequences and functions. The restricted `postgres` database principal cannot `SET ROLE` to that superuser, and the available Supabase migration execution path rejected an attempt to alter those defaults. Existing protected tables are still verified to have no Data API table/column grants. **Sakhi application objects must be created by `sakhi_staging_migrator` or `postgres`, not by `supabase_admin`.** Removing the platform role's defaults requires an owner-level Supabase administrative path not available through the current connection.

## Staging database application and verification

The three Stage 4A/4B DDL migrations were applied atomically to the active `sakhi-friend-testing` staging project using the reviewed owner split. The pending predecessor `20261118130000_remove_legacy_admin_mfa_flag` was also audited: its target legacy column is already absent, and the authoritative `admin_staff_mfa.enrollment_verified_at` and `disabled_at` columns are present. Its intended postcondition is therefore already satisfied; the four-migration target will record this no-op cleanup migration together with the three Stage 4 migrations.

- 40 protected tables owned by `sakhi_staging_migrator`
- 10 protected tables owned by `postgres`
- `20261118130000_remove_legacy_admin_mfa_flag` (postcondition already satisfied; legacy flag column absent)
- `20261119140000_admin_staff_role_constraints`
- `20261119150000_secure_admin_bootstrap_function_search_path`
- `20261119160000_revoke_data_api_roles_from_member_data`

Post-application checks confirmed:

- `role` and `status` database defaults are NULL (no implicit privilege-bearing values).
- All three Stage 4A constraints exist and are validated.
- The existing staff inventory remains one active `SUPER_ADMIN` account with valid reviewer clearance; no staff/member rows were changed.
- `guard_admin_bootstrap_credential_consumption()` has `search_path=pg_catalog`.
- No table-level or column-level grants remain for `anon`, `authenticated` or `service_role` across the 50 protected tables.
- Required `sakhi_staging_app` access remains intact.
- Default ACLs for `postgres` and `sakhi_staging_migrator` no longer grant public-schema object access to Data API roles or PUBLIC.
- 50 tables remain FORCE RLS.

The migration SQL was first dry-run in one transaction and rolled back; the committed run then passed the same postflight. No application data was modified.

### Prisma migration history reconciliation

The DDL is committed in staging. At the time of this update, the Prisma `_prisma_migrations` table still has 38 previously applied migrations and does not yet record the four-migration Stage 4 target. The first reconciliation preflight correctly stopped because `20261118130000_remove_legacy_admin_mfa_flag` was an additional pending predecessor. The exact reviewed target, Prisma gate, migration runners, workflow environment and tests were expanded to include it. One workflow attempt still carried the old three-migration environment value and was rejected by preflight without changing the ledger. After correcting the target, the next run reached postflight but the restricted migrator could not see columns on the postgres-owned `admin_staff_mfa` table through `information_schema`. The migration and both runners now inspect those columns through `pg_catalog.pg_attribute`, without broadening grants. A read-only postcondition query executed as `sakhi_staging_migrator` now confirms all Stage 4 checks are true. A new marker push will rerun ledger reconciliation. It does not execute DDL; it first verifies the live database postconditions, then runs `prisma migrate resolve --applied` with the dedicated migrator connection. It triggers only on a commit whose message contains `[STAGE4_LEDGER_RESOLVE]`.

## CI and release status

- The isolated PostgreSQL 17 integration script now models the real owner split, creates a `service_role BYPASSRLS` principal, applies the Stage 4 migrations, and runs the Stage 5 member-isolation integration suite.
- Stage 4 migration and workflow contract tests include syntax checks for the Node and shell runners.
- GitHub Actions validation for the current branch was still running at the time of this update; final pass/fail evidence must be read from the latest commit's checks.
- PR #55 remains a draft against `release/staging-apk-hosted-20261112`; it includes the Stage 3C dependency and Stage 4 work. It has not been merged.
- No application deployment was triggered. Render's staging API service remains on its existing release-branch deployment; this work changed staging database security only.

## Remaining Stage 4 closure items

1. Confirm the current branch's backend, Super Admin, Flutter and isolated PostgreSQL 17 checks are green.
2. Confirm the Stage 4 Prisma ledger reconciliation workflow completes and all three migration rows are recorded.
3. Keep the `supabase_admin` default ACL limitation visible as a platform-owner follow-up; do not create Sakhi application tables under that role.
4. Re-review PR #55 after CI evidence is complete. Do not merge or deploy as part of this migration task.
