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
MIGRATOR_PASSWORD="$(openssl rand -hex 32)"
STAGING_ROLE_PASSWORD="$(openssl rand -hex 32)"

# The migrator is privileged only inside this disposable CI database. The app
# role remains NOBYPASSRLS and never owns protected member-data tables.
psql "postgresql://${PGUSER}:${PGPASSWORD}@${PGHOST}:${PGPORT}/${PGDATABASE}" \
  -v app_password="$APP_PASSWORD" \
  -v migrator_password="$MIGRATOR_PASSWORD" \
  -v staging_role_password="$STAGING_ROLE_PASSWORD" <<'SQL'
SELECT format(
  'CREATE ROLE sakhi_test_app LOGIN PASSWORD %L NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS',
  :'app_password'
) \gexec
SELECT format(
  'CREATE ROLE sakhi_test_migrator LOGIN PASSWORD %L NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION BYPASSRLS',
  :'migrator_password'
) \gexec
SELECT format(
  'CREATE ROLE sakhi_staging_app LOGIN PASSWORD %L NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS',
  :'staging_role_password'
) \gexec

GRANT CONNECT ON DATABASE sakhi_test TO sakhi_test_app, sakhi_test_migrator;
GRANT CREATE ON DATABASE sakhi_test TO sakhi_test_migrator;
GRANT USAGE ON SCHEMA public TO sakhi_test_app;
GRANT USAGE, CREATE ON SCHEMA public TO sakhi_test_migrator;
SQL

export SAKHI_APP_DATABASE_URL="postgresql://sakhi_test_app:${APP_PASSWORD}@${PGHOST}:${PGPORT}/sakhi_test?schema=public"
export SAKHI_MIGRATOR_DATABASE_URL="postgresql://sakhi_test_migrator:${MIGRATOR_PASSWORD}@${PGHOST}:${PGPORT}/sakhi_test?schema=public"

npm run db:migrate:deploy
npm run prisma:generate
npm run db:seed

# Grant object access to the NOBYPASSRLS app role. These grants do not alter
# RLS policies, enable bypass, or transfer table ownership.
psql "postgresql://sakhi_test_migrator:${MIGRATOR_PASSWORD}@${PGHOST}:${PGPORT}/sakhi_test" <<'SQL'
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO sakhi_test_app;
GRANT USAGE ON ALL TYPES IN SCHEMA public TO sakhi_test_app;
REVOKE ALL ON TABLE public._prisma_migrations FROM sakhi_test_app;

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

unset SAKHI_APP_DATABASE_URL SAKHI_MIGRATOR_DATABASE_URL SAKHI_ADMIN_REVIEW_TOKEN
