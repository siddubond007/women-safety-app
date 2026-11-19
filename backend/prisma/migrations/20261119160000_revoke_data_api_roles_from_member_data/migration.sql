BEGIN;

-- Sakhi accesses protected records through the dedicated sakhi_staging_app
-- connection, which is a non-BYPASSRLS role. Supabase's service_role has
-- BYPASSRLS; therefore row policies alone cannot protect data from that role.
-- The Flutter client does not connect to Supabase Data API directly.
DO $revoke_member_data_api_roles$
DECLARE
  table_name text;
  role_name text;
  column_name text;
BEGIN
  FOREACH table_name IN ARRAY ARRAY[
    'member_accounts',
    'auth_sessions',
    'otp_challenges',
    'account_deletion_requests',
    'member_profiles',
    'member_consents',
    'member_communication_preferences',
    'eligibility_submissions',
    'community_posts',
    'community_post_likes',
    'community_post_saves',
    'community_post_comments',
    'community_groups',
    'community_circle_memberships',
    'community_circle_posts',
    'member_follows',
    'member_privacy_preferences',
    'member_notification_preferences',
    'member_push_tokens',
    'member_wellness_preferences',
    'member_notifications',
    'safety_emergency_contacts',
    'safety_sos_events',
    'safety_location_shares',
    'member_moderation_blocks',
    'member_user_reports',
    'direct_messages',
    'media_assets',
    'community_post_reactions',
    'business_directory_listings',
    'business_enquiries',
    'business_reports',
    'menstrual_cycle_logs',
    'menstrual_daily_logs',
    'menstrual_tracker_preferences',
    'community_directory_profiles',
    'eligibility_consents',
    'eligibility_support_requests',
    'eligibility_verification_sessions',
    'audit_events',
    'moderation_decisions',
    'admin_staff_accounts',
    'admin_staff_sessions',
    'admin_staff_mfa',
    'admin_staff_backup_codes',
    'admin_staff_recovery_requests',
    'admin_auth_sessions',
    'discreet_complaints',
    'eligibility_provider_callback_events',
    'admin_bootstrap_credentials'
  ] LOOP
    IF to_regclass(format('public.%I', table_name)) IS NULL THEN
      RAISE EXCEPTION 'Required protected table public.% is missing', table_name;
    END IF;

    EXECUTE format('REVOKE ALL PRIVILEGES ON TABLE public.%I FROM PUBLIC', table_name);

    -- Table-level REVOKE does not remove column-level grants. Remove those
    -- explicitly as well so no stale Data API column ACL survives.
    FOR column_name IN
      SELECT a.attname
      FROM pg_attribute a
      WHERE a.attrelid = format('public.%I', table_name)::regclass
        AND a.attnum > 0
        AND NOT a.attisdropped
    LOOP
      EXECUTE format(
        'REVOKE ALL PRIVILEGES (%I) ON TABLE public.%I FROM PUBLIC',
        column_name,
        table_name
      );
    END LOOP;

    FOREACH role_name IN ARRAY ARRAY['anon', 'authenticated', 'service_role'] LOOP
      IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = role_name) THEN
        EXECUTE format(
          'REVOKE ALL PRIVILEGES ON TABLE public.%I FROM %I',
          table_name,
          role_name
        );
        FOR column_name IN
          SELECT a.attname
          FROM pg_attribute a
          WHERE a.attrelid = format('public.%I', table_name)::regclass
            AND a.attnum > 0
            AND NOT a.attisdropped
        LOOP
          EXECUTE format(
            'REVOKE ALL PRIVILEGES (%I) ON TABLE public.%I FROM %I',
            column_name,
            table_name,
            role_name
          );
        END LOOP;
      END IF;
    END LOOP;
  END LOOP;
END
$revoke_member_data_api_roles$;

-- Postflight: the public Supabase API roles must not have table privileges on
-- protected member/admin data. Backend access remains via sakhi_staging_app.
DO $verify_member_data_api_role_revocations$
DECLARE
  table_name text;
  role_name text;
  privilege_name text;
BEGIN
  FOREACH table_name IN ARRAY ARRAY[
    'member_accounts',
    'auth_sessions',
    'otp_challenges',
    'account_deletion_requests',
    'member_profiles',
    'member_consents',
    'member_communication_preferences',
    'eligibility_submissions',
    'community_posts',
    'community_post_likes',
    'community_post_saves',
    'community_post_comments',
    'community_groups',
    'community_circle_memberships',
    'community_circle_posts',
    'member_follows',
    'member_privacy_preferences',
    'member_notification_preferences',
    'member_push_tokens',
    'member_wellness_preferences',
    'member_notifications',
    'safety_emergency_contacts',
    'safety_sos_events',
    'safety_location_shares',
    'member_moderation_blocks',
    'member_user_reports',
    'direct_messages',
    'media_assets',
    'community_post_reactions',
    'business_directory_listings',
    'business_enquiries',
    'business_reports',
    'menstrual_cycle_logs',
    'menstrual_daily_logs',
    'menstrual_tracker_preferences',
    'community_directory_profiles',
    'eligibility_consents',
    'eligibility_support_requests',
    'eligibility_verification_sessions',
    'audit_events',
    'moderation_decisions',
    'admin_staff_accounts',
    'admin_staff_sessions',
    'admin_staff_mfa',
    'admin_staff_backup_codes',
    'admin_staff_recovery_requests',
    'admin_auth_sessions',
    'discreet_complaints',
    'eligibility_provider_callback_events',
    'admin_bootstrap_credentials'
  ] LOOP
    FOREACH role_name IN ARRAY ARRAY['anon', 'authenticated', 'service_role'] LOOP
      IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = role_name) THEN
        FOREACH privilege_name IN ARRAY ARRAY['SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER'] LOOP
          IF has_table_privilege(role_name, format('public.%I', table_name), privilege_name) THEN
            RAISE EXCEPTION 'Role % retains % privilege on protected table public.%', role_name, privilege_name, table_name;
          END IF;
          IF privilege_name IN ('SELECT', 'INSERT', 'UPDATE', 'REFERENCES')
             AND has_any_column_privilege(role_name, format('public.%I', table_name), privilege_name) THEN
            RAISE EXCEPTION 'Role % retains column-level % privilege on protected table public.%', role_name, privilege_name, table_name;
          END IF;
        END LOOP;
      END IF;
    END LOOP;
  END LOOP;

  IF NOT has_table_privilege('sakhi_staging_app', 'public.member_accounts', 'SELECT')
     OR NOT has_table_privilege('sakhi_staging_app', 'public.member_profiles', 'SELECT')
     OR NOT has_table_privilege('sakhi_staging_app', 'public.admin_staff_accounts', 'SELECT') THEN
    RAISE EXCEPTION 'Dedicated Sakhi backend role lost required protected-table access';
  END IF;
END
$verify_member_data_api_role_revocations$;

COMMIT;
