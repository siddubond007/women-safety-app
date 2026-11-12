-- Stage D: close additional member-owned verification and audit-data gaps.
-- Complaint passkey access and provider callbacks are deliberately excluded
-- until their service paths carry a dedicated, verifiable transaction context.

ALTER TABLE public.eligibility_consents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.eligibility_consents FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS eligibility_consents_owner_only ON public.eligibility_consents;
CREATE POLICY eligibility_consents_owner_only ON public.eligibility_consents
  FOR ALL TO PUBLIC
  USING (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app')
    AND account_id=NULLIF(current_setting('app.account_id',true),'')::uuid)
  WITH CHECK (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app')
    AND account_id=NULLIF(current_setting('app.account_id',true),'')::uuid);

ALTER TABLE public.eligibility_support_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.eligibility_support_requests FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS eligibility_support_requests_owner_only ON public.eligibility_support_requests;
CREATE POLICY eligibility_support_requests_owner_only ON public.eligibility_support_requests
  FOR ALL TO PUBLIC
  USING (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app')
    AND account_id=NULLIF(current_setting('app.account_id',true),'')::uuid)
  WITH CHECK (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app')
    AND account_id=NULLIF(current_setting('app.account_id',true),'')::uuid);

ALTER TABLE public.eligibility_verification_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.eligibility_verification_sessions FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS eligibility_verification_sessions_owner_only ON public.eligibility_verification_sessions;
CREATE POLICY eligibility_verification_sessions_owner_only ON public.eligibility_verification_sessions
  FOR ALL TO PUBLIC
  USING (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app')
    AND account_id=NULLIF(current_setting('app.account_id',true),'')::uuid)
  WITH CHECK (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app')
    AND account_id=NULLIF(current_setting('app.account_id',true),'')::uuid);

ALTER TABLE public.audit_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_events FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS audit_events_member_or_admin_insert ON public.audit_events;
DROP POLICY IF EXISTS audit_events_admin_read ON public.audit_events;
CREATE POLICY audit_events_member_or_admin_insert ON public.audit_events
  FOR INSERT TO PUBLIC
  WITH CHECK (
    current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app')
    AND (
      (actor_type='MEMBER' AND actor_id=NULLIF(current_setting('app.account_id',true),'')::uuid)
      OR (NULLIF(current_setting('app.admin_staff_id',true),'') IS NOT NULL
          AND NULLIF(current_setting('app.admin_role',true),'') IS NOT NULL)
    )
  );
CREATE POLICY audit_events_admin_read ON public.audit_events
  FOR SELECT TO PUBLIC
  USING (
    current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app')
    AND NULLIF(current_setting('app.admin_staff_id',true),'') IS NOT NULL
    AND NULLIF(current_setting('app.admin_role',true),'') IS NOT NULL
  );

ALTER TABLE public.moderation_decisions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.moderation_decisions FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS moderation_decisions_admin_only ON public.moderation_decisions;
CREATE POLICY moderation_decisions_admin_only ON public.moderation_decisions
  FOR ALL TO PUBLIC
  USING (
    current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app')
    AND NULLIF(current_setting('app.admin_staff_id',true),'') IS NOT NULL
    AND current_setting('app.admin_role',true) IN ('SUPER_ADMIN','CONTENT_MODERATOR','COMPLAINT_REVIEWER','VERIFICATION_ADMIN')
  )
  WITH CHECK (
    current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app')
    AND NULLIF(current_setting('app.admin_staff_id',true),'') IS NOT NULL
    AND current_setting('app.admin_role',true) IN ('SUPER_ADMIN','CONTENT_MODERATOR','COMPLAINT_REVIEWER','VERIFICATION_ADMIN')
  );

-- Admin credential tables are backend-only and already have role-scoped grants.
-- Force the existing RLS boundary to apply even if a runtime role ever owns a table.
DO $admin_security_force_rls$
DECLARE table_name text;
BEGIN
  FOREACH table_name IN ARRAY ARRAY[
    'admin_staff_accounts','admin_staff_sessions','admin_staff_mfa',
    'admin_staff_backup_codes','admin_staff_recovery_requests','admin_auth_sessions'
  ] LOOP
    IF to_regclass(format('public.%I',table_name)) IS NOT NULL THEN
      EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY',table_name);
      EXECUTE format('ALTER TABLE public.%I FORCE ROW LEVEL SECURITY',table_name);
    END IF;
  END LOOP;
END
$admin_security_force_rls$;

DO $stage_d_aux_postflight$
DECLARE table_name text;
BEGIN
  FOREACH table_name IN ARRAY ARRAY[
    'eligibility_consents','eligibility_support_requests',
    'eligibility_verification_sessions','audit_events','moderation_decisions',
    'admin_staff_accounts','admin_staff_sessions','admin_staff_mfa',
    'admin_staff_backup_codes','admin_staff_recovery_requests','admin_auth_sessions'
  ] LOOP
    IF NOT EXISTS (
      SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
      WHERE n.nspname='public' AND c.relname=table_name
        AND c.relrowsecurity AND c.relforcerowsecurity
    ) THEN
      RAISE EXCEPTION 'Stage D requires forced RLS on public.%',table_name;
    END IF;
  END LOOP;
END
$stage_d_aux_postflight$;

-- Keep dev/test/staging runtime privileges aligned. The dev role is the source
-- of truth for the backend's existing table-level grant contract; policies
-- above then constrain rows independently for each role.
DO $stage_d_runtime_grants$
DECLARE target_role text;
DECLARE grant_row RECORD;
BEGIN
  FOREACH target_role IN ARRAY ARRAY['sakhi_test_app','sakhi_staging_app'] LOOP
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname=target_role) THEN
      EXECUTE format('GRANT USAGE ON SCHEMA public TO %I',target_role);
      FOR grant_row IN
        SELECT table_name,privilege_type
        FROM information_schema.role_table_grants
        WHERE table_schema='public' AND grantee='sakhi_dev_app'
      LOOP
        EXECUTE format('GRANT %s ON TABLE public.%I TO %I',
          grant_row.privilege_type,grant_row.table_name,target_role);
      END LOOP;
      FOR grant_row IN
        SELECT object_name AS sequence_name,privilege_type
        FROM information_schema.role_usage_grants
        WHERE object_schema='public' AND grantee='sakhi_dev_app'
          AND object_type='SEQUENCE'
      LOOP
        EXECUTE format('GRANT %s ON SEQUENCE public.%I TO %I',
          grant_row.privilege_type,grant_row.sequence_name,target_role);
      END LOOP;
    END IF;
  END LOOP;
END
$stage_d_runtime_grants$;
