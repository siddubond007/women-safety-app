#!/usr/bin/env bash
set -euo pipefail

# PostgreSQL 17 disposable CI database only. Never point this runner at staging.
: "${PGHOST:=127.0.0.1}"
: "${PGPORT:=5432}"
: "${PGUSER:=postgres}"
: "${PGPASSWORD:?PostgreSQL service password is required}"
: "${PGDATABASE:=sakhi_test}"

if [[ "$PGDATABASE" != "sakhi_test" || "$PGHOST" != "127.0.0.1" ]]; then
  echo "Refusing integration setup outside the disposable local sakhi_test database." >&2
  exit 1
fi

export SAKHI_ENV=test
export NODE_ENV=development
export HOST=127.0.0.1

APP_PASSWORD="$(openssl rand -hex 32)"
DEV_ROLE_PASSWORD="$(openssl rand -hex 32)"
MIGRATOR_PASSWORD="$(openssl rand -hex 32)"
STAGING_ROLE_PASSWORD="$(openssl rand -hex 32)"
STAGING_MIGRATOR_PASSWORD="$(openssl rand -hex 32)"
STAGING_FIXTURE_CLEANUP_PASSWORD="$(openssl rand -hex 32)"
SUPABASE_POSTGRES_PASSWORD="$(openssl rand -hex 32)"
SUPABASE_RENAMER_PASSWORD="$(openssl rand -hex 32)"

# The migrator is privileged only inside this disposable CI database. The app
# role remains NOBYPASSRLS and never owns protected member-data tables.
psql "postgresql://${PGUSER}:${PGPASSWORD}@${PGHOST}:${PGPORT}/${PGDATABASE}" \
  -v ON_ERROR_STOP=1 \
  -v app_password="$APP_PASSWORD" \
  -v dev_role_password="$DEV_ROLE_PASSWORD" \
  -v migrator_password="$MIGRATOR_PASSWORD" \
  -v staging_role_password="$STAGING_ROLE_PASSWORD" \
  -v staging_migrator_password="$STAGING_MIGRATOR_PASSWORD" \
  -v staging_fixture_cleanup_password="$STAGING_FIXTURE_CLEANUP_PASSWORD" \
  -v supabase_postgres_password="$SUPABASE_POSTGRES_PASSWORD" \
  -v supabase_renamer_password="$SUPABASE_RENAMER_PASSWORD" <<'SQL'
SELECT format(
  'CREATE ROLE sakhi_test_app LOGIN PASSWORD %L NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS',
  :'app_password'
) \gexec
SELECT format(
  'CREATE ROLE sakhi_dev_app LOGIN PASSWORD %L NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS',
  :'dev_role_password'
) \gexec
SELECT format(
  'CREATE ROLE sakhi_test_migrator LOGIN PASSWORD %L NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION BYPASSRLS',
  :'migrator_password'
) \gexec
SELECT format(
  'CREATE ROLE sakhi_staging_app LOGIN PASSWORD %L NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS',
  :'staging_role_password'
) \gexec
SELECT format(
  'CREATE ROLE sakhi_staging_migrator LOGIN PASSWORD %L NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS',
  :'staging_migrator_password'
) \gexec

SELECT format(
  'CREATE ROLE sakhi_staging_fixture_cleanup LOGIN PASSWORD %L NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS',
  :'staging_fixture_cleanup_password'
) \gexec
SELECT format(
  'CREATE ROLE sakhi_test_supabase_postgres LOGIN PASSWORD %L NOSUPERUSER CREATEDB CREATEROLE BYPASSRLS',
  :'supabase_postgres_password'
) \gexec
SELECT format(
  'CREATE ROLE sakhi_ci_role_renamer LOGIN SUPERUSER PASSWORD %L',
  :'supabase_renamer_password'
) \gexec

-- Reproduce Supabase Data API roles so the Stage 4B migration proves that
-- even a BYPASSRLS service_role has no direct table/column privileges.
CREATE ROLE anon NOLOGIN NOSUPERUSER NOBYPASSRLS;
CREATE ROLE authenticated NOLOGIN NOSUPERUSER NOBYPASSRLS;
CREATE ROLE service_role NOLOGIN NOSUPERUSER BYPASSRLS;

GRANT CONNECT ON DATABASE sakhi_test TO sakhi_test_app, sakhi_dev_app, sakhi_test_migrator, sakhi_staging_migrator, sakhi_staging_fixture_cleanup, sakhi_test_supabase_postgres;
GRANT CREATE ON DATABASE sakhi_test TO sakhi_test_migrator;
GRANT USAGE ON SCHEMA public TO sakhi_test_app, sakhi_staging_fixture_cleanup;
GRANT USAGE, CREATE ON SCHEMA public TO sakhi_test_migrator, sakhi_staging_migrator, sakhi_test_supabase_postgres;
SQL

# Reproduce Supabase's administrator identity, not merely its role name.
# PostgreSQL records superuser role-membership grants under the cluster's
# bootstrap superuser OID. Rename that actual role to supabase_admin, then
# rename the prepared restricted stand-in to postgres for migration execution.
SUPABASE_ADMIN_PASSWORD="$PGPASSWORD"
# A separate temporary superuser must perform the rename: PostgreSQL forbids
# the active session user from renaming itself, even when it is a superuser.
# The original bootstrap role's OID is retained, so its later membership
# grants are attributed to supabase_admin after the rename.
psql "postgresql://sakhi_ci_role_renamer:${SUPABASE_RENAMER_PASSWORD}@${PGHOST}:${PGPORT}/${PGDATABASE}" \
  -v ON_ERROR_STOP=1 <<'SQL'
ALTER ROLE postgres RENAME TO supabase_admin;
ALTER ROLE sakhi_test_supabase_postgres RENAME TO postgres;

DO $supabase_role_identity$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_roles
    WHERE rolname = 'supabase_admin' AND rolsuper
  ) OR NOT EXISTS (
    SELECT 1 FROM pg_roles
    WHERE rolname = 'postgres'
      AND NOT rolsuper
      AND rolcanlogin
      AND rolcreatedb
      AND rolcreaterole
      AND rolbypassrls
  ) THEN
    RAISE EXCEPTION 'Disposable CI role identities do not match the Supabase administrator/postgres boundary';
  END IF;
END
$supabase_role_identity$;
SQL

# The temporary renamer cannot drop its own active session role. Remove it
# from a separate connection authenticated as the renamed bootstrap admin.
psql "postgresql://supabase_admin:${SUPABASE_ADMIN_PASSWORD}@${PGHOST}:${PGPORT}/${PGDATABASE}" \
  -v ON_ERROR_STOP=1 <<'SQL'
DROP ROLE sakhi_ci_role_renamer;
SQL

# All subsequent ordinary PG connections must authenticate as the restricted
# non-superuser role now named postgres. Keep the original bootstrap password
# only for explicit supabase_admin maintenance connections.
PGPASSWORD="$SUPABASE_POSTGRES_PASSWORD"

export SAKHI_APP_DATABASE_URL="postgresql://sakhi_test_app:${APP_PASSWORD}@${PGHOST}:${PGPORT}/sakhi_test?schema=public"
export SAKHI_MIGRATOR_DATABASE_URL="postgresql://sakhi_test_migrator:${MIGRATOR_PASSWORD}@${PGHOST}:${PGPORT}/sakhi_test?schema=public"
export SAKHI_STAGING_MIGRATOR_DATABASE_URL="postgresql://sakhi_staging_migrator:${STAGING_MIGRATOR_PASSWORD}@${PGHOST}:${PGPORT}/sakhi_test?schema=public"
export SAKHI_STAGING_FIXTURE_CLEANUP_DATABASE_URL="postgresql://sakhi_staging_fixture_cleanup:${STAGING_FIXTURE_CLEANUP_PASSWORD}@${PGHOST}:${PGPORT}/sakhi_test?schema=public"

# Apply the predecessor migrations with the disposable CI migrator, but hold
# the two new admin migrations back: staging must apply them in the Supabase
# table-owner context, then let the restricted Prisma migrator record them.
MIGRATION_ROOT="prisma/migrations"
MIGRATION_HOLD_DIR="$(mktemp -d)"
MANUAL_ADMIN_MIGRATIONS=(
  "20261117140000_single_use_admin_bootstrap_credential"
  "20261117150000_staging_mfa_fixture_cleanup_role"
  "20261119140000_admin_staff_role_constraints"
  "20261119150000_secure_admin_bootstrap_function_search_path"
  "20261119160000_revoke_data_api_roles_from_member_data"
)
restore_admin_migrations() {
  for migration in "${MANUAL_ADMIN_MIGRATIONS[@]}"; do
    if [[ -d "${MIGRATION_HOLD_DIR}/${migration}" ]]; then
      mv "${MIGRATION_HOLD_DIR}/${migration}" "${MIGRATION_ROOT}/${migration}"
    fi
  done
  rmdir "${MIGRATION_HOLD_DIR}" 2>/dev/null || true
}
trap restore_admin_migrations EXIT
for migration in "${MANUAL_ADMIN_MIGRATIONS[@]}"; do
  mv "${MIGRATION_ROOT}/${migration}" "${MIGRATION_HOLD_DIR}/${migration}"
done
npm run db:migrate:deploy
restore_admin_migrations
trap - EXIT

# Reproduce Supabase's real role names and privilege boundary. Rename the
# container's bootstrap superuser out of the way, then rename the prepared
# non-superuser stand-in to "postgres". This lets migrations run with
# session_user=current_user=postgres and no superuser privilege, as in staging.
psql "postgresql://supabase_admin:${SUPABASE_ADMIN_PASSWORD}@${PGHOST}:${PGPORT}/${PGDATABASE}" \
  -v ON_ERROR_STOP=1 <<'SQL'
ALTER TABLE public.member_accounts OWNER TO sakhi_staging_migrator;
ALTER TABLE public.auth_sessions OWNER TO sakhi_staging_migrator;
ALTER TABLE public.otp_challenges OWNER TO sakhi_staging_migrator;
ALTER TABLE public.account_deletion_requests OWNER TO sakhi_staging_migrator;
ALTER TABLE public.member_profiles OWNER TO sakhi_staging_migrator;
ALTER TABLE public.member_consents OWNER TO sakhi_staging_migrator;
ALTER TABLE public.member_communication_preferences OWNER TO sakhi_staging_migrator;
ALTER TABLE public.eligibility_submissions OWNER TO sakhi_staging_migrator;
ALTER TABLE public.community_posts OWNER TO sakhi_staging_migrator;
ALTER TABLE public.community_post_likes OWNER TO sakhi_staging_migrator;
ALTER TABLE public.community_post_saves OWNER TO sakhi_staging_migrator;
ALTER TABLE public.community_post_comments OWNER TO sakhi_staging_migrator;
ALTER TABLE public.community_groups OWNER TO sakhi_staging_migrator;
ALTER TABLE public.member_follows OWNER TO sakhi_staging_migrator;
ALTER TABLE public.member_privacy_preferences OWNER TO sakhi_staging_migrator;
ALTER TABLE public.member_notification_preferences OWNER TO sakhi_staging_migrator;
ALTER TABLE public.member_notifications OWNER TO sakhi_staging_migrator;
ALTER TABLE public.safety_emergency_contacts OWNER TO sakhi_staging_migrator;
ALTER TABLE public.safety_sos_events OWNER TO sakhi_staging_migrator;
ALTER TABLE public.safety_location_shares OWNER TO sakhi_staging_migrator;
ALTER TABLE public.member_moderation_blocks OWNER TO sakhi_staging_migrator;
ALTER TABLE public.member_user_reports OWNER TO sakhi_staging_migrator;
ALTER TABLE public.direct_messages OWNER TO sakhi_staging_migrator;
ALTER TABLE public.media_assets OWNER TO sakhi_staging_migrator;
ALTER TABLE public.community_post_reactions OWNER TO sakhi_staging_migrator;
ALTER TABLE public.business_directory_listings OWNER TO sakhi_staging_migrator;
ALTER TABLE public.business_enquiries OWNER TO sakhi_staging_migrator;
ALTER TABLE public.business_reports OWNER TO sakhi_staging_migrator;
ALTER TABLE public.menstrual_cycle_logs OWNER TO sakhi_staging_migrator;
ALTER TABLE public.menstrual_daily_logs OWNER TO sakhi_staging_migrator;
ALTER TABLE public.menstrual_tracker_preferences OWNER TO sakhi_staging_migrator;
ALTER TABLE public.community_directory_profiles OWNER TO sakhi_staging_migrator;
ALTER TABLE public.eligibility_consents OWNER TO sakhi_staging_migrator;
ALTER TABLE public.eligibility_support_requests OWNER TO sakhi_staging_migrator;
ALTER TABLE public.eligibility_verification_sessions OWNER TO sakhi_staging_migrator;
ALTER TABLE public.audit_events OWNER TO sakhi_staging_migrator;
ALTER TABLE public.moderation_decisions OWNER TO sakhi_staging_migrator;
ALTER TABLE public.admin_staff_accounts OWNER TO sakhi_staging_migrator;
ALTER TABLE public.discreet_complaints OWNER TO sakhi_staging_migrator;
ALTER TABLE public.eligibility_provider_callback_events OWNER TO sakhi_staging_migrator;
ALTER TABLE public.admin_auth_sessions OWNER TO postgres;
ALTER TABLE public.admin_staff_backup_codes OWNER TO postgres;
ALTER TABLE public.admin_staff_mfa OWNER TO postgres;
ALTER TABLE public.admin_staff_recovery_requests OWNER TO postgres;
ALTER TABLE public.admin_staff_sessions OWNER TO postgres;
ALTER TABLE public.community_circle_memberships OWNER TO postgres;
ALTER TABLE public.community_circle_posts OWNER TO postgres;
ALTER TABLE public.member_push_tokens OWNER TO postgres;
ALTER TABLE public.member_wellness_preferences OWNER TO postgres;
-- Keep the isolated integration fixture role capable of seeding and cleaning
-- data after ownership is transferred to the staging-equivalent principals.
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO sakhi_test_migrator;
SQL

# The login role supabase_admin is the renamed cluster bootstrap superuser.
# Its grants are therefore naturally recorded with the required grantor OID.
psql "postgresql://supabase_admin:${SUPABASE_ADMIN_PASSWORD}@${PGHOST}:${PGPORT}/${PGDATABASE}" \
  -v ON_ERROR_STOP=1 <<'SQL'
GRANT sakhi_staging_migrator TO postgres
  WITH ADMIN OPTION, INHERIT FALSE, SET FALSE;
GRANT sakhi_staging_fixture_cleanup TO postgres
  WITH ADMIN OPTION, INHERIT FALSE, SET FALSE;

DO $fixture_cleanup_membership_assertion$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_auth_members am
    JOIN pg_roles granted ON granted.oid = am.roleid
    JOIN pg_roles member ON member.oid = am.member
    JOIN pg_roles grantor ON grantor.oid = am.grantor
    WHERE granted.rolname = 'sakhi_staging_fixture_cleanup'
      AND member.rolname = 'postgres'
      AND grantor.rolname = 'supabase_admin'
      AND am.admin_option IS TRUE
      AND am.inherit_option IS FALSE
      AND am.set_option IS FALSE
  ) THEN
    RAISE EXCEPTION 'CI fixture-cleanup membership was not recorded with the required supabase_admin grantor and restricted options';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_auth_members am
    WHERE am.member = (SELECT oid FROM pg_roles WHERE rolname = 'sakhi_staging_fixture_cleanup')
       OR (
         am.roleid = (SELECT oid FROM pg_roles WHERE rolname = 'sakhi_staging_fixture_cleanup')
         AND NOT (
           am.member = (SELECT oid FROM pg_roles WHERE rolname = 'postgres')
           AND am.grantor = (SELECT oid FROM pg_roles WHERE rolname = 'supabase_admin')
           AND am.admin_option IS TRUE
           AND am.inherit_option IS FALSE
           AND am.set_option IS FALSE
         )
       )
  ) THEN
    RAISE EXCEPTION 'CI fixture-cleanup role has an additional or unsupported membership';
  END IF;
END
$fixture_cleanup_membership_assertion$;
RESET ROLE;
SQL

psql "postgresql://${PGUSER}:${PGPASSWORD}@${PGHOST}:${PGPORT}/${PGDATABASE}" \
  -v ON_ERROR_STOP=1 <<'SQL'

-- Match the second membership row observed in Supabase: postgres grants
-- itself SET/INHERIT access to the migrator using its managed ADMIN option.
SET ROLE postgres;
GRANT sakhi_staging_migrator TO postgres
  WITH INHERIT TRUE, SET TRUE;
RESET ROLE;

DO $owner_boundary$
BEGIN
  IF pg_get_userbyid((SELECT relowner FROM pg_class WHERE oid='public._prisma_migrations'::regclass)) <> 'sakhi_test_migrator'
     OR pg_get_userbyid((SELECT relowner FROM pg_class WHERE oid='public.admin_staff_accounts'::regclass)) <> 'sakhi_staging_migrator'
     OR EXISTS (
       SELECT 1 FROM pg_class
       WHERE oid IN (
         'public.admin_staff_sessions'::regclass,
         'public.admin_staff_mfa'::regclass,
         'public.admin_staff_backup_codes'::regclass,
         'public.admin_staff_recovery_requests'::regclass
       )
       AND pg_get_userbyid(relowner) <> 'postgres'
     )
     OR NOT pg_has_role('postgres','sakhi_staging_migrator','SET')
     OR NOT has_schema_privilege('postgres','public','CREATE') THEN
    RAISE EXCEPTION 'Disposable CI database does not reproduce the Supabase table-owner and role-switch boundary';
  END IF;
END
$owner_boundary$;

SQL

# Keep the original disposable CI connection authenticated as postgres, but
# SET ROLE to the prepared non-superuser Supabase-postgres stand-in for each
# migration. This preserves session_user=postgres while current_user has the
# same non-superuser ownership and role-switch boundary as live staging.

# Emit the exact disposable role-membership rows used by the migration preflight.
# This is metadata only; it contains no credentials or application data.
psql "postgresql://${PGUSER}:${PGPASSWORD}@${PGHOST}:${PGPORT}/${PGDATABASE}" \
  -v ON_ERROR_STOP=1 <<'SQL'
SET ROLE postgres;
SELECT granted.rolname AS granted_role,
       member.rolname AS member_role,
       grantor.rolname AS grantor_role,
       am.admin_option,
       am.inherit_option,
       am.set_option
FROM pg_auth_members am
JOIN pg_roles granted ON granted.oid = am.roleid
JOIN pg_roles member ON member.oid = am.member
JOIN pg_roles grantor ON grantor.oid = am.grantor
WHERE granted.rolname = 'sakhi_staging_fixture_cleanup'
   OR member.rolname = 'sakhi_staging_fixture_cleanup'
ORDER BY granted.rolname, member.rolname, grantor.rolname;
RESET ROLE;
SQL

# Execute the bootstrap migration under the non-superuser role context.
psql "postgresql://${PGUSER}:${PGPASSWORD}@${PGHOST}:${PGPORT}/${PGDATABASE}" \
  -v ON_ERROR_STOP=1 <<SQL
SET ROLE postgres;
\\i ${MIGRATION_ROOT}/20261117140000_single_use_admin_bootstrap_credential/migration.sql
SQL

# The second migration checks session_user=postgres and current_user is
# non-superuser, then switches to the account-table owner only for account DDL.
psql "postgresql://${PGUSER}:${PGPASSWORD}@${PGHOST}:${PGPORT}/${PGDATABASE}" \
  -v ON_ERROR_STOP=1 <<SQL
SET ROLE postgres;
\\i ${MIGRATION_ROOT}/20261117150000_staging_mfa_fixture_cleanup_role/migration.sql
SQL

# Apply the Stage 4A role constraints as the owning staging migrator.
# Apply the bootstrap function hardening and Stage 4B Data API revocations as
# restricted postgres; the Stage 4B migration temporarily SET ROLEs to the
# staging migrator for the member tables owned by that principal.
psql "postgresql://${PGUSER}:${PGPASSWORD}@${PGHOST}:${PGPORT}/${PGDATABASE}" \
  -v ON_ERROR_STOP=1 <<SQL
SET ROLE sakhi_staging_migrator;
\i ${MIGRATION_ROOT}/20261119140000_admin_staff_role_constraints/migration.sql
RESET ROLE;
SQL

# Seed the disposable database with the risky Data API grants observed in
# Supabase staging. The Stage 4B migration must revoke these before CI passes.
psql "postgresql://supabase_admin:${SUPABASE_ADMIN_PASSWORD}@${PGHOST}:${PGPORT}/${PGDATABASE}" \
  -v ON_ERROR_STOP=1 <<'SQL'
GRANT SELECT ON TABLE
  public.member_accounts,
  public.member_profiles,
  public.admin_staff_accounts
TO sakhi_staging_app;

GRANT ALL PRIVILEGES ON TABLE
  public.member_accounts,
  public.auth_sessions,
  public.otp_challenges,
  public.account_deletion_requests,
  public.member_profiles,
  public.member_consents,
  public.member_communication_preferences,
  public.eligibility_submissions,
  public.community_posts,
  public.community_post_likes,
  public.community_post_saves,
  public.community_post_comments,
  public.community_groups,
  public.community_circle_memberships,
  public.community_circle_posts,
  public.member_follows,
  public.member_privacy_preferences,
  public.member_notification_preferences,
  public.member_push_tokens,
  public.member_wellness_preferences,
  public.member_notifications,
  public.safety_emergency_contacts,
  public.safety_sos_events,
  public.safety_location_shares,
  public.member_moderation_blocks,
  public.member_user_reports,
  public.direct_messages,
  public.media_assets,
  public.community_post_reactions,
  public.business_directory_listings,
  public.business_enquiries,
  public.business_reports,
  public.menstrual_cycle_logs,
  public.menstrual_daily_logs,
  public.menstrual_tracker_preferences,
  public.community_directory_profiles,
  public.eligibility_consents,
  public.eligibility_support_requests,
  public.eligibility_verification_sessions,
  public.audit_events,
  public.moderation_decisions,
  public.admin_staff_accounts,
  public.admin_staff_sessions,
  public.admin_staff_mfa,
  public.admin_staff_backup_codes,
  public.admin_staff_recovery_requests,
  public.admin_auth_sessions,
  public.discreet_complaints,
  public.eligibility_provider_callback_events,
  public.admin_bootstrap_credentials
TO anon, authenticated, service_role;
SQL

psql "postgresql://${PGUSER}:${PGPASSWORD}@${PGHOST}:${PGPORT}/${PGDATABASE}" \
  -v ON_ERROR_STOP=1 <<SQL
SET ROLE postgres;
\i ${MIGRATION_ROOT}/20261119150000_secure_admin_bootstrap_function_search_path/migration.sql
\i ${MIGRATION_ROOT}/20261119160000_revoke_data_api_roles_from_member_data/migration.sql
RESET ROLE;
SQL

# The test migrator owns _prisma_migrations and records the exact migrations
# already applied above under their reviewed table-owner identities.
for migration in "${MANUAL_ADMIN_MIGRATIONS[@]}"; do
  npx prisma migrate resolve --applied "${migration}"
done

npm run prisma:generate
npm run db:seed

# Use the disposable CI-only Supabase admin role for test fixture grants.
# This role is never present in staging and is not used to execute the migrations.
psql "postgresql://supabase_admin:${SUPABASE_ADMIN_PASSWORD}@${PGHOST}:${PGPORT}/${PGDATABASE}" \
  -v ON_ERROR_STOP=1 <<'SQL'
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO sakhi_test_app;
REVOKE ALL ON TABLE public._prisma_migrations FROM sakhi_test_app;

-- The integration suite uses sakhi_test_migrator only as a disposable fixture
-- setup/inspection helper. It is deliberately separate from the staging
-- migrator and receives DML (not ownership or TRUNCATE) on the five staff
-- tables whose ownership reproduces the Supabase staging boundary.
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE
  public.admin_staff_accounts,
  public.admin_staff_sessions,
  public.admin_staff_mfa,
  public.admin_staff_backup_codes,
  public.admin_staff_recovery_requests
TO sakhi_test_migrator;

-- Test-only staff security access mirrors the dedicated backend runtime role.
-- This policy is installed only in the disposable sakhi_test database. The
-- test app role remains NOBYPASSRLS and does not own these tables.
GRANT SELECT, INSERT, UPDATE ON TABLE
  public.admin_staff_accounts,
  public.admin_staff_sessions,
  public.admin_staff_mfa,
  public.admin_staff_backup_codes,
  public.admin_staff_recovery_requests
TO sakhi_test_app;
DO $test_staff_rls$
DECLARE
  table_name text;
  policy_name text;
BEGIN
  FOREACH table_name IN ARRAY ARRAY[
    'admin_staff_accounts',
    'admin_staff_sessions',
    'admin_staff_mfa',
    'admin_staff_backup_codes',
    'admin_staff_recovery_requests'
  ] LOOP
    policy_name := table_name || '_runtime_sakhi_test_app';
    IF NOT EXISTS (
      SELECT 1 FROM pg_policies
      WHERE schemaname='public' AND tablename=table_name AND policyname=policy_name
    ) THEN
      EXECUTE format(
        'CREATE POLICY %I ON public.%I FOR ALL TO sakhi_test_app USING (true) WITH CHECK (true)',
        policy_name, table_name
      );
    END IF;
  END LOOP;
END
$test_staff_rls$;
SQL

export SAKHI_DB_INTEGRATION=true
export SAKHI_OTP_MODE=disabled
export SAKHI_ADMIN_STAFF_SESSION_SIGNING_KEY="$(openssl rand -base64 32)"
export SAKHI_ADMIN_MFA_ENCRYPTION_KEY="$(openssl rand -base64 32)"
export SAKHI_ADMIN_REVIEW_TOKEN="$(openssl rand -hex 32)"
export SAKHI_MANUAL_REVIEW_POLICY_APPROVED=true
export SAKHI_MANUAL_REVIEW_EVIDENCE_PROCEDURE_APPROVED=true
export SAKHI_MANUAL_REVIEW_CONSENT_VERSION=integration-test-v1
export SAKHI_MANUAL_REVIEW_CONSENT_TEXT="TEST ONLY: synthetic fixtures; no real identity evidence is collected."
export SAKHI_MANUAL_REVIEW_DESCRIPTION="TEST ONLY: exercise the manual-review API state machine with synthetic accounts."
export SAKHI_MANUAL_REVIEW_DATA_HANDLING_DESCRIPTION="TEST ONLY: no real member or identity evidence data is used."
export SAKHI_MANUAL_REVIEW_RETENTION_DESCRIPTION="TEST ONLY: integration fixtures are deleted by the migrator cleanup step."

npm run test:db-admin-review

# Exercise the already-applied Stage 3D/Stage 5 account-isolation policies and
# forced-RLS table inventory against two separate non-production DB roles.
export SAKHI_STAGE5_RLS_ADMIN_TEST_URL="postgresql://sakhi_test_migrator:${MIGRATOR_PASSWORD}@${PGHOST}:${PGPORT}/${PGDATABASE}?schema=public"
export SAKHI_STAGE5_RLS_APP_TEST_URL="postgresql://sakhi_test_app:${APP_PASSWORD}@${PGHOST}:${PGPORT}/${PGDATABASE}?schema=public"
NODE_ENV=test npx vitest run test/integration/stage5-member-rls.integration.spec.ts --reporter=verbose

# Verify forced RLS metadata for staff-security tables against the same disposable PostgreSQL 17 database.
NODE_ENV=test npx vitest run test/admin-mfa-role-boundary.database.integration.spec.ts --reporter=verbose

unset SAKHI_APP_DATABASE_URL SAKHI_MIGRATOR_DATABASE_URL SAKHI_ADMIN_REVIEW_TOKEN SAKHI_STAGE5_RLS_ADMIN_TEST_URL SAKHI_STAGE5_RLS_APP_TEST_URL

# Execute the exact community follower RLS performance migration in a fresh
# disposable PostgreSQL database, including its no-approved-role fail-closed path.
bash scripts/test-community-followers-rls-migration.sh
