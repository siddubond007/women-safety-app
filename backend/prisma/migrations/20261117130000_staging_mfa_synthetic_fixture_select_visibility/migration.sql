BEGIN;

-- DELETE policies alone are not sufficient for PostgreSQL to target rows
-- through a filtered predicate under FORCE RLS. Give the dedicated staging
-- migrator column-level SELECT plus row-level SELECT policies that reveal
-- only rows belonging to synthetic MFA fixtures.
DO $mfa_fixture_select_preflight$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_roles
    WHERE rolname='sakhi_staging_migrator'
      AND rolcanlogin AND NOT rolsuper AND NOT rolbypassrls
      AND NOT rolcreatedb AND NOT rolcreaterole AND NOT rolreplication
  ) THEN
    RAISE EXCEPTION 'sakhi_staging_migrator is missing or has excessive privileges';
  END IF;
  IF NOT has_column_privilege(
    'sakhi_staging_migrator',
    'public.admin_staff_accounts',
    'id',
    'SELECT'
  ) OR NOT has_column_privilege(
    'sakhi_staging_migrator',
    'public.admin_staff_accounts',
    'email',
    'SELECT'
  ) OR NOT has_column_privilege(
    'sakhi_staging_migrator',
    'public.admin_staff_accounts',
    'staff_code',
    'SELECT'
  ) THEN
    RAISE EXCEPTION 'The migrator must be able to identify synthetic staff accounts only';
  END IF;
END
$mfa_fixture_select_preflight$;

DO $mfa_fixture_select_policies$
DECLARE
  item RECORD;
BEGIN
  FOR item IN
    SELECT * FROM (VALUES
      ('admin_staff_sessions','admin_staff_sessions_mfa_fixture_cleanup_select'),
      ('admin_staff_mfa','admin_staff_mfa_mfa_fixture_cleanup_select'),
      ('admin_staff_backup_codes','admin_staff_backup_codes_mfa_fixture_cleanup_select'),
      ('admin_staff_recovery_requests','admin_staff_recovery_requests_mfa_fixture_cleanup_select')
    ) AS p(table_name, policy_name)
  LOOP
    IF NOT EXISTS (
      SELECT 1 FROM pg_policies
      WHERE schemaname='public'
        AND tablename=item.table_name
        AND policyname=item.policy_name
    ) THEN
      EXECUTE format(
        'CREATE POLICY %I ON public.%I FOR SELECT TO sakhi_staging_migrator USING (EXISTS (SELECT 1 FROM public.admin_staff_accounts a WHERE a.id = %I.staff_id AND a.email LIKE ''mfa-%%@example.test'' AND a.staff_code LIKE ''SYN-MFA-%%''))',
        item.policy_name,
        item.table_name,
        item.table_name
      );
    END IF;
  END LOOP;
END
$mfa_fixture_select_policies$;

DO $mfa_fixture_select_postflight$
DECLARE
  item RECORD;
  actual RECORD;
BEGIN
  FOR item IN
    SELECT * FROM (VALUES
      ('admin_staff_sessions','admin_staff_sessions_mfa_fixture_cleanup_select'),
      ('admin_staff_mfa','admin_staff_mfa_mfa_fixture_cleanup_select'),
      ('admin_staff_backup_codes','admin_staff_backup_codes_mfa_fixture_cleanup_select'),
      ('admin_staff_recovery_requests','admin_staff_recovery_requests_mfa_fixture_cleanup_select')
    ) AS p(table_name, policy_name)
  LOOP
    SELECT * INTO actual
    FROM pg_policies
    WHERE schemaname='public'
      AND tablename=item.table_name
      AND policyname=item.policy_name;
    IF NOT FOUND
       OR actual.permissive IS DISTINCT FROM 'PERMISSIVE'
       OR actual.roles IS DISTINCT FROM ARRAY['sakhi_staging_migrator']::name[]
       OR actual.cmd IS DISTINCT FROM 'SELECT'
       OR actual.qual IS NULL
       OR actual.qual NOT LIKE '%mfa-%@example.test%'
       OR actual.qual NOT LIKE '%SYN-MFA-%'
       OR actual.with_check IS NOT NULL THEN
      RAISE EXCEPTION 'Synthetic MFA SELECT policy %.% is not narrowly scoped',
        item.table_name, item.policy_name;
    END IF;
  END LOOP;

  IF EXISTS (
    SELECT 1 FROM pg_policies p
    WHERE p.schemaname='public'
      AND p.tablename IN (
        'admin_staff_sessions','admin_staff_mfa',
        'admin_staff_backup_codes','admin_staff_recovery_requests'
      )
      AND 'sakhi_staging_migrator'=ANY(p.roles)
      AND p.cmd='SELECT'
      AND p.policyname NOT IN (
        'admin_staff_sessions_mfa_fixture_cleanup_select',
        'admin_staff_mfa_mfa_fixture_cleanup_select',
        'admin_staff_backup_codes_mfa_fixture_cleanup_select',
        'admin_staff_recovery_requests_mfa_fixture_cleanup_select'
      )
  ) THEN
    RAISE EXCEPTION 'Unexpected migrator SELECT policy broadens child-table visibility';
  END IF;

  IF has_table_privilege('sakhi_staging_migrator','public.admin_staff_sessions','SELECT')
     OR has_table_privilege('sakhi_staging_migrator','public.admin_staff_mfa','SELECT')
     OR has_table_privilege('sakhi_staging_migrator','public.admin_staff_backup_codes','SELECT')
     OR has_table_privilege('sakhi_staging_migrator','public.admin_staff_recovery_requests','SELECT')
     OR NOT has_column_privilege('sakhi_staging_migrator','public.admin_staff_sessions','staff_id','SELECT')
     OR NOT has_column_privilege('sakhi_staging_migrator','public.admin_staff_mfa','staff_id','SELECT')
     OR NOT has_column_privilege('sakhi_staging_migrator','public.admin_staff_backup_codes','staff_id','SELECT')
     OR NOT has_column_privilege('sakhi_staging_migrator','public.admin_staff_recovery_requests','staff_id','SELECT') THEN
    RAISE EXCEPTION 'Migrator child-table SELECT must remain column-scoped';
  END IF;
END
$mfa_fixture_select_postflight$;

COMMIT;
