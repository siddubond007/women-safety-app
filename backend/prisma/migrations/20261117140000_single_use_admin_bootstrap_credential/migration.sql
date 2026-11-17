BEGIN;

DO $bootstrap_preflight$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_roles
    WHERE rolname = 'sakhi_staging_app'
      AND rolcanlogin
      AND NOT rolsuper
      AND NOT rolbypassrls
      AND NOT rolcreatedb
      AND NOT rolcreaterole
      AND NOT rolreplication
  ) THEN
    RAISE EXCEPTION 'sakhi_staging_app is missing or has excessive privileges';
  END IF;
END
$bootstrap_preflight$;

CREATE TABLE public.admin_bootstrap_credentials (
  id varchar(64) PRIMARY KEY,
  token_digest varchar(64) NOT NULL,
  expires_at timestamptz(6) NOT NULL,
  consumed_at timestamptz(6),
  created_at timestamptz(6) NOT NULL DEFAULT now(),
  CONSTRAINT admin_bootstrap_credentials_singleton_check
    CHECK (id = 'initial-super-admin'),
  CONSTRAINT admin_bootstrap_credentials_digest_check
    CHECK (token_digest ~ '^[0-9a-f]{64}$'),
  CONSTRAINT admin_bootstrap_credentials_expiry_check
    CHECK (expires_at > created_at),
  CONSTRAINT admin_bootstrap_credentials_consumed_check
    CHECK (consumed_at IS NULL OR consumed_at >= created_at)
);

ALTER TABLE public.admin_bootstrap_credentials ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_bootstrap_credentials FORCE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.admin_bootstrap_credentials FROM PUBLIC;

DO $bootstrap_role_revocations$
DECLARE
  role_name text;
BEGIN
  FOREACH role_name IN ARRAY ARRAY['anon', 'authenticated', 'service_role'] LOOP
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = role_name) THEN
      EXECUTE format(
        'REVOKE ALL ON TABLE public.admin_bootstrap_credentials FROM %I',
        role_name
      );
    END IF;
  END LOOP;
END
$bootstrap_role_revocations$;
GRANT SELECT, INSERT, UPDATE ON TABLE public.admin_bootstrap_credentials TO sakhi_staging_app;

CREATE POLICY admin_bootstrap_credentials_select
  ON public.admin_bootstrap_credentials
  FOR SELECT TO sakhi_staging_app
  USING (id = 'initial-super-admin');

CREATE POLICY admin_bootstrap_credentials_insert
  ON public.admin_bootstrap_credentials
  FOR INSERT TO sakhi_staging_app
  WITH CHECK (
    id = 'initial-super-admin'
    AND consumed_at IS NULL
    AND expires_at > now()
  );

CREATE POLICY admin_bootstrap_credentials_consume
  ON public.admin_bootstrap_credentials
  FOR UPDATE TO sakhi_staging_app
  USING (
    id = 'initial-super-admin'
    AND consumed_at IS NULL
    AND expires_at > now()
  )
  WITH CHECK (
    id = 'initial-super-admin'
    AND consumed_at IS NOT NULL
  );

CREATE FUNCTION public.guard_admin_bootstrap_credential_consumption()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
BEGIN
  IF OLD.id IS DISTINCT FROM NEW.id
     OR OLD.token_digest IS DISTINCT FROM NEW.token_digest
     OR OLD.expires_at IS DISTINCT FROM NEW.expires_at
     OR OLD.created_at IS DISTINCT FROM NEW.created_at
     OR OLD.consumed_at IS NOT NULL
     OR NEW.consumed_at IS NULL THEN
    RAISE EXCEPTION 'The initial Super Admin bootstrap credential is immutable except for one-way consumption';
  END IF;
  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION public.guard_admin_bootstrap_credential_consumption() FROM PUBLIC;

DO $bootstrap_function_revocations$
DECLARE
  role_name text;
BEGIN
  FOREACH role_name IN ARRAY ARRAY['anon', 'authenticated', 'service_role'] LOOP
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = role_name) THEN
      EXECUTE format(
        'REVOKE ALL ON FUNCTION public.guard_admin_bootstrap_credential_consumption() FROM %I',
        role_name
      );
    END IF;
  END LOOP;
END
$bootstrap_function_revocations$;

CREATE TRIGGER admin_bootstrap_credentials_one_way_consumption
  BEFORE UPDATE ON public.admin_bootstrap_credentials
  FOR EACH ROW
  EXECUTE FUNCTION public.guard_admin_bootstrap_credential_consumption();

DO $bootstrap_postflight$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relname = 'admin_bootstrap_credentials'
      AND c.relrowsecurity
      AND c.relforcerowsecurity
  ) THEN
    RAISE EXCEPTION 'Bootstrap credential table must have enabled and forced RLS';
  END IF;

  IF has_table_privilege('sakhi_staging_app', 'public.admin_bootstrap_credentials', 'DELETE')
     OR NOT has_table_privilege('sakhi_staging_app', 'public.admin_bootstrap_credentials', 'SELECT')
     OR NOT has_table_privilege('sakhi_staging_app', 'public.admin_bootstrap_credentials', 'INSERT')
     OR NOT has_table_privilege('sakhi_staging_app', 'public.admin_bootstrap_credentials', 'UPDATE') THEN
    RAISE EXCEPTION 'Bootstrap credential grants are broader or narrower than intended';
  END IF;

  -- Supabase roles are not present in the isolated vanilla PostgreSQL CI
  -- database. Verify them when present, without making migration portability
  -- depend on Supabase-managed role creation.
  FOR role_name IN
    SELECT rolname FROM pg_roles
    WHERE rolname IN ('anon', 'authenticated', 'service_role')
  LOOP
    IF has_table_privilege(role_name, 'public.admin_bootstrap_credentials', 'SELECT')
       OR has_table_privilege(role_name, 'public.admin_bootstrap_credentials', 'INSERT')
       OR has_table_privilege(role_name, 'public.admin_bootstrap_credentials', 'UPDATE')
       OR has_table_privilege(role_name, 'public.admin_bootstrap_credentials', 'DELETE') THEN
      RAISE EXCEPTION 'Bootstrap credential table is exposed to role %', role_name;
    END IF;
  END LOOP;
END
$bootstrap_postflight$;

COMMIT;
