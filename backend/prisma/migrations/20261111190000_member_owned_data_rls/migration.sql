-- Stage 5: account-scoped RLS for member-owned records.
-- PrismaService binds app.account_id/app.session_id or app.admin_staff_id/app.admin_role
-- transaction-locally after authentication. The runtime DB roles must never own
-- these tables and must not have SUPERUSER or BYPASSRLS privileges.

DO $sakhi_member_rls_preflight$
DECLARE item RECORD;
BEGIN
  FOR item IN SELECT * FROM (VALUES
    ('member_accounts','id'),
    ('auth_sessions','account_id'),
    ('otp_challenges','account_id'),
    ('account_deletion_requests','account_id'),
    ('member_profiles','account_id'),
    ('member_consents','account_id'),
    ('member_communication_preferences','account_id'),
    ('eligibility_submissions','account_id'),
    ('community_posts','author_account_id'),
    ('community_post_likes','account_id'),
    ('community_post_saves','account_id'),
    ('community_post_comments','account_id'),
    ('community_groups','owner_account_id'),
    ('community_circle_memberships','account_id'),
    ('community_circle_posts','author_account_id'),
    ('member_follows','account_id'),
    ('member_privacy_preferences','account_id'),
    ('member_notification_preferences','account_id'),
    ('member_push_tokens','account_id'),
    ('member_wellness_preferences','account_id'),
    ('member_notifications','account_id'),
    ('safety_emergency_contacts','account_id'),
    ('safety_sos_events','account_id'),
    ('safety_location_shares','account_id'),
    ('member_moderation_blocks','account_id'),
    ('member_user_reports','reporter_account_id'),
    ('direct_messages','sender_account_id'),
    ('media_assets','owner_account_id'),
    ('community_post_reactions','account_id'),
    ('business_directory_listings','owner_account_id'),
    ('business_enquiries','sender_account_id'),
    ('business_reports','reporter_account_id')
  ) AS required(table_name,column_name)
  LOOP
    IF to_regclass(format('public.%I', item.table_name)) IS NULL THEN
      RAISE EXCEPTION 'Stage 5 requires public.%', item.table_name;
    END IF;
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns c
      WHERE c.table_schema='public' AND c.table_name=item.table_name
        AND c.column_name=item.column_name AND c.data_type='uuid'
    ) THEN
      RAISE EXCEPTION 'Stage 5 requires UUID %.% ', item.table_name, item.column_name;
    END IF;
  END LOOP;

  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='sakhi_dev_app') OR
     NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='sakhi_test_app') OR
     NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='sakhi_staging_app') THEN
    RAISE EXCEPTION 'Stage 5 requires the three dedicated Sakhi runtime roles';
  END IF;

  IF EXISTS (
    SELECT 1 FROM pg_roles
    WHERE rolname IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app')
      AND (rolsuper OR rolbypassrls)
  ) THEN
    RAISE EXCEPTION 'Sakhi runtime roles must not be SUPERUSER or BYPASSRLS';
  END IF;

  IF EXISTS (
    SELECT 1 FROM pg_class c
    JOIN pg_namespace n ON n.oid=c.relnamespace
    JOIN pg_roles r ON r.oid=c.relowner
    WHERE n.nspname='public'
      AND c.relname IN (
        'member_accounts','auth_sessions','otp_challenges','account_deletion_requests','member_profiles','member_consents',
        'member_communication_preferences','eligibility_submissions','community_posts',
        'community_post_likes','community_post_saves','community_post_comments',
        'community_groups','community_circle_memberships','community_circle_posts',
        'member_follows','member_privacy_preferences','member_notification_preferences',
        'member_push_tokens','member_wellness_preferences','member_notifications',
        'safety_emergency_contacts','safety_sos_events','safety_location_shares',
        'member_moderation_blocks','member_user_reports','direct_messages','media_assets',
        'community_post_reactions','business_directory_listings','business_enquiries','business_reports'
      )
      AND r.rolname IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app')
  ) THEN
    RAISE EXCEPTION 'A Sakhi runtime role owns a protected member-data table';
  END IF;
END
$sakhi_member_rls_preflight$;

-- Remove the earlier role-only policies: permissive policies are OR-combined and
-- would otherwise defeat account isolation even after the new policies are added.
DROP POLICY IF EXISTS member_notifications_backend_runtime_access ON public.member_notifications;
DROP POLICY IF EXISTS member_wellness_preferences_backend_runtime_access ON public.member_wellness_preferences;
DROP POLICY IF EXISTS member_push_tokens_backend_runtime_access ON public.member_push_tokens;

-- Identity-root tables have narrow, explicit pre-authentication exceptions.
ALTER TABLE public.member_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.member_accounts FORCE ROW LEVEL SECURITY;
CREATE POLICY member_accounts_self_or_auth_lookup_read ON public.member_accounts
  FOR SELECT TO PUBLIC USING (
    current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND (
      id=NULLIF(current_setting('app.account_id',true),'')::uuid OR
      current_setting('app.auth_lookup',true)='true' OR
      (NULLIF(current_setting('app.admin_staff_id',true),'') IS NOT NULL AND current_setting('app.admin_role',true) IN ('SUPER_ADMIN','VERIFICATION_ADMIN'))
    )
  );
CREATE POLICY member_accounts_self_or_auth_lookup_insert ON public.member_accounts
  FOR INSERT TO PUBLIC WITH CHECK (
    current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND (
      id=NULLIF(current_setting('app.account_id',true),'')::uuid OR
      current_setting('app.auth_lookup',true)='true' OR
      (NULLIF(current_setting('app.admin_staff_id',true),'') IS NOT NULL AND current_setting('app.admin_role',true)='SUPER_ADMIN')
    )
  );
CREATE POLICY member_accounts_self_or_auth_lookup_update ON public.member_accounts
  FOR UPDATE TO PUBLIC
  USING (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND (
    id=NULLIF(current_setting('app.account_id',true),'')::uuid OR
    current_setting('app.auth_lookup',true)='true' OR
    (NULLIF(current_setting('app.admin_staff_id',true),'') IS NOT NULL AND current_setting('app.admin_role',true) IN ('SUPER_ADMIN','VERIFICATION_ADMIN'))
  ))
  WITH CHECK (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND (
    id=NULLIF(current_setting('app.account_id',true),'')::uuid OR
    current_setting('app.auth_lookup',true)='true' OR
    (NULLIF(current_setting('app.admin_staff_id',true),'') IS NOT NULL AND current_setting('app.admin_role',true) IN ('SUPER_ADMIN','VERIFICATION_ADMIN'))
  ));
CREATE POLICY member_accounts_superadmin_delete ON public.member_accounts
  FOR DELETE TO PUBLIC USING (
    current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND
    NULLIF(current_setting('app.admin_staff_id',true),'') IS NOT NULL AND
    current_setting('app.admin_role',true)='SUPER_ADMIN'
  );

ALTER TABLE public.auth_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.auth_sessions FORCE ROW LEVEL SECURITY;
CREATE POLICY auth_sessions_owner_or_token_digest_read ON public.auth_sessions
  FOR SELECT TO PUBLIC USING (
    current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND (
      account_id=NULLIF(current_setting('app.account_id',true),'')::uuid OR
      token_digest=NULLIF(current_setting('app.auth_session_digest',true),'') OR
      (NULLIF(current_setting('app.admin_staff_id',true),'') IS NOT NULL AND current_setting('app.admin_role',true)='SUPER_ADMIN')
    )
  );
CREATE POLICY auth_sessions_owner_or_auth_insert ON public.auth_sessions
  FOR INSERT TO PUBLIC WITH CHECK (
    current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND (
      account_id=NULLIF(current_setting('app.account_id',true),'')::uuid OR
      current_setting('app.auth_lookup',true)='true' OR
      (NULLIF(current_setting('app.admin_staff_id',true),'') IS NOT NULL AND current_setting('app.admin_role',true)='SUPER_ADMIN')
    )
  );
CREATE POLICY auth_sessions_owner_update ON public.auth_sessions
  FOR UPDATE TO PUBLIC
  USING (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND (
    account_id=NULLIF(current_setting('app.account_id',true),'')::uuid OR
    (NULLIF(current_setting('app.admin_staff_id',true),'') IS NOT NULL AND current_setting('app.admin_role',true)='SUPER_ADMIN')
  ))
  WITH CHECK (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND (
    account_id=NULLIF(current_setting('app.account_id',true),'')::uuid OR
    (NULLIF(current_setting('app.admin_staff_id',true),'') IS NOT NULL AND current_setting('app.admin_role',true)='SUPER_ADMIN')
  ));
CREATE POLICY auth_sessions_superadmin_delete ON public.auth_sessions
  FOR DELETE TO PUBLIC USING (
    current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND
    NULLIF(current_setting('app.admin_staff_id',true),'') IS NOT NULL AND current_setting('app.admin_role',true)='SUPER_ADMIN'
  );

ALTER TABLE public.otp_challenges ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.otp_challenges FORCE ROW LEVEL SECURITY;
CREATE POLICY otp_challenges_auth_flow_or_owner ON public.otp_challenges
  FOR ALL TO PUBLIC
  USING (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND (
    account_id=NULLIF(current_setting('app.account_id',true),'')::uuid OR
    current_setting('app.auth_lookup',true)='true' OR
    (NULLIF(current_setting('app.admin_staff_id',true),'') IS NOT NULL AND current_setting('app.admin_role',true)='SUPER_ADMIN')
  ))
  WITH CHECK (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND (
    account_id=NULLIF(current_setting('app.account_id',true),'')::uuid OR
    current_setting('app.auth_lookup',true)='true' OR
    (NULLIF(current_setting('app.admin_staff_id',true),'') IS NOT NULL AND current_setting('app.admin_role',true)='SUPER_ADMIN')
  ));

-- Private, strictly account-owned tables.
DO $sakhi_private_member_tables$
DECLARE table_name TEXT;
BEGIN
  FOREACH table_name IN ARRAY ARRAY[
    'member_accounts','auth_sessions','otp_challenges','account_deletion_requests','member_profiles','member_consents',
    'member_communication_preferences','eligibility_submissions',
    'community_post_likes','community_post_saves','community_circle_memberships',
    'member_follows','member_privacy_preferences','member_notification_preferences',
    'member_push_tokens','member_wellness_preferences','member_notifications',
    'safety_emergency_contacts','safety_sos_events','safety_location_shares',
    'member_moderation_blocks'
  ] LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', table_name);
    EXECUTE format('ALTER TABLE public.%I FORCE ROW LEVEL SECURITY', table_name);
  END LOOP;
END
$sakhi_private_member_tables$;

CREATE POLICY account_deletion_requests_owner_or_superadmin ON public.account_deletion_requests
  FOR ALL TO PUBLIC
  USING (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND (
    account_id = NULLIF(current_setting('app.account_id',true),'')::uuid OR
    (NULLIF(current_setting('app.admin_staff_id',true),'') IS NOT NULL AND current_setting('app.admin_role',true)='SUPER_ADMIN')
  ))
  WITH CHECK (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND (
    account_id = NULLIF(current_setting('app.account_id',true),'')::uuid OR
    (NULLIF(current_setting('app.admin_staff_id',true),'') IS NOT NULL AND current_setting('app.admin_role',true)='SUPER_ADMIN')
  ));

CREATE POLICY member_profiles_owner_or_verification_admin ON public.member_profiles
  FOR ALL TO PUBLIC
  USING (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND (
    account_id = NULLIF(current_setting('app.account_id',true),'')::uuid OR
    (NULLIF(current_setting('app.admin_staff_id',true),'') IS NOT NULL AND current_setting('app.admin_role',true) IN ('SUPER_ADMIN','VERIFICATION_ADMIN'))
  ))
  WITH CHECK (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND (
    account_id = NULLIF(current_setting('app.account_id',true),'')::uuid OR
    (NULLIF(current_setting('app.admin_staff_id',true),'') IS NOT NULL AND current_setting('app.admin_role',true) IN ('SUPER_ADMIN','VERIFICATION_ADMIN'))
  ));
CREATE POLICY member_profiles_username_availability_lookup ON public.member_profiles
  FOR SELECT TO PUBLIC USING (
    current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND
    current_setting('app.username_lookup',true)='true'
  );

CREATE POLICY member_consents_owner_only ON public.member_consents
  FOR ALL TO PUBLIC USING (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND account_id=NULLIF(current_setting('app.account_id',true),'')::uuid)
  WITH CHECK (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND account_id=NULLIF(current_setting('app.account_id',true),'')::uuid);

CREATE POLICY member_communication_preferences_owner_only ON public.member_communication_preferences
  FOR ALL TO PUBLIC USING (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND account_id=NULLIF(current_setting('app.account_id',true),'')::uuid)
  WITH CHECK (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND account_id=NULLIF(current_setting('app.account_id',true),'')::uuid);

CREATE POLICY eligibility_submissions_owner_or_verification_admin ON public.eligibility_submissions
  FOR ALL TO PUBLIC
  USING (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND (
    account_id=NULLIF(current_setting('app.account_id',true),'')::uuid OR
    (NULLIF(current_setting('app.admin_staff_id',true),'') IS NOT NULL AND current_setting('app.admin_role',true) IN ('SUPER_ADMIN','VERIFICATION_ADMIN'))
  ))
  WITH CHECK (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND (
    account_id=NULLIF(current_setting('app.account_id',true),'')::uuid OR
    (NULLIF(current_setting('app.admin_staff_id',true),'') IS NOT NULL AND current_setting('app.admin_role',true) IN ('SUPER_ADMIN','VERIFICATION_ADMIN'))
  ));

CREATE POLICY community_post_likes_owner_only ON public.community_post_likes
  FOR ALL TO PUBLIC USING (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND account_id=NULLIF(current_setting('app.account_id',true),'')::uuid)
  WITH CHECK (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND account_id=NULLIF(current_setting('app.account_id',true),'')::uuid);
CREATE POLICY community_post_saves_owner_only ON public.community_post_saves
  FOR ALL TO PUBLIC USING (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND account_id=NULLIF(current_setting('app.account_id',true),'')::uuid)
  WITH CHECK (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND account_id=NULLIF(current_setting('app.account_id',true),'')::uuid);
CREATE POLICY community_circle_memberships_owner_only ON public.community_circle_memberships
  FOR ALL TO PUBLIC USING (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND account_id=NULLIF(current_setting('app.account_id',true),'')::uuid)
  WITH CHECK (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND account_id=NULLIF(current_setting('app.account_id',true),'')::uuid);
CREATE POLICY member_follows_owner_only ON public.member_follows
  FOR ALL TO PUBLIC USING (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND account_id=NULLIF(current_setting('app.account_id',true),'')::uuid)
  WITH CHECK (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND account_id=NULLIF(current_setting('app.account_id',true),'')::uuid);
CREATE POLICY member_privacy_preferences_owner_only ON public.member_privacy_preferences
  FOR ALL TO PUBLIC USING (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND account_id=NULLIF(current_setting('app.account_id',true),'')::uuid)
  WITH CHECK (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND account_id=NULLIF(current_setting('app.account_id',true),'')::uuid);
CREATE POLICY member_notification_preferences_owner_only ON public.member_notification_preferences
  FOR ALL TO PUBLIC USING (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND account_id=NULLIF(current_setting('app.account_id',true),'')::uuid)
  WITH CHECK (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND account_id=NULLIF(current_setting('app.account_id',true),'')::uuid);
CREATE POLICY member_notification_preferences_recipient_delivery_read ON public.member_notification_preferences
  FOR SELECT TO PUBLIC USING (
    current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND
    NULLIF(current_setting('app.account_id',true),'') IS NOT NULL AND
    account_id=NULLIF(current_setting('app.notification_recipient_id',true),'')::uuid
  );
CREATE POLICY member_push_tokens_owner_only ON public.member_push_tokens
  FOR ALL TO PUBLIC USING (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND account_id=NULLIF(current_setting('app.account_id',true),'')::uuid)
  WITH CHECK (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND account_id=NULLIF(current_setting('app.account_id',true),'')::uuid);
CREATE POLICY member_wellness_preferences_owner_only ON public.member_wellness_preferences
  FOR ALL TO PUBLIC USING (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND account_id=NULLIF(current_setting('app.account_id',true),'')::uuid)
  WITH CHECK (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND account_id=NULLIF(current_setting('app.account_id',true),'')::uuid);
CREATE POLICY member_notifications_owner_only ON public.member_notifications
  FOR ALL TO PUBLIC USING (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND account_id=NULLIF(current_setting('app.account_id',true),'')::uuid)
  WITH CHECK (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND account_id=NULLIF(current_setting('app.account_id',true),'')::uuid);
CREATE POLICY member_notifications_recipient_delivery ON public.member_notifications
  FOR ALL TO PUBLIC USING (
    current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND
    NULLIF(current_setting('app.account_id',true),'') IS NOT NULL AND
    account_id=NULLIF(current_setting('app.notification_recipient_id',true),'')::uuid
  ) WITH CHECK (
    current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND
    NULLIF(current_setting('app.account_id',true),'') IS NOT NULL AND
    account_id=NULLIF(current_setting('app.notification_recipient_id',true),'')::uuid
  );
CREATE POLICY safety_emergency_contacts_owner_only ON public.safety_emergency_contacts
  FOR ALL TO PUBLIC USING (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND account_id=NULLIF(current_setting('app.account_id',true),'')::uuid)
  WITH CHECK (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND account_id=NULLIF(current_setting('app.account_id',true),'')::uuid);
CREATE POLICY safety_sos_events_owner_only ON public.safety_sos_events
  FOR ALL TO PUBLIC USING (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND account_id=NULLIF(current_setting('app.account_id',true),'')::uuid)
  WITH CHECK (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND account_id=NULLIF(current_setting('app.account_id',true),'')::uuid);
CREATE POLICY safety_location_shares_owner_only ON public.safety_location_shares
  FOR ALL TO PUBLIC USING (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND account_id=NULLIF(current_setting('app.account_id',true),'')::uuid)
  WITH CHECK (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND account_id=NULLIF(current_setting('app.account_id',true),'')::uuid);
CREATE POLICY member_moderation_blocks_owner_only ON public.member_moderation_blocks
  FOR ALL TO PUBLIC USING (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND account_id=NULLIF(current_setting('app.account_id',true),'')::uuid)
  WITH CHECK (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND account_id=NULLIF(current_setting('app.account_id',true),'')::uuid);

-- Public/community data: reads are limited to active verified-member content;
-- mutations remain author/owner-only, with narrowly role-gated moderation access.
ALTER TABLE public.community_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.community_posts FORCE ROW LEVEL SECURITY;
CREATE POLICY community_posts_owner_or_moderator ON public.community_posts
  FOR ALL TO PUBLIC
  USING (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND (
    author_account_id=NULLIF(current_setting('app.account_id',true),'')::uuid OR
    (NULLIF(current_setting('app.admin_staff_id',true),'') IS NOT NULL AND current_setting('app.admin_role',true) IN ('SUPER_ADMIN','CONTENT_MODERATOR','COMPLAINT_REVIEWER'))
  ))
  WITH CHECK (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND (
    author_account_id=NULLIF(current_setting('app.account_id',true),'')::uuid OR
    (NULLIF(current_setting('app.admin_staff_id',true),'') IS NOT NULL AND current_setting('app.admin_role',true) IN ('SUPER_ADMIN','CONTENT_MODERATOR','COMPLAINT_REVIEWER'))
  ));
CREATE POLICY community_posts_verified_read ON public.community_posts
  FOR SELECT TO PUBLIC
  USING (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND
    NULLIF(current_setting('app.account_id',true),'') IS NOT NULL AND
    status='PUBLISHED' AND deleted_at IS NULL AND visibility IN ('PUBLIC','VERIFIED_MEMBERS'));

ALTER TABLE public.community_post_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.community_post_comments FORCE ROW LEVEL SECURITY;
CREATE POLICY community_post_comments_owner_or_moderator ON public.community_post_comments
  FOR ALL TO PUBLIC
  USING (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND (
    account_id=NULLIF(current_setting('app.account_id',true),'')::uuid OR
    EXISTS (SELECT 1 FROM public.community_posts p WHERE p.id=community_post_comments.post_id AND p.author_account_id=NULLIF(current_setting('app.account_id',true),'')::uuid) OR
    (NULLIF(current_setting('app.admin_staff_id',true),'') IS NOT NULL AND current_setting('app.admin_role',true) IN ('SUPER_ADMIN','CONTENT_MODERATOR','COMPLAINT_REVIEWER'))
  ))
  WITH CHECK (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND (
    account_id=NULLIF(current_setting('app.account_id',true),'')::uuid OR
    EXISTS (SELECT 1 FROM public.community_posts p WHERE p.id=community_post_comments.post_id AND p.author_account_id=NULLIF(current_setting('app.account_id',true),'')::uuid) OR
    (NULLIF(current_setting('app.admin_staff_id',true),'') IS NOT NULL AND current_setting('app.admin_role',true) IN ('SUPER_ADMIN','CONTENT_MODERATOR','COMPLAINT_REVIEWER'))
  ));
CREATE POLICY community_post_comments_verified_read ON public.community_post_comments
  FOR SELECT TO PUBLIC
  USING (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND (
    account_id=NULLIF(current_setting('app.account_id',true),'')::uuid OR
    (NULLIF(current_setting('app.account_id',true),'') IS NOT NULL AND deleted_at IS NULL AND is_removed_by_moderator=false AND EXISTS (
      SELECT 1 FROM public.community_posts p
      WHERE p.id=community_post_comments.post_id AND p.status='PUBLISHED'
        AND p.deleted_at IS NULL AND p.visibility IN ('PUBLIC','VERIFIED_MEMBERS')
    ))
  ));

ALTER TABLE public.community_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.community_groups FORCE ROW LEVEL SECURITY;
CREATE POLICY community_groups_owner_or_moderator ON public.community_groups
  FOR ALL TO PUBLIC
  USING (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND (
    owner_account_id=NULLIF(current_setting('app.account_id',true),'')::uuid OR
    (NULLIF(current_setting('app.admin_staff_id',true),'') IS NOT NULL AND current_setting('app.admin_role',true) IN ('SUPER_ADMIN','CONTENT_MODERATOR'))
  ))
  WITH CHECK (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND (
    owner_account_id=NULLIF(current_setting('app.account_id',true),'')::uuid OR
    (NULLIF(current_setting('app.admin_staff_id',true),'') IS NOT NULL AND current_setting('app.admin_role',true) IN ('SUPER_ADMIN','CONTENT_MODERATOR'))
  ));
CREATE POLICY community_groups_verified_read ON public.community_groups
  FOR SELECT TO PUBLIC
  USING (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND
    NULLIF(current_setting('app.account_id',true),'') IS NOT NULL AND
    activity_state='ACTIVE' AND visibility='PUBLIC_VERIFIED');

ALTER TABLE public.community_circle_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.community_circle_posts FORCE ROW LEVEL SECURITY;
CREATE POLICY community_circle_posts_author_or_moderator ON public.community_circle_posts
  FOR ALL TO PUBLIC
  USING (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND (
    author_account_id=NULLIF(current_setting('app.account_id',true),'')::uuid OR
    (NULLIF(current_setting('app.admin_staff_id',true),'') IS NOT NULL AND current_setting('app.admin_role',true) IN ('SUPER_ADMIN','CONTENT_MODERATOR'))
  ))
  WITH CHECK (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND (
    author_account_id=NULLIF(current_setting('app.account_id',true),'')::uuid OR
    (NULLIF(current_setting('app.admin_staff_id',true),'') IS NOT NULL AND current_setting('app.admin_role',true) IN ('SUPER_ADMIN','CONTENT_MODERATOR'))
  ));
CREATE POLICY community_circle_posts_member_read ON public.community_circle_posts
  FOR SELECT TO PUBLIC
  USING (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND (
    author_account_id=NULLIF(current_setting('app.account_id',true),'')::uuid OR
    (NULLIF(current_setting('app.account_id',true),'') IS NOT NULL AND EXISTS (
      SELECT 1 FROM public.community_circle_memberships m
      WHERE m.circle_id=community_circle_posts.circle_id
        AND m.account_id=NULLIF(current_setting('app.account_id',true),'')::uuid
        AND m.status='ACTIVE'
    ) AND status='PUBLISHED'
    ))
  );

ALTER TABLE public.member_user_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.member_user_reports FORCE ROW LEVEL SECURITY;
CREATE POLICY member_user_reports_reporter_or_reviewer ON public.member_user_reports
  FOR ALL TO PUBLIC
  USING (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND (
    reporter_account_id=NULLIF(current_setting('app.account_id',true),'')::uuid OR
    (NULLIF(current_setting('app.admin_staff_id',true),'') IS NOT NULL AND current_setting('app.admin_role',true) IN ('SUPER_ADMIN','COMPLAINT_REVIEWER','CONTENT_MODERATOR','SOS_SAFETY_ADMIN'))
  ))
  WITH CHECK (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND (
    reporter_account_id=NULLIF(current_setting('app.account_id',true),'')::uuid OR
    (NULLIF(current_setting('app.admin_staff_id',true),'') IS NOT NULL AND current_setting('app.admin_role',true) IN ('SUPER_ADMIN','COMPLAINT_REVIEWER','CONTENT_MODERATOR','SOS_SAFETY_ADMIN'))
  ));

ALTER TABLE public.direct_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.direct_messages FORCE ROW LEVEL SECURITY;
CREATE POLICY direct_messages_participants_only ON public.direct_messages
  FOR ALL TO PUBLIC
  USING (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND (
    sender_account_id=NULLIF(current_setting('app.account_id',true),'')::uuid OR
    recipient_account_id=NULLIF(current_setting('app.account_id',true),'')::uuid
  ))
  WITH CHECK (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND (
    sender_account_id=NULLIF(current_setting('app.account_id',true),'')::uuid OR
    recipient_account_id=NULLIF(current_setting('app.account_id',true),'')::uuid
  ));

ALTER TABLE public.media_assets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.media_assets FORCE ROW LEVEL SECURITY;
CREATE POLICY media_assets_owner_or_authorized_member ON public.media_assets
  FOR ALL TO PUBLIC
  USING (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND (
    owner_account_id=NULLIF(current_setting('app.account_id',true),'')::uuid OR
    (NULLIF(current_setting('app.admin_staff_id',true),'') IS NOT NULL AND current_setting('app.admin_role',true) IN ('SUPER_ADMIN','CONTENT_MODERATOR','COMPLAINT_REVIEWER'))
  ))
  WITH CHECK (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND (
    owner_account_id=NULLIF(current_setting('app.account_id',true),'')::uuid OR
    (NULLIF(current_setting('app.admin_staff_id',true),'') IS NOT NULL AND current_setting('app.admin_role',true) IN ('SUPER_ADMIN','CONTENT_MODERATOR','COMPLAINT_REVIEWER'))
  ));
CREATE POLICY media_assets_verified_or_message_read ON public.media_assets
  FOR SELECT TO PUBLIC
  USING (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND (
    (NULLIF(current_setting('app.account_id',true),'') IS NOT NULL AND visibility IN ('PUBLIC','VERIFIED_MEMBERS') AND deleted_at IS NULL AND status IN ('UPLOADED','ATTACHED')) OR
    EXISTS (
      SELECT 1 FROM public.direct_messages dm
      WHERE dm.media_upload_id=media_assets.id::text AND
        (dm.sender_account_id=NULLIF(current_setting('app.account_id',true),'')::uuid OR dm.recipient_account_id=NULLIF(current_setting('app.account_id',true),'')::uuid)
    )
  ));

ALTER TABLE public.community_post_reactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.community_post_reactions FORCE ROW LEVEL SECURITY;
CREATE POLICY community_post_reactions_owner_only ON public.community_post_reactions
  FOR ALL TO PUBLIC USING (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND account_id=NULLIF(current_setting('app.account_id',true),'')::uuid)
  WITH CHECK (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND account_id=NULLIF(current_setting('app.account_id',true),'')::uuid);

ALTER TABLE public.business_directory_listings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.business_directory_listings FORCE ROW LEVEL SECURITY;
CREATE POLICY business_directory_listings_owner_or_business_admin ON public.business_directory_listings
  FOR ALL TO PUBLIC
  USING (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND (
    owner_account_id=NULLIF(current_setting('app.account_id',true),'')::uuid OR
    (NULLIF(current_setting('app.admin_staff_id',true),'') IS NOT NULL AND current_setting('app.admin_role',true) IN ('SUPER_ADMIN','BUSINESS_ADMIN'))
  ))
  WITH CHECK (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND (
    owner_account_id=NULLIF(current_setting('app.account_id',true),'')::uuid OR
    (NULLIF(current_setting('app.admin_staff_id',true),'') IS NOT NULL AND current_setting('app.admin_role',true) IN ('SUPER_ADMIN','BUSINESS_ADMIN'))
  ));
CREATE POLICY business_directory_listings_public_read ON public.business_directory_listings
  FOR SELECT TO PUBLIC
  USING (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND
    NULLIF(current_setting('app.account_id',true),'') IS NOT NULL AND
    approval_status='APPROVED' AND is_reported_fraudulent=false);

ALTER TABLE public.business_enquiries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.business_enquiries FORCE ROW LEVEL SECURITY;
CREATE POLICY business_enquiries_participants_or_admin ON public.business_enquiries
  FOR ALL TO PUBLIC
  USING (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND (
    sender_account_id=NULLIF(current_setting('app.account_id',true),'')::uuid OR
    owner_account_id=NULLIF(current_setting('app.account_id',true),'')::uuid OR
    (NULLIF(current_setting('app.admin_staff_id',true),'') IS NOT NULL AND current_setting('app.admin_role',true) IN ('SUPER_ADMIN','BUSINESS_ADMIN'))
  ))
  WITH CHECK (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND (
    sender_account_id=NULLIF(current_setting('app.account_id',true),'')::uuid OR
    owner_account_id=NULLIF(current_setting('app.account_id',true),'')::uuid OR
    (NULLIF(current_setting('app.admin_staff_id',true),'') IS NOT NULL AND current_setting('app.admin_role',true) IN ('SUPER_ADMIN','BUSINESS_ADMIN'))
  ));

ALTER TABLE public.business_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.business_reports FORCE ROW LEVEL SECURITY;
CREATE POLICY business_reports_reporter_or_admin ON public.business_reports
  FOR ALL TO PUBLIC
  USING (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND (
    reporter_account_id=NULLIF(current_setting('app.account_id',true),'')::uuid OR
    (NULLIF(current_setting('app.admin_staff_id',true),'') IS NOT NULL AND current_setting('app.admin_role',true) IN ('SUPER_ADMIN','BUSINESS_ADMIN'))
  ))
  WITH CHECK (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND (
    reporter_account_id=NULLIF(current_setting('app.account_id',true),'')::uuid OR
    (NULLIF(current_setting('app.admin_staff_id',true),'') IS NOT NULL AND current_setting('app.admin_role',true) IN ('SUPER_ADMIN','BUSINESS_ADMIN'))
  ));

-- Verify every newly protected table is actually forced through RLS.
DO $sakhi_member_rls_postflight$
DECLARE table_name TEXT;
BEGIN
  FOREACH table_name IN ARRAY ARRAY[
    'member_accounts','auth_sessions','otp_challenges','account_deletion_requests','member_profiles','member_consents',
    'member_communication_preferences','eligibility_submissions','community_posts',
    'community_post_likes','community_post_saves','community_post_comments',
    'community_groups','community_circle_memberships','community_circle_posts',
    'member_follows','member_privacy_preferences','member_notification_preferences',
    'member_push_tokens','member_wellness_preferences','member_notifications',
    'safety_emergency_contacts','safety_sos_events','safety_location_shares',
    'member_moderation_blocks','member_user_reports','direct_messages','media_assets',
    'community_post_reactions','business_directory_listings','business_enquiries','business_reports'
  ] LOOP
    IF NOT EXISTS (
      SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
      WHERE n.nspname='public' AND c.relname=table_name AND c.relrowsecurity AND c.relforcerowsecurity
    ) THEN
      RAISE EXCEPTION 'RLS is not enabled and forced on public.%', table_name;
    END IF;
  END LOOP;
END
$sakhi_member_rls_postflight$;
