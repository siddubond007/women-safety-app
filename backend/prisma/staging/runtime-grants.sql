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
  public.member_communication_preferences
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

GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public TO sakhi_staging_app;
GRANT USAGE ON ALL TYPES IN SCHEMA public TO sakhi_staging_app;
REVOKE CREATE ON SCHEMA public FROM sakhi_staging_app;
REVOKE ALL ON TABLE public._prisma_migrations FROM sakhi_staging_app;
