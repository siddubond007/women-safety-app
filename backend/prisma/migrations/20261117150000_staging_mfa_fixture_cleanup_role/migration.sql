BEGIN;

-- The schema migrator remains the owner of the staging schema and is never
-- used by the MFA integration teardown. This separate login is deliberately
-- not an owner, member of another role, schema creator, or table truncator.
DO $fixture_cleanup_role_preflight$
DECLARE
  cleanup_role oid;
BEGIN
  SELECT oid INTO cleanup_role
  FROM pg_roles
  WHERE rolname = 'sakhi_staging_fixture_cleanup'
    AND rolcanlogin
    AND NOT rolsuper
    AND NOT rolbypassrls
    AND NOT rolcreatedb
    AND NOT rolcreaterole
    AND NOT rolreplication;

  IF cleanup_role IS NULL THEN
    RAISE EXCEPTION 'sakhi_staging_fixture_cleanup must exist as a restricted login role before this migration';
  END IF;

  -- Supabase may grant a custom migration-support role to its managed
  -- postgres role. Permit only that exact administrative membership:
  -- postgres cannot SET ROLE or inherit cleanup privileges, while all other
  -- memberships (including membership granted to another role) remain denied.
  IF EXISTS (
    SELECT 1
    FROM pg_auth_members am
    WHERE am.member = cleanup_role
       OR (
         am.roleid = cleanup_role
         AND NOT (
           EXISTS (SELECT 1 FROM pg_roles p WHERE p.oid = am.member AND p.rolname = 'postgres')
           AND EXISTS (SELECT 1 FROM pg_roles s WHERE s.oid = am.grantor AND s.rolname = 'supabase_admin')
           AND am.admin_option IS TRUE
           AND am.inherit_option IS FALSE
           AND am.set_option IS FALSE
         )
       )
  ) THEN
    RAISE EXCEPTION 'Fixture cleanup role has an unsupported role membership';
  END IF;

  IF NOT has_database_privilege(cleanup_role, current_database(), 'CONNECT')
     OR NOT has_schema_privilege(cleanup_role, 'public', 'USAGE')
     OR has_schema_privilege(cleanup_role, 'public', 'CREATE')
     OR has_database_privilege(cleanup_role, current_database(), 'CREATE') THEN
    RAISE EXCEPTION 'Fixture cleanup role must have CONNECT and schema USAGE only, not CREATE';
  END IF;

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

  IF EXISTS (
    SELECT 1
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relname IN (
        'admin_staff_accounts',
        'admin_staff_sessions',
        'admin_staff_mfa',
        'admin_staff_backup_codes',
        'admin_staff_recovery_requests'
      )
      AND c.relowner = cleanup_role
  ) THEN
    RAISE EXCEPTION 'Fixture cleanup role must never own a P0 staff-security table';
  END IF;

  IF NOT pg_has_role('postgres','sakhi_staging_migrator','SET') THEN
    RAISE EXCEPTION 'Supabase postgres must be able to SET ROLE to the staging migrator for the account-table policy changes';
  END IF;

  IF (SELECT relowner FROM pg_class WHERE oid='public.admin_staff_accounts'::regclass)
       IS DISTINCT FROM (SELECT oid FROM pg_roles WHERE rolname='sakhi_staging_migrator')
     OR EXISTS (
       SELECT 1
       FROM pg_class c
       WHERE c.oid IN (
         'public.admin_staff_sessions'::regclass,
         'public.admin_staff_mfa'::regclass,
         'public.admin_staff_backup_codes'::regclass,
         'public.admin_staff_recovery_requests'::regclass
       )
       AND c.relowner IS DISTINCT FROM (SELECT oid FROM pg_roles WHERE rolname='postgres')
     ) THEN
    RAISE EXCEPTION 'P0 staff tables do not match the reviewed Supabase owner boundary';
  END IF;
END
$fixture_cleanup_role_preflight$;

-- The account table is owned by sakhi_staging_migrator, while the
-- child tables are owned by Supabase postgres. Use the exact existing
-- postgres -> migrator SET membership only for account-table DDL.
SET ROLE sakhi_staging_migrator;

REVOKE ALL ON TABLE public.admin_staff_accounts
  FROM sakhi_staging_fixture_cleanup;

GRANT SELECT (id, email, staff_code)
  ON TABLE public.admin_staff_accounts
  TO sakhi_staging_fixture_cleanup;

GRANT DELETE ON TABLE public.admin_staff_accounts
  TO sakhi_staging_fixture_cleanup;

DO $fixture_cleanup_account_policies$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname='public' AND tablename='admin_staff_accounts'
      AND policyname='admin_staff_accounts_fixture_cleanup_select'
  ) THEN
    CREATE POLICY admin_staff_accounts_fixture_cleanup_select
      ON public.admin_staff_accounts
      FOR SELECT TO sakhi_staging_fixture_cleanup
      USING (email LIKE 'mfa-%@example.test' AND staff_code LIKE 'SYN-MFA-%');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname='public' AND tablename='admin_staff_accounts'
      AND policyname='admin_staff_accounts_fixture_cleanup_delete'
  ) THEN
    CREATE POLICY admin_staff_accounts_fixture_cleanup_delete
      ON public.admin_staff_accounts
      FOR DELETE TO sakhi_staging_fixture_cleanup
      USING (email LIKE 'mfa-%@example.test' AND staff_code LIKE 'SYN-MFA-%');
  END IF;
END
$fixture_cleanup_account_policies$;

RESET ROLE;

-- The four child tables are owned by the Supabase postgres role executing
-- this migration. Keep their cleanup privileges column-scoped and row-filtered.
REVOKE ALL ON TABLE
  public.admin_staff_sessions,
  public.admin_staff_mfa,
  public.admin_staff_backup_codes,
  public.admin_staff_recovery_requests
FROM sakhi_staging_fixture_cleanup;

GRANT DELETE ON TABLE
  public.admin_staff_sessions,
  public.admin_staff_mfa,
  public.admin_staff_backup_codes,
  public.admin_staff_recovery_requests
TO sakhi_staging_fixture_cleanup;

GRANT SELECT (staff_id)
  ON TABLE
    public.admin_staff_sessions,
    public.admin_staff_mfa,
    public.admin_staff_backup_codes,
    public.admin_staff_recovery_requests
TO sakhi_staging_fixture_cleanup;

DO $fixture_cleanup_child_policies$
DECLARE
  item RECORD;
BEGIN
  FOR item IN
    SELECT * FROM (VALUES
      ('admin_staff_sessions'),
      ('admin_staff_mfa'),
      ('admin_staff_backup_codes'),
      ('admin_staff_recovery_requests')
    ) AS child(table_name)
  LOOP
    IF NOT EXISTS (
      SELECT 1 FROM pg_policies
      WHERE schemaname='public'
        AND tablename=item.table_name
        AND policyname=item.table_name || '_fixture_cleanup_select'
    ) THEN
      EXECUTE format(
        'CREATE POLICY %I ON public.%I FOR SELECT TO sakhi_staging_fixture_cleanup USING (EXISTS (SELECT 1 FROM public.admin_staff_accounts a WHERE a.id = %I.staff_id AND a.email LIKE ''mfa-%%@example.test'' AND a.staff_code LIKE ''SYN-MFA-%%''))',
        item.table_name || '_fixture_cleanup_select',
        item.table_name,
        item.table_name
      );
    END IF;

    IF NOT EXISTS (
      SELECT 1 FROM pg_policies
      WHERE schemaname='public'
        AND tablename=item.table_name
        AND policyname=item.table_name || '_fixture_cleanup_delete'
    ) THEN
      EXECUTE format(
        'CREATE POLICY %I ON public.%I FOR DELETE TO sakhi_staging_fixture_cleanup USING (EXISTS (SELECT 1 FROM public.admin_staff_accounts a WHERE a.id = %I.staff_id AND a.email LIKE ''mfa-%%@example.test'' AND a.staff_code LIKE ''SYN-MFA-%%''))',
        item.table_name || '_fixture_cleanup_delete',
        item.table_name,
        item.table_name
      );
    END IF;
  END LOOP;
END
$fixture_cleanup_child_policies$;

DO $fixture_cleanup_postflight$
DECLARE
  item RECORD;
  actual RECORD;
  cleanup_role oid;
BEGIN
  SELECT oid INTO cleanup_role
  FROM pg_roles
  WHERE rolname='sakhi_staging_fixture_cleanup';

  FOR item IN
    SELECT * FROM (VALUES
      ('admin_staff_accounts','admin_staff_accounts_fixture_cleanup_select','SELECT'),
      ('admin_staff_accounts','admin_staff_accounts_fixture_cleanup_delete','DELETE'),
      ('admin_staff_sessions','admin_staff_sessions_fixture_cleanup_select','SELECT'),
      ('admin_staff_sessions','admin_staff_sessions_fixture_cleanup_delete','DELETE'),
      ('admin_staff_mfa','admin_staff_mfa_fixture_cleanup_select','SELECT'),
      ('admin_staff_mfa','admin_staff_mfa_fixture_cleanup_delete','DELETE'),
      ('admin_staff_backup_codes','admin_staff_backup_codes_fixture_cleanup_select','SELECT'),
      ('admin_staff_backup_codes','admin_staff_backup_codes_fixture_cleanup_delete','DELETE'),
      ('admin_staff_recovery_requests','admin_staff_recovery_requests_fixture_cleanup_select','SELECT'),
      ('admin_staff_recovery_requests','admin_staff_recovery_requests_fixture_cleanup_delete','DELETE')
    ) AS p(table_name, policy_name, command)
  LOOP
    SELECT * INTO actual
    FROM pg_policies
    WHERE schemaname='public'
      AND tablename=item.table_name
      AND policyname=item.policy_name;

    IF NOT FOUND
       OR actual.permissive IS DISTINCT FROM 'PERMISSIVE'
       OR actual.roles IS DISTINCT FROM ARRAY['sakhi_staging_fixture_cleanup']::name[]
       OR actual.cmd IS DISTINCT FROM item.command
       OR actual.qual IS NULL
       OR actual.qual NOT LIKE '%mfa-%@example.test%'
       OR actual.qual NOT LIKE '%SYN-MFA-%'
       OR actual.with_check IS NOT NULL THEN
      RAISE EXCEPTION 'Fixture cleanup policy %.% has an unexpected shape',
        item.table_name, item.policy_name;
    END IF;
  END LOOP;

  IF EXISTS (
    SELECT 1 FROM pg_policies p
    WHERE p.schemaname='public'
      AND p.tablename IN (
        'admin_staff_accounts','admin_staff_sessions','admin_staff_mfa',
        'admin_staff_backup_codes','admin_staff_recovery_requests'
      )
      AND 'sakhi_staging_fixture_cleanup'=ANY(p.roles)
      AND p.policyname NOT IN (
        'admin_staff_accounts_fixture_cleanup_select',
        'admin_staff_accounts_fixture_cleanup_delete',
        'admin_staff_sessions_fixture_cleanup_select',
        'admin_staff_sessions_fixture_cleanup_delete',
        'admin_staff_mfa_fixture_cleanup_select',
        'admin_staff_mfa_fixture_cleanup_delete',
        'admin_staff_backup_codes_fixture_cleanup_select',
        'admin_staff_backup_codes_fixture_cleanup_delete',
        'admin_staff_recovery_requests_fixture_cleanup_select',
        'admin_staff_recovery_requests_fixture_cleanup_delete'
      )
  ) THEN
    RAISE EXCEPTION 'Unexpected fixture-cleanup policy exists on a P0 table';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_class c
    JOIN pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname='public'
      AND c.relname IN (
        'admin_staff_accounts','admin_staff_sessions','admin_staff_mfa',
        'admin_staff_backup_codes','admin_staff_recovery_requests'
      )
      AND (
        c.relowner=cleanup_role
        OR has_table_privilege(cleanup_role,c.oid,'TRUNCATE')
      )
  ) THEN
    RAISE EXCEPTION 'Fixture cleanup role must not own or truncate P0 staff-security tables';
  END IF;

  IF has_table_privilege(cleanup_role,'public.admin_staff_sessions','SELECT')
     OR has_table_privilege(cleanup_role,'public.admin_staff_mfa','SELECT')
     OR has_table_privilege(cleanup_role,'public.admin_staff_backup_codes','SELECT')
     OR has_table_privilege(cleanup_role,'public.admin_staff_recovery_requests','SELECT')
     OR NOT has_column_privilege(cleanup_role,'public.admin_staff_accounts','id','SELECT')
     OR NOT has_column_privilege(cleanup_role,'public.admin_staff_accounts','email','SELECT')
     OR NOT has_column_privilege(cleanup_role,'public.admin_staff_accounts','staff_code','SELECT')
     OR NOT has_column_privilege(cleanup_role,'public.admin_staff_sessions','staff_id','SELECT')
     OR NOT has_column_privilege(cleanup_role,'public.admin_staff_mfa','staff_id','SELECT')
     OR NOT has_column_privilege(cleanup_role,'public.admin_staff_backup_codes','staff_id','SELECT')
     OR NOT has_column_privilege(cleanup_role,'public.admin_staff_recovery_requests','staff_id','SELECT') THEN
    RAISE EXCEPTION 'Fixture cleanup role SELECT privileges are broader or narrower than the required column-scoped access';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM (VALUES
      ('admin_staff_accounts'),('admin_staff_sessions'),('admin_staff_mfa'),
      ('admin_staff_backup_codes'),('admin_staff_recovery_requests')
    ) AS t(table_name)
    WHERE NOT has_table_privilege(cleanup_role,format('public.%I',t.table_name),'DELETE')
  ) THEN
    RAISE EXCEPTION 'Fixture cleanup role is missing a required DELETE grant';
  END IF;

  -- Table-level REVOKE does not remove independent column grants. Fail closed
  -- if any column privilege exists outside the exact fixture metadata needed
  -- for the row-filtered policies and cleanup queries.
  IF EXISTS (
    SELECT 1
    FROM pg_attribute a
    JOIN pg_class c ON c.oid = a.attrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relname IN (
        'admin_staff_accounts','admin_staff_sessions','admin_staff_mfa',
        'admin_staff_backup_codes','admin_staff_recovery_requests'
      )
      AND a.attnum > 0
      AND NOT a.attisdropped
      AND (
        has_column_privilege(cleanup_role,c.oid,a.attname,'INSERT')
        OR has_column_privilege(cleanup_role,c.oid,a.attname,'UPDATE')
        OR has_column_privilege(cleanup_role,c.oid,a.attname,'REFERENCES')
        OR (
          has_column_privilege(cleanup_role,c.oid,a.attname,'SELECT')
          AND NOT (
            (c.relname = 'admin_staff_accounts'
              AND a.attname IN ('id','email','staff_code'))
            OR
            (c.relname IN (
              'admin_staff_sessions','admin_staff_mfa',
              'admin_staff_backup_codes','admin_staff_recovery_requests'
            ) AND a.attname = 'staff_id')
          )
        )
      )
  ) THEN
    RAISE EXCEPTION 'Fixture cleanup role has an unexpected column-level privilege';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_auth_members am
    WHERE am.member = cleanup_role
       OR (
         am.roleid = cleanup_role
         AND NOT (
           EXISTS (SELECT 1 FROM pg_roles p WHERE p.oid = am.member AND p.rolname = 'postgres')
           AND EXISTS (SELECT 1 FROM pg_roles s WHERE s.oid = am.grantor AND s.rolname = 'supabase_admin')
           AND am.admin_option IS TRUE
           AND am.inherit_option IS FALSE
           AND am.set_option IS FALSE
         )
       )
  ) THEN
    RAISE EXCEPTION 'Fixture cleanup role has an unsupported role membership';
  END IF;
END
$fixture_cleanup_postflight$;

COMMIT;
