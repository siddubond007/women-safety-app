BEGIN;

-- Keep the staging application role strictly non-destructive. The separate
-- staging migrator may clean only synthetic MFA integration fixtures, and
-- only when their account carries both reserved fixture markers.
DO $mfa_cleanup_role_preflight$
DECLARE
  role_name text;
BEGIN
  FOREACH role_name IN ARRAY ARRAY['sakhi_staging_app', 'sakhi_staging_migrator'] LOOP
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = role_name AND rolcanlogin) THEN
      RAISE EXCEPTION 'Required staging role % is missing or cannot log in', role_name;
    END IF;
    IF EXISTS (
      SELECT 1 FROM pg_roles
      WHERE rolname = role_name
        AND (rolsuper OR rolbypassrls OR rolcreatedb OR rolcreaterole OR rolreplication)
    ) THEN
      RAISE EXCEPTION 'Staging role % must remain non-superuser and NOBYPASSRLS', role_name;
    END IF;
    IF EXISTS (
      SELECT 1 FROM pg_auth_members
      WHERE member = (SELECT oid FROM pg_roles WHERE rolname = role_name)
         OR roleid = (SELECT oid FROM pg_roles WHERE rolname = role_name)
    ) THEN
      RAISE EXCEPTION 'Staging role % must not have incoming or outgoing role memberships', role_name;
    END IF;
  END LOOP;

  IF EXISTS (
    SELECT 1
    FROM (VALUES
      ('admin_staff_accounts'),
      ('admin_staff_sessions'),
      ('admin_staff_mfa'),
      ('admin_staff_backup_codes'),
      ('admin_staff_recovery_requests')
    ) AS required(table_name)
    LEFT JOIN pg_class c
      ON c.relnamespace = 'public'::regnamespace
     AND c.relname = required.table_name
    WHERE c.oid IS NULL OR NOT c.relrowsecurity OR NOT c.relforcerowsecurity
  ) THEN
    RAISE EXCEPTION 'All five P0 staff-security tables must exist with enabled and forced RLS';
  END IF;
END
$mfa_cleanup_role_preflight$;

-- The live application remains SELECT/INSERT/UPDATE only on every P0 table.
REVOKE DELETE ON TABLE
  public.admin_staff_accounts,
  public.admin_staff_sessions,
  public.admin_staff_mfa,
  public.admin_staff_backup_codes,
  public.admin_staff_recovery_requests
FROM sakhi_staging_app;

-- Grant only the columns used by the synthetic-fixture filters and the
-- DELETE statements. No child-table SELECT policy is created for the migrator.
GRANT SELECT (id, email, staff_code)
  ON TABLE public.admin_staff_accounts TO sakhi_staging_migrator;
GRANT DELETE ON TABLE public.admin_staff_accounts TO sakhi_staging_migrator;
GRANT SELECT (staff_id)
  ON TABLE public.admin_staff_sessions, public.admin_staff_mfa,
  public.admin_staff_backup_codes, public.admin_staff_recovery_requests
  TO sakhi_staging_migrator;
GRANT DELETE ON TABLE
  public.admin_staff_sessions, public.admin_staff_mfa,
  public.admin_staff_backup_codes, public.admin_staff_recovery_requests
  TO sakhi_staging_migrator;

-- The account policy lets the migrator identify fixture accounts only.
-- The child policies reference that restricted view and cannot match real staff.
DO $mfa_cleanup_policies$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname='public' AND tablename='admin_staff_accounts'
      AND policyname='admin_staff_accounts_mfa_fixture_cleanup_select'
  ) THEN
    CREATE POLICY admin_staff_accounts_mfa_fixture_cleanup_select
      ON public.admin_staff_accounts
      FOR SELECT TO sakhi_staging_migrator
      USING (email LIKE 'mfa-%@example.test' AND staff_code LIKE 'SYN-MFA-%');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname='public' AND tablename='admin_staff_accounts'
      AND policyname='admin_staff_accounts_mfa_fixture_cleanup_delete'
  ) THEN
    CREATE POLICY admin_staff_accounts_mfa_fixture_cleanup_delete
      ON public.admin_staff_accounts
      FOR DELETE TO sakhi_staging_migrator
      USING (email LIKE 'mfa-%@example.test' AND staff_code LIKE 'SYN-MFA-%');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname='public' AND tablename='admin_staff_sessions'
      AND policyname='admin_staff_sessions_mfa_fixture_cleanup_delete'
  ) THEN
    CREATE POLICY admin_staff_sessions_mfa_fixture_cleanup_delete
      ON public.admin_staff_sessions
      FOR DELETE TO sakhi_staging_migrator
      USING (EXISTS (
        SELECT 1 FROM public.admin_staff_accounts a
        WHERE a.id = admin_staff_sessions.staff_id
          AND a.email LIKE 'mfa-%@example.test'
          AND a.staff_code LIKE 'SYN-MFA-%'
      ));
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname='public' AND tablename='admin_staff_mfa'
      AND policyname='admin_staff_mfa_mfa_fixture_cleanup_delete'
  ) THEN
    CREATE POLICY admin_staff_mfa_mfa_fixture_cleanup_delete
      ON public.admin_staff_mfa
      FOR DELETE TO sakhi_staging_migrator
      USING (EXISTS (
        SELECT 1 FROM public.admin_staff_accounts a
        WHERE a.id = admin_staff_mfa.staff_id
          AND a.email LIKE 'mfa-%@example.test'
          AND a.staff_code LIKE 'SYN-MFA-%'
      ));
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname='public' AND tablename='admin_staff_backup_codes'
      AND policyname='admin_staff_backup_codes_mfa_fixture_cleanup_delete'
  ) THEN
    CREATE POLICY admin_staff_backup_codes_mfa_fixture_cleanup_delete
      ON public.admin_staff_backup_codes
      FOR DELETE TO sakhi_staging_migrator
      USING (EXISTS (
        SELECT 1 FROM public.admin_staff_accounts a
        WHERE a.id = admin_staff_backup_codes.staff_id
          AND a.email LIKE 'mfa-%@example.test'
          AND a.staff_code LIKE 'SYN-MFA-%'
      ));
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname='public' AND tablename='admin_staff_recovery_requests'
      AND policyname='admin_staff_recovery_requests_mfa_fixture_cleanup_delete'
  ) THEN
    CREATE POLICY admin_staff_recovery_requests_mfa_fixture_cleanup_delete
      ON public.admin_staff_recovery_requests
      FOR DELETE TO sakhi_staging_migrator
      USING (EXISTS (
        SELECT 1 FROM public.admin_staff_accounts a
        WHERE a.id = admin_staff_recovery_requests.staff_id
          AND a.email LIKE 'mfa-%@example.test'
          AND a.staff_code LIKE 'SYN-MFA-%'
      ));
  END IF;
END
$mfa_cleanup_policies$;

-- Fail closed if any policy name is occupied by an incompatible policy,
-- if another migrator policy broadens visibility, or if app DELETE reappears.
DO $mfa_cleanup_postflight$
DECLARE
  expected RECORD;
  actual RECORD;
BEGIN
  FOR expected IN
    SELECT * FROM (VALUES
      ('admin_staff_accounts','admin_staff_accounts_mfa_fixture_cleanup_select','SELECT'),
      ('admin_staff_accounts','admin_staff_accounts_mfa_fixture_cleanup_delete','DELETE'),
      ('admin_staff_sessions','admin_staff_sessions_mfa_fixture_cleanup_delete','DELETE'),
      ('admin_staff_mfa','admin_staff_mfa_mfa_fixture_cleanup_delete','DELETE'),
      ('admin_staff_backup_codes','admin_staff_backup_codes_mfa_fixture_cleanup_delete','DELETE'),
      ('admin_staff_recovery_requests','admin_staff_recovery_requests_mfa_fixture_cleanup_delete','DELETE')
    ) AS p(table_name, policy_name, command)
  LOOP
    SELECT * INTO actual
    FROM pg_policies
    WHERE schemaname='public'
      AND tablename=expected.table_name
      AND policyname=expected.policy_name;
    IF NOT FOUND
       OR actual.permissive IS DISTINCT FROM 'PERMISSIVE'
       OR actual.roles IS DISTINCT FROM ARRAY['sakhi_staging_migrator']::name[]
       OR actual.cmd IS DISTINCT FROM expected.command
       OR actual.qual IS NULL
       OR actual.qual NOT LIKE '%mfa-%@example.test%'
       OR actual.qual NOT LIKE '%SYN-MFA-%'
       OR actual.with_check IS NOT NULL THEN
      RAISE EXCEPTION 'MFA synthetic cleanup policy %.% has an unexpected shape',
        expected.table_name, expected.policy_name;
    END IF;
  END LOOP;

  IF EXISTS (
    SELECT 1 FROM pg_policies p
    WHERE p.schemaname='public'
      AND p.tablename IN (
        'admin_staff_accounts','admin_staff_sessions','admin_staff_mfa',
        'admin_staff_backup_codes','admin_staff_recovery_requests'
      )
      AND p.roles && ARRAY['sakhi_staging_migrator']::name[]
      AND NOT (
        (p.tablename='admin_staff_accounts' AND p.policyname IN (
          'admin_staff_accounts_mfa_fixture_cleanup_select',
          'admin_staff_accounts_mfa_fixture_cleanup_delete'
        )) OR
        (p.tablename='admin_staff_sessions' AND p.policyname='admin_staff_sessions_mfa_fixture_cleanup_delete') OR
        (p.tablename='admin_staff_mfa' AND p.policyname='admin_staff_mfa_mfa_fixture_cleanup_delete') OR
        (p.tablename='admin_staff_backup_codes' AND p.policyname='admin_staff_backup_codes_mfa_fixture_cleanup_delete') OR
        (p.tablename='admin_staff_recovery_requests' AND p.policyname='admin_staff_recovery_requests_mfa_fixture_cleanup_delete')
      )
  ) THEN
    RAISE EXCEPTION 'Unexpected permissive policy exists for sakhi_staging_migrator on a P0 table';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM (VALUES
      ('admin_staff_accounts'),('admin_staff_sessions'),('admin_staff_mfa'),
      ('admin_staff_backup_codes'),('admin_staff_recovery_requests')
    ) AS t(table_name)
    WHERE has_table_privilege('sakhi_staging_app', format('public.%I', t.table_name), 'DELETE')
       OR NOT has_table_privilege('sakhi_staging_migrator', format('public.%I', t.table_name), 'DELETE')
  ) THEN
    RAISE EXCEPTION 'P0 DELETE privileges do not match the staging app/migrator separation';
  END IF;

  IF NOT (
    has_column_privilege('sakhi_staging_migrator','public.admin_staff_accounts','id','SELECT')
    AND has_column_privilege('sakhi_staging_migrator','public.admin_staff_accounts','email','SELECT')
    AND has_column_privilege('sakhi_staging_migrator','public.admin_staff_accounts','staff_code','SELECT')
    AND has_column_privilege('sakhi_staging_migrator','public.admin_staff_sessions','staff_id','SELECT')
    AND has_column_privilege('sakhi_staging_migrator','public.admin_staff_mfa','staff_id','SELECT')
    AND has_column_privilege('sakhi_staging_migrator','public.admin_staff_backup_codes','staff_id','SELECT')
    AND has_column_privilege('sakhi_staging_migrator','public.admin_staff_recovery_requests','staff_id','SELECT')
  ) THEN
    RAISE EXCEPTION 'MFA synthetic cleanup column privileges are incomplete';
  END IF;

  IF EXISTS (
    SELECT 1 FROM pg_roles
    WHERE rolname='sakhi_staging_migrator'
      AND (rolsuper OR rolbypassrls OR rolcreatedb OR rolcreaterole OR rolreplication)
  ) THEN
    RAISE EXCEPTION 'sakhi_staging_migrator must remain NOBYPASSRLS and non-privileged';
  END IF;
END
$mfa_cleanup_postflight$;

COMMIT;
