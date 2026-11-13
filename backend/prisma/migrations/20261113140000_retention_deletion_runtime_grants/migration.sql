-- Supply only the missing backend privileges required by Module 5 complaint
-- processing and the account-erasure/retention lifecycle. RLS remains enabled
-- and forced; no grants are made to anon/authenticated client roles.
DO $retention_deletion_runtime_grants$
DECLARE
  runtime_role text;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='sakhi_staging_app') THEN
    RAISE EXCEPTION 'Retention/deletion runtime grants require sakhi_staging_app';
  END IF;

  FOREACH runtime_role IN ARRAY ARRAY[
    'sakhi_dev_app',
    'sakhi_test_app',
    'sakhi_staging_app'
  ] LOOP
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname=runtime_role) THEN
      EXECUTE format(
        'GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.discreet_complaints TO %I',
        runtime_role
      );
      EXECUTE format(
        'GRANT DELETE ON TABLE public.member_communication_preferences, public.eligibility_submissions TO %I',
        runtime_role
      );
      EXECUTE format(
        'GRANT SELECT, DELETE ON TABLE public.business_directory_listings, public.business_enquiries, public.direct_messages, public.safety_location_shares TO %I',
        runtime_role
      );
      EXECUTE format(
        'GRANT SELECT, UPDATE ON TABLE public.business_reports TO %I',
        runtime_role
      );
    END IF;
  END LOOP;
END
$retention_deletion_runtime_grants$;

DO $retention_deletion_runtime_postflight$
DECLARE
  runtime_role text;
BEGIN
  FOREACH runtime_role IN ARRAY ARRAY[
    'sakhi_dev_app',
    'sakhi_test_app',
    'sakhi_staging_app'
  ] LOOP
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname=runtime_role) THEN
      IF NOT (
        has_table_privilege(runtime_role, 'public.discreet_complaints', 'SELECT')
        AND has_table_privilege(runtime_role, 'public.discreet_complaints', 'INSERT')
        AND has_table_privilege(runtime_role, 'public.discreet_complaints', 'UPDATE')
        AND has_table_privilege(runtime_role, 'public.discreet_complaints', 'DELETE')
        AND has_table_privilege(runtime_role, 'public.member_communication_preferences', 'DELETE')
        AND has_table_privilege(runtime_role, 'public.business_directory_listings', 'SELECT')
        AND has_table_privilege(runtime_role, 'public.business_directory_listings', 'DELETE')
        AND has_table_privilege(runtime_role, 'public.business_enquiries', 'SELECT')
        AND has_table_privilege(runtime_role, 'public.business_enquiries', 'DELETE')
        AND has_table_privilege(runtime_role, 'public.direct_messages', 'SELECT')
        AND has_table_privilege(runtime_role, 'public.direct_messages', 'DELETE')
        AND has_table_privilege(runtime_role, 'public.eligibility_submissions', 'DELETE')
        AND has_table_privilege(runtime_role, 'public.safety_location_shares', 'SELECT')
        AND has_table_privilege(runtime_role, 'public.safety_location_shares', 'DELETE')
        AND has_table_privilege(runtime_role, 'public.business_reports', 'SELECT')
        AND has_table_privilege(runtime_role, 'public.business_reports', 'UPDATE')
      ) THEN
        RAISE EXCEPTION 'Required retention/deletion privileges are incomplete for %', runtime_role;
      END IF;
    END IF;
  END LOOP;

  IF NOT EXISTS (
    SELECT 1 FROM pg_class c
    JOIN pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname='public'
      AND c.relname='discreet_complaints'
      AND c.relrowsecurity
      AND c.relforcerowsecurity
  ) THEN
    RAISE EXCEPTION 'discreet_complaints must retain enabled and forced RLS';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname='public'
      AND tablename='discreet_complaints'
      AND policyname='discreet_complaints_sakhi_backend_only'
      AND cmd='ALL'
  ) THEN
    RAISE EXCEPTION 'The backend-only discreet_complaints RLS policy is required';
  END IF;
END
$retention_deletion_runtime_postflight$;
