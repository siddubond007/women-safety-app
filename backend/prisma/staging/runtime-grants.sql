-- Least-privilege runtime grants for Sakhi Modules 1-12.
-- Run as sakhi_staging_migrator after baseline setup.
-- P0 staff-security policies are permissive only for this backend-only runtime
-- role. This is NOT staff-row isolation. The role must not be exposed to
-- clients, must not own these tables, and must have NOBYPASSRLS.
GRANT USAGE ON SCHEMA public TO sakhi_staging_app;

-- Authentication, profiles, sessions, and communication settings.
GRANT SELECT, INSERT, UPDATE ON TABLE
  public.member_accounts,
  public.member_profiles,
  public.otp_challenges,
  public.member_consents,
  public.auth_sessions,
  public.member_communication_preferences,
  public.platform_registration_policies
TO sakhi_staging_app;
GRANT SELECT ON TABLE public.policy_document_versions TO sakhi_staging_app;
GRANT INSERT, SELECT ON TABLE public.audit_events TO sakhi_staging_app;

-- Module 2 & 8 dedicated DM persistence. Column-level UPDATE only on read_at and request_status; no DELETE access.
GRANT SELECT, INSERT ON TABLE public.direct_messages TO sakhi_staging_app;
GRANT UPDATE ("read_at", "request_status") ON TABLE public.direct_messages TO sakhi_staging_app;

-- Explicit eligibility/manual-review request records; no raw evidence tables exist.
GRANT SELECT, INSERT, UPDATE ON TABLE
  public.eligibility_consents,
  public.eligibility_verification_sessions,
  public.eligibility_submissions
TO sakhi_staging_app;
GRANT SELECT, INSERT ON TABLE
  public.eligibility_support_requests,
  public.eligibility_provider_callback_events
TO sakhi_staging_app;

-- Module 2 & 8 profile, social preferences, notifications, wellness, and safety domain.
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE
  public.community_posts,
  public.community_post_likes,
  public.community_post_saves,
  public.community_post_comments,
  public.community_groups,
  public.community_directory_profiles,
  public.member_follows,
  public.member_privacy_preferences,
  public.member_notification_preferences,
  public.member_notifications,
  public.safety_emergency_contacts,
  public.safety_sos_events,
  public.safety_location_shares,
  public.safety_helpline_configs,
  public.verified_police_stations,
  public.wellness_resources,
  public.member_moderation_blocks,
  public.member_user_reports
TO sakhi_staging_app;

-- Module 3 social wall, media metadata, feed categories, and moderation.
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE
  public.feed_category_configs,
  public.media_assets,
  public.community_post_reactions,
  public.moderation_decisions
TO sakhi_staging_app;

-- Module 5 discreet complaints: allow durable complaint submission and review.
-- Do not grant DELETE on complaints; retention/purge must use explicit audited workflows.
GRANT SELECT, INSERT, UPDATE ON TABLE
  public.discreet_complaints
TO sakhi_staging_app;

-- Complaint categories and retention controls are read during startup and updated
-- only by the application service's validated configuration paths.
GRANT SELECT, INSERT, UPDATE ON TABLE
  public.complaint_category_configs,
  public.complaint_retention_policies
TO sakhi_staging_app;

-- Module 10/11 admin RBAC and platform configuration persistence.
-- Staff accounts are soft-deleted; the runtime role must not physically DELETE.
GRANT SELECT, INSERT, UPDATE ON TABLE
  public.admin_staff_accounts,
  public.admin_staff_sessions,
  public.admin_staff_mfa,
  public.admin_staff_backup_codes,
  public.admin_staff_recovery_requests
TO sakhi_staging_app;
REVOKE DELETE, TRUNCATE, REFERENCES, TRIGGER ON TABLE
  public.admin_staff_accounts,
  public.admin_staff_sessions,
  public.admin_staff_mfa,
  public.admin_staff_backup_codes,
  public.admin_staff_recovery_requests
FROM sakhi_staging_app;

DO $$
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
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', table_name);
    EXECUTE format('ALTER TABLE public.%I FORCE ROW LEVEL SECURITY', table_name);
    policy_name := table_name || '_runtime_sakhi_staging_app';
    IF EXISTS (
      SELECT 1 FROM pg_policies
      WHERE schemaname = 'public'
        AND tablename = table_name
        AND policyname = policy_name
        AND (qual <> 'true' OR with_check <> 'true')
    ) THEN
      RAISE EXCEPTION 'Existing P0 runtime policy % has an incompatible expression.', policy_name;
    END IF;
    IF NOT EXISTS (
      SELECT 1 FROM pg_policies
      WHERE schemaname = 'public'
        AND tablename = table_name
        AND policyname = policy_name
    ) THEN
      EXECUTE format(
        'CREATE POLICY %I ON public.%I FOR ALL TO sakhi_staging_app USING (true) WITH CHECK (true)',
        policy_name,
        table_name
      );
    END IF;
  END LOOP;
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN
    REVOKE ALL ON TABLE
      public.admin_staff_accounts,
      public.admin_staff_sessions,
      public.admin_staff_mfa,
      public.admin_staff_backup_codes,
      public.admin_staff_recovery_requests
    FROM service_role;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'sakhi_staging_app') THEN
    ALTER ROLE sakhi_staging_app NOSUPERUSER NOBYPASSRLS NOCREATEDB NOCREATEROLE;
  END IF;
  IF EXISTS (
    SELECT 1 FROM pg_class c
    JOIN pg_roles r ON r.oid = c.relowner
    WHERE c.relnamespace = 'public'::regnamespace
      AND c.relname IN ('admin_staff_accounts','admin_staff_sessions','admin_staff_mfa','admin_staff_backup_codes','admin_staff_recovery_requests')
      AND r.rolname = 'sakhi_staging_app'
  ) THEN
    RAISE EXCEPTION 'sakhi_staging_app must not own P0 staff-security tables.';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role')
     AND (
       has_table_privilege('service_role','public.admin_staff_accounts','SELECT')
       OR has_table_privilege('service_role','public.admin_staff_sessions','SELECT')
       OR has_table_privilege('service_role','public.admin_staff_mfa','SELECT')
       OR has_table_privilege('service_role','public.admin_staff_backup_codes','SELECT')
       OR has_table_privilege('service_role','public.admin_staff_recovery_requests','SELECT')
     ) THEN
    RAISE EXCEPTION 'service_role retains effective SELECT access to P0 staff-security tables.';
  END IF;
END $$;

GRANT SELECT, INSERT, UPDATE ON TABLE
  public.business_directory_listings,
  public.business_enquiries,
  public.business_reports,
  public.platform_config_settings
TO sakhi_staging_app;

-- UUID-backed tables do not require sequence privileges. Do not grant blanket
-- access to current or future public-schema sequences.
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM sakhi_staging_app;
GRANT USAGE ON TYPE
  public.account_status,
  public.verification_status,
  public.eligibility_submission_status,
  public.otp_purpose,
  public.policy_document_type,
  public.policy_document_status,
  public.eligibility_verification_status,
  public.eligibility_verification_session_status,
  public.eligibility_support_request_category,
  public.eligibility_support_request_status,
  public.eligibility_provider_callback_outcome
TO sakhi_staging_app;
-- The bootstrap-roles.sql setup grants the runtime role USAGE only (not CREATE)
-- on public. Leave schema ACL ownership changes to the Supabase project owner.
REVOKE ALL ON TABLE public._prisma_migrations FROM sakhi_staging_app;

-- Module 7 menstrual health tables. These grants are backend-only and do NOT
-- establish per-member row isolation. Do not claim RLS protection until
-- member-scoped policies and runtime account context are implemented and tested.
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE
  public.menstrual_cycle_logs,
  public.menstrual_daily_logs,
  public.menstrual_tracker_preferences
TO sakhi_staging_app;

-- Wellness preferences, push tokens, circle memberships/posts & admin auth sessions (2026-11-07).
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE
  public.member_wellness_preferences,
  public.member_push_tokens,
  public.community_circle_memberships,
  public.community_circle_posts,
  public.admin_auth_sessions
TO sakhi_staging_app;
