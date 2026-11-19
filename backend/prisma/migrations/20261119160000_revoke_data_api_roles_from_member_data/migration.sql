BEGIN;

-- Supabase staging uses two table-owner principals. Most member records are
-- owned by sakhi_staging_migrator; the bootstrap/MFA child tables and circle
-- records are owned by the restricted postgres role. Execute under the same
-- non-superuser owner boundary rather than relying on superuser privileges.
DO $stage4_owner_preflight$
BEGIN
  IF current_user <> 'postgres' THEN
    RAISE EXCEPTION 'Stage 4 Data API privilege migration must execute as the restricted postgres role';
  END IF;
  IF NOT pg_has_role(current_user, 'sakhi_staging_migrator', 'SET') THEN
    RAISE EXCEPTION 'postgres must have SET ROLE capability for sakhi_staging_migrator';
  END IF;
  IF EXISTS (
    SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname='public' AND c.relkind='r'
      AND c.relname = ANY(ARRAY[
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
        'member_follows',
        'member_privacy_preferences',
        'member_notification_preferences',
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
        'discreet_complaints',
        'eligibility_provider_callback_events'
      ])
      AND c.relowner <> (SELECT oid FROM pg_roles WHERE rolname='sakhi_staging_migrator')
  ) THEN
    RAISE EXCEPTION 'A migrator-owned protected table has an unexpected owner';
  END IF;
  IF EXISTS (
    SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname='public' AND c.relkind='r'
      AND c.relname = ANY(ARRAY[
    'admin_auth_sessions',
    'admin_bootstrap_credentials',
    'admin_staff_backup_codes',
    'admin_staff_mfa',
    'admin_staff_recovery_requests',
    'admin_staff_sessions',
    'community_circle_memberships',
    'community_circle_posts',
    'member_push_tokens',
    'member_wellness_preferences'
      ])
      AND c.relowner <> (SELECT oid FROM pg_roles WHERE rolname='postgres')
  ) THEN
    RAISE EXCEPTION 'A postgres-owned protected table has an unexpected owner';
  END IF;
END
$stage4_owner_preflight$;

-- Supabase's managed service_role bypasses RLS. Remove default grants from
-- both application table-owner principals so future public-schema objects
-- created by these roles do not silently reopen Data API access.
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE ALL ON TABLES FROM anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE ALL ON SEQUENCES FROM anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC, anon, authenticated, service_role;

SET LOCAL ROLE sakhi_staging_migrator;
ALTER DEFAULT PRIVILEGES FOR ROLE sakhi_staging_migrator IN SCHEMA public
  REVOKE ALL ON TABLES FROM PUBLIC, anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE sakhi_staging_migrator IN SCHEMA public
  REVOKE ALL ON SEQUENCES FROM PUBLIC, anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE sakhi_staging_migrator IN SCHEMA public
  REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC, anon, authenticated, service_role;
DO $revoke_migrator_owned_data_api_roles$
DECLARE table_name text; role_name text; column_name text;
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
    'member_follows',
    'member_privacy_preferences',
    'member_notification_preferences',
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
    'discreet_complaints',
    'eligibility_provider_callback_events'
  ] LOOP
    IF to_regclass(format('public.%I', table_name)) IS NULL THEN
      RAISE EXCEPTION 'Required protected table public.% is missing', table_name;
    END IF;
    EXECUTE format('REVOKE ALL PRIVILEGES ON TABLE public.%I FROM PUBLIC', table_name);
    FOR column_name IN
      SELECT a.attname FROM pg_attribute a
      WHERE a.attrelid = format('public.%I', table_name)::regclass
        AND a.attnum > 0 AND NOT a.attisdropped
    LOOP
      EXECUTE format('REVOKE ALL PRIVILEGES (%I) ON TABLE public.%I FROM PUBLIC', column_name, table_name);
    END LOOP;
    FOREACH role_name IN ARRAY ARRAY['anon', 'authenticated', 'service_role'] LOOP
      IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = role_name) THEN
        EXECUTE format('REVOKE ALL PRIVILEGES ON TABLE public.%I FROM %I', table_name, role_name);
        FOR column_name IN
          SELECT a.attname FROM pg_attribute a
          WHERE a.attrelid = format('public.%I', table_name)::regclass
            AND a.attnum > 0 AND NOT a.attisdropped
        LOOP
          EXECUTE format('REVOKE ALL PRIVILEGES (%I) ON TABLE public.%I FROM %I', column_name, table_name, role_name);
        END LOOP;
      END IF;
    END LOOP;
  END LOOP;
END
$revoke_migrator_owned_data_api_roles$;
RESET ROLE;

DO $revoke_postgres_owned_data_api_roles$
DECLARE table_name text; role_name text; column_name text;
BEGIN
  FOREACH table_name IN ARRAY ARRAY[
    'admin_auth_sessions',
    'admin_bootstrap_credentials',
    'admin_staff_backup_codes',
    'admin_staff_mfa',
    'admin_staff_recovery_requests',
    'admin_staff_sessions',
    'community_circle_memberships',
    'community_circle_posts',
    'member_push_tokens',
    'member_wellness_preferences'
  ] LOOP
    IF to_regclass(format('public.%I', table_name)) IS NULL THEN
      RAISE EXCEPTION 'Required protected table public.% is missing', table_name;
    END IF;
    EXECUTE format('REVOKE ALL PRIVILEGES ON TABLE public.%I FROM PUBLIC', table_name);
    FOR column_name IN
      SELECT a.attname FROM pg_attribute a
      WHERE a.attrelid = format('public.%I', table_name)::regclass
        AND a.attnum > 0 AND NOT a.attisdropped
    LOOP
      EXECUTE format('REVOKE ALL PRIVILEGES (%I) ON TABLE public.%I FROM PUBLIC', column_name, table_name);
    END LOOP;
    FOREACH role_name IN ARRAY ARRAY['anon', 'authenticated', 'service_role'] LOOP
      IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = role_name) THEN
        EXECUTE format('REVOKE ALL PRIVILEGES ON TABLE public.%I FROM %I', table_name, role_name);
        FOR column_name IN
          SELECT a.attname FROM pg_attribute a
          WHERE a.attrelid = format('public.%I', table_name)::regclass
            AND a.attnum > 0 AND NOT a.attisdropped
        LOOP
          EXECUTE format('REVOKE ALL PRIVILEGES (%I) ON TABLE public.%I FROM %I', column_name, table_name, role_name);
        END LOOP;
      END IF;
    END LOOP;
  END LOOP;
END
$revoke_postgres_owned_data_api_roles$;

DO $verify_member_data_api_role_revocations$
DECLARE table_name text; role_name text; privilege_name text;
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
  IF EXISTS (
    SELECT 1
    FROM pg_default_acl d
    JOIN pg_namespace n ON n.oid=d.defaclnamespace
    CROSS JOIN LATERAL aclexplode(d.defaclacl) x
    WHERE n.nspname='public'
      AND d.defaclrole IN (
        (SELECT oid FROM pg_roles WHERE rolname='postgres'),
        (SELECT oid FROM pg_roles WHERE rolname='sakhi_staging_migrator')
      )
      AND x.grantee IN (
        0,
        (SELECT oid FROM pg_roles WHERE rolname='anon'),
        (SELECT oid FROM pg_roles WHERE rolname='authenticated'),
        (SELECT oid FROM pg_roles WHERE rolname='service_role')
      )
  ) THEN
    RAISE EXCEPTION 'Application table-owner default privileges still expose public objects to Data API roles or PUBLIC';
  END IF;

  IF NOT has_table_privilege('sakhi_staging_app', 'public.member_accounts', 'SELECT')
     OR NOT has_table_privilege('sakhi_staging_app', 'public.member_profiles', 'SELECT')
     OR NOT has_table_privilege('sakhi_staging_app', 'public.admin_staff_accounts', 'SELECT') THEN
    RAISE EXCEPTION 'Dedicated Sakhi backend role lost required protected-table access';
  END IF;
END
$verify_member_data_api_role_revocations$;

COMMIT;
