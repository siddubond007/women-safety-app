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

  -- Validate the effective policy shape. Permissive policies are OR-combined,
  -- so unexpected additional policies or weakened USING/WITH CHECK expressions
  -- would broaden access even when the expected policy name still exists.
  DECLARE
    expected RECORD;
    actual_policy RECORD;
    required_token text;
  BEGIN
    FOR expected IN
      SELECT * FROM (VALUES
        ('discreet_complaints','discreet_complaints_sakhi_backend_only','ALL','38bbe0a38d8c81387fece45c70ba7240','38bbe0a38d8c81387fece45c70ba7240',
          ARRAY['current_user','sakhi_dev_app','sakhi_test_app','sakhi_staging_app']::text[],
          ARRAY['current_user','sakhi_dev_app','sakhi_test_app','sakhi_staging_app']::text[]),
        ('member_communication_preferences','member_communication_preferences_owner_only','ALL','1def17443af834ca7530bc43a8d088f2','1def17443af834ca7530bc43a8d088f2',
          ARRAY['current_user','sakhi_staging_app','account_id','app.account_id']::text[],
          ARRAY['current_user','sakhi_staging_app','account_id','app.account_id']::text[]),
        ('eligibility_submissions','eligibility_submissions_owner_or_verification_admin','ALL','3678314d557bd3349f517685d467c821','3678314d557bd3349f517685d467c821',
          ARRAY['current_user','account_id','app.account_id','admin_staff_id','admin_role','verification_admin']::text[],
          ARRAY['current_user','account_id','app.account_id','admin_staff_id','admin_role','verification_admin']::text[]),
        ('business_directory_listings','business_directory_listings_owner_or_business_admin','ALL','bf0eb46b172a17675eac2ae3951292d5','bf0eb46b172a17675eac2ae3951292d5',
          ARRAY['current_user','owner_account_id','app.account_id','admin_staff_id','admin_role','business_admin']::text[],
          ARRAY['current_user','owner_account_id','app.account_id','admin_staff_id','admin_role','business_admin']::text[]),
        ('business_directory_listings','business_directory_listings_public_read','SELECT','998dae311deac48870e5d19e425eec61','d41d8cd98f00b204e9800998ecf8427e',
          ARRAY['current_user','account_id','app.account_id','approval_status','approved','is_reported_fraudulent']::text[],
          ARRAY[]::text[]),
        ('business_enquiries','business_enquiries_participants_or_admin','ALL','6902b35b3fdaf17a74bf67f6b956f647','6902b35b3fdaf17a74bf67f6b956f647',
          ARRAY['current_user','sender_account_id','owner_account_id','app.account_id','admin_staff_id','admin_role','business_admin']::text[],
          ARRAY['current_user','sender_account_id','owner_account_id','app.account_id','admin_staff_id','admin_role','business_admin']::text[]),
        ('direct_messages','direct_messages_participants_only','ALL','8995429c63e39d5a46d110562a710842','8995429c63e39d5a46d110562a710842',
          ARRAY['current_user','sender_account_id','recipient_account_id','app.account_id']::text[],
          ARRAY['current_user','sender_account_id','recipient_account_id','app.account_id']::text[]),
        ('safety_location_shares','safety_location_shares_owner_only','ALL','1def17443af834ca7530bc43a8d088f2','1def17443af834ca7530bc43a8d088f2',
          ARRAY['current_user','account_id','app.account_id']::text[],
          ARRAY['current_user','account_id','app.account_id']::text[]),
        ('business_reports','business_reports_reporter_or_admin','ALL','a8d78b5638b34c08def851a01f0cd149','a8d78b5638b34c08def851a01f0cd149',
          ARRAY['current_user','reporter_account_id','app.account_id','admin_staff_id','admin_role','business_admin']::text[],
          ARRAY['current_user','reporter_account_id','app.account_id','admin_staff_id','admin_role','business_admin']::text[])
      ) AS policies(table_name, policy_name, policy_command, qual_hash, check_hash, qual_tokens, check_tokens)
    LOOP
      SELECT * INTO actual_policy
      FROM pg_policies
      WHERE schemaname='public'
        AND tablename=expected.table_name
        AND policyname=expected.policy_name;
      IF NOT FOUND
         OR actual_policy.permissive IS DISTINCT FROM 'PERMISSIVE'
         OR actual_policy.roles IS DISTINCT FROM ARRAY['public']::name[]
         OR actual_policy.cmd IS DISTINCT FROM expected.policy_command
         OR actual_policy.qual IS NULL
         OR (expected.policy_command='ALL' AND actual_policy.with_check IS NULL)
         OR (expected.policy_command='SELECT' AND actual_policy.with_check IS NOT NULL)
         OR md5(lower(regexp_replace(COALESCE(actual_policy.qual,''), '[[:space:]]+', '', 'g'))) <> expected.qual_hash
         OR md5(lower(regexp_replace(COALESCE(actual_policy.with_check,''), '[[:space:]]+', '', 'g'))) <> expected.check_hash THEN
        RAISE EXCEPTION 'Lifecycle RLS policy %.% has an unexpected mode, role, command, or predicate shape', expected.table_name, expected.policy_name;
      END IF;
      FOREACH required_token IN ARRAY expected.qual_tokens LOOP
        IF position(lower(required_token) IN lower(actual_policy.qual)) = 0 THEN
          RAISE EXCEPTION 'Lifecycle RLS policy %.% is missing required USING predicate token %', expected.table_name, expected.policy_name, required_token;
        END IF;
      END LOOP;
      FOREACH required_token IN ARRAY expected.check_tokens LOOP
        IF position(lower(required_token) IN lower(COALESCE(actual_policy.with_check,''))) = 0 THEN
          RAISE EXCEPTION 'Lifecycle RLS policy %.% is missing required WITH CHECK predicate token %', expected.table_name, expected.policy_name, required_token;
        END IF;
      END LOOP;
    END LOOP;
  END;

  IF EXISTS (
    SELECT 1 FROM pg_policies p
    WHERE p.schemaname='public'
      AND p.tablename IN (
        'discreet_complaints','member_communication_preferences','eligibility_submissions',
        'business_directory_listings','business_enquiries','direct_messages',
        'safety_location_shares','business_reports'
      )
      AND p.permissive='PERMISSIVE'
      AND p.roles && ARRAY['public','sakhi_dev_app','sakhi_test_app','sakhi_staging_app']::name[]
      AND NOT (
        (p.tablename='discreet_complaints' AND p.policyname='discreet_complaints_sakhi_backend_only') OR
        (p.tablename='member_communication_preferences' AND p.policyname='member_communication_preferences_owner_only') OR
        (p.tablename='eligibility_submissions' AND p.policyname='eligibility_submissions_owner_or_verification_admin') OR
        (p.tablename='business_directory_listings' AND p.policyname IN ('business_directory_listings_owner_or_business_admin','business_directory_listings_public_read')) OR
        (p.tablename='business_enquiries' AND p.policyname='business_enquiries_participants_or_admin') OR
        (p.tablename='direct_messages' AND p.policyname='direct_messages_participants_only') OR
        (p.tablename='safety_location_shares' AND p.policyname='safety_location_shares_owner_only') OR
        (p.tablename='business_reports' AND p.policyname='business_reports_reporter_or_admin')
      )
  ) THEN
    RAISE EXCEPTION 'Unexpected permissive lifecycle RLS policy may broaden runtime access';
  END IF;
END
$retention_deletion_runtime_postflight$;

COMMIT;
