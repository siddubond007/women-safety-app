BEGIN;

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

  -- Every table touched by the retention/deletion runtime grant set must
  -- remain protected by forced RLS, with its expected owner/participant or
  -- backend-only policy still installed. Checking only discreet_complaints
  -- would leave the other seven lifecycle tables without a postflight gate.
  IF EXISTS (
    SELECT 1
    FROM (VALUES
      ('discreet_complaints'),
      ('member_communication_preferences'),
      ('eligibility_submissions'),
      ('business_directory_listings'),
      ('business_enquiries'),
      ('direct_messages'),
      ('safety_location_shares'),
      ('business_reports')
    ) AS expected(table_name)
    LEFT JOIN pg_class c
      ON c.relnamespace='public'::regnamespace
     AND c.relname=expected.table_name
    WHERE c.oid IS NULL OR NOT c.relrowsecurity OR NOT c.relforcerowsecurity
  ) THEN
    RAISE EXCEPTION 'All eight retention/deletion lifecycle tables must exist with enabled and forced RLS';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM (VALUES
      ('discreet_complaints','discreet_complaints_sakhi_backend_only','ALL'),
      ('member_communication_preferences','member_communication_preferences_owner_only','ALL'),
      ('eligibility_submissions','eligibility_submissions_owner_or_verification_admin','ALL'),
      ('business_directory_listings','business_directory_listings_owner_or_business_admin','ALL'),
      ('business_directory_listings','business_directory_listings_public_read','SELECT'),
      ('business_enquiries','business_enquiries_participants_or_admin','ALL'),
      ('direct_messages','direct_messages_participants_only','ALL'),
      ('safety_location_shares','safety_location_shares_owner_only','ALL'),
      ('business_reports','business_reports_reporter_or_admin','ALL')
    ) AS expected(table_name, policy_name, policy_command)
    LEFT JOIN pg_policies p
      ON p.schemaname='public'
     AND p.tablename=expected.table_name
     AND p.policyname=expected.policy_name
     AND p.cmd=expected.policy_command
    WHERE p.policyname IS NULL
  ) THEN
    RAISE EXCEPTION 'One or more required lifecycle RLS policies are missing or have an unexpected command';
  END IF;
END
$retention_deletion_runtime_postflight$;

COMMIT;
