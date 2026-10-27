-- Least-privilege runtime grants for Sakhi Modules 1-3.
-- Run as sakhi_staging_migrator after baseline setup.
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

-- Module 2 profile, social preferences, wellness, and safety domain.
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
  public.safety_emergency_contacts,
  public.safety_sos_events,
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
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE
  public.admin_staff_accounts
TO sakhi_staging_app;

GRANT SELECT, INSERT, UPDATE ON TABLE
  public.business_directory_listings,
  public.platform_config_settings
TO sakhi_staging_app;

GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public TO sakhi_staging_app;
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
