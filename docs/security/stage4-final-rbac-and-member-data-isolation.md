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

### Prisma migration history reconciliation — complete

The four reviewed migrations are recorded in live staging. The DDL postconditions were already present before the successful ledger-recovery run; the recovery workflow verified them and reconciled Prisma history rather than reapplying DDL.

- Recovery run [44501359948](https://github.com/siddubond007/women-safety-app/actions/runs/44501359948) succeeded and reported **42 migrations found; database schema is up to date**.
- The latest catalog-based verifier [44501563438](https://github.com/siddubond007/women-safety-app/actions/runs/44501563438) also succeeded.
- The first recovery attempt failed closed before changing the ledger. The resolver was corrected to inspect metadata through `pg_catalog`; the later run completed successfully.
- All four migration rows have `finished_at` set and no rollback marker:
  1. `20261118130000_remove_legacy_admin_mfa_flag`
  2. `20261119140000_admin_staff_role_constraints`
  3. `20261119150000_secure_admin_bootstrap_function_search_path`
  4. `20261119160000_revoke_data_api_roles_from_member_data`

### Live staging postflight — passed

Read-only checks against the active staging project confirmed:

- All 50 protected tables have RLS enabled, FORCE RLS enabled and at least one policy.
- No table- or column-level Data API privileges remain for `PUBLIC`, `anon`, `authenticated` or `service_role` across the 50 protected tables.
- The 10 public-schema non-RLS configuration/reference/metadata tables also have no Data API table- or column-level grants.
- Protected-table ownership is split as reviewed: 40 tables owned by `sakhi_staging_migrator`, 10 by `postgres`.
- Default ACLs for `postgres` and `sakhi_staging_migrator` have no matching Data API grants.
- `sakhi_staging_app` is non-superuser and NOBYPASSRLS, retains required access, and is not a member of the migrator or PostgreSQL roles.
- The legacy `mfa_enabled` column is absent; role/status defaults are removed; all three role/reviewer constraints are validated; the bootstrap trigger function has `search_path=pg_catalog`.
- One active Super Admin remains; there are no invalid role/status/reviewer-clearance rows; the existing MFA record and ten recovery-code records remain.

Supabase Security Advisor and Health Advisor report no lints. Performance Advisor still reports 8 unindexed foreign keys, 59 RLS init-plan findings and 112 multiple-permissive-policy findings across 11 tables. The reviewed policies are scoped to ownership, visibility, verified membership, admin identity, or transaction-local username/notification contexts; no blanket `USING (true)` policy was found. These are recorded as performance/policy-maintenance follow-ups, not as proof of an authorization bypass.

The Supabase-managed `supabase_admin` role still has platform default ACL entries for future public-schema objects. Existing application tables are verified safe. New Sakhi application objects must be created by `sakhi_staging_migrator` or `postgres`, never `supabase_admin`; removing the platform role's defaults requires an owner-level Supabase path unavailable to the restricted connection.

### CI and release status

- PR #54, the Stage 3C workflow parent, is merged.
- PR #55, Stage 4A/4B, is squash-merged into `release/staging-apk-hosted-20261112` at `6d773e3eeb0b5d7a190584e8c4b2dfa6ebb38f24`.
- Checkpoint branch `checkpoint/stage4-final-20261119` has the same Git tree as the merged release commit.
- Full validation [44502098730](https://github.com/siddubond007/women-safety-app/actions/runs/44502098730) completed successfully: backend 344 passed / 19 skipped; isolated PostgreSQL 17 Stage 5 RLS tests 5/5; MFA role-boundary test 1/1; Super Admin type-check/lint/build; Flutter analysis/tests and staging-connected debug APK build all passed.
- The Stage 3C live staging MFA lifecycle run [44485650279](https://github.com/siddubond007/women-safety-app/actions/runs/44485650279) passed.
- Release-branch validation [44502823639](https://github.com/siddubond007/women-safety-app/actions/runs/44502823639) and the Modules 8–9 staging APK workflow [44502823569](https://github.com/siddubond007/women-safety-app/actions/runs/44502823569) were still running at the time of this update.

### Remaining release gates

1. Confirm the two post-merge release workflows finish successfully.
2. Verify the Render staging API/admin deployment and run authenticated smoke tests against the merged release. This is separate from the completed database security work.
3. Keep the `supabase_admin` default-ACL limitation and Performance Advisor findings visible as follow-ups.
4. Super Admin creation/promotion remains intentionally blocked until a true independent two-person approval workflow is implemented.

No production database or production deployment was changed.
