-- Manual rollback only. This removes Stage 5 row policies and disables RLS on
-- the tables protected by this migration. Do not run without a reviewed rollback plan.
DO $rollback$
DECLARE table_name TEXT;
BEGIN
  FOREACH table_name IN ARRAY ARRAY[
    'account_deletion_requests','member_profiles','member_consents',
    'member_communication_preferences','eligibility_submissions','community_posts',
    'community_post_likes','community_post_saves','community_post_comments',
    'community_groups','community_circle_memberships','community_circle_posts',
    'member_follows','member_privacy_preferences','member_notification_preferences',
    'member_push_tokens','member_wellness_preferences','member_notifications',
    'safety_emergency_contacts','safety_sos_events','safety_location_shares',
    'member_moderation_blocks','member_user_reports','direct_messages','media_assets',
    'community_post_reactions','business_directory_listings','business_enquiries','business_reports'
  ] LOOP
    IF to_regclass(format('public.%I',table_name)) IS NOT NULL THEN
      EXECUTE format('ALTER TABLE public.%I DISABLE ROW LEVEL SECURITY',table_name);
    END IF;
  END LOOP;
END
$rollback$;
