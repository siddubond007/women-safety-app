-- ============================================================================
-- Sakhi Platform — Wellness Preferences, Active Circles, Quiet Hours,
-- Push Token Registration & Admin Credential Authentication Migration
-- Migration ID: 20261107120000_sakhi_wellness_circles_admin_auth_hardening
-- Strictly additive; preserves all existing user data and RLS boundaries.
-- ============================================================================

-- 1. Wellness Studio: Server-saved voice, music category, onboarding & cache rotation preferences (Section 4.2)
CREATE TABLE IF NOT EXISTS "member_wellness_preferences" (
  "account_id" UUID NOT NULL,
  "selected_voice_id" VARCHAR(16) NOT NULL DEFAULT 'V01',
  "selected_music_id" VARCHAR(16) NOT NULL DEFAULT 'M01',
  "selected_music_category" VARCHAR(64) NOT NULL DEFAULT 'CHOOSE_FOR_ME',
  "music_selection_mode" VARCHAR(24) NOT NULL DEFAULT 'RANDOM',
  "preferred_duration_minutes" INT NOT NULL DEFAULT 7,
  "voice_volume" DOUBLE PRECISION NOT NULL DEFAULT 0.92,
  "music_volume" DOUBLE PRECISION NOT NULL DEFAULT 0.65,
  "has_completed_onboarding" BOOLEAN NOT NULL DEFAULT false,
  "recent_track_ids" JSONB NOT NULL DEFAULT '[]'::jsonb,
  "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "member_wellness_preferences_pkey" PRIMARY KEY ("account_id"),
  CONSTRAINT "member_wellness_preferences_account_id_fkey"
    FOREIGN KEY ("account_id") REFERENCES "member_accounts"("id")
    ON DELETE CASCADE ON UPDATE CASCADE
);

ALTER TABLE "member_wellness_preferences" ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "member_wellness_preferences_backend_runtime_access"
  ON "member_wellness_preferences";
CREATE POLICY "member_wellness_preferences_backend_runtime_access"
  ON "member_wellness_preferences"
  AS PERMISSIVE
  FOR ALL
  TO PUBLIC
  USING (current_user IN ('sakhi_dev_app', 'sakhi_test_app', 'sakhi_staging_app'))
  WITH CHECK (current_user IN ('sakhi_dev_app', 'sakhi_test_app', 'sakhi_staging_app'));

-- 2. Notifications: Quiet hours, timezone & circle activity preferences + Push Token Registration (Section 7.2)
ALTER TABLE "member_notification_preferences"
  ADD COLUMN IF NOT EXISTS "circle_activity" BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS "quiet_hours_enabled" BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS "quiet_hours_start" VARCHAR(8) NOT NULL DEFAULT '22:00',
  ADD COLUMN IF NOT EXISTS "quiet_hours_end" VARCHAR(8) NOT NULL DEFAULT '07:00',
  ADD COLUMN IF NOT EXISTS "quiet_hours_timezone" VARCHAR(64) NOT NULL DEFAULT 'Asia/Kolkata';

CREATE TABLE IF NOT EXISTS "member_push_tokens" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "account_id" UUID NOT NULL,
  "platform" VARCHAR(24) NOT NULL DEFAULT 'ANDROID',
  "provider" VARCHAR(24) NOT NULL DEFAULT 'FCM',
  "token_digest" VARCHAR(64) NOT NULL,
  "encrypted_token" TEXT NOT NULL,
  "device_name" VARCHAR(120),
  "is_enabled" BOOLEAN NOT NULL DEFAULT true,
  "last_registered_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "member_push_tokens_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "member_push_tokens_account_id_fkey"
    FOREIGN KEY ("account_id") REFERENCES "member_accounts"("id")
    ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE UNIQUE INDEX IF NOT EXISTS "member_push_tokens_token_digest_key"
  ON "member_push_tokens"("token_digest");

CREATE INDEX IF NOT EXISTS "member_push_tokens_account_enabled_idx"
  ON "member_push_tokens"("account_id", "is_enabled");

ALTER TABLE "member_push_tokens" ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "member_push_tokens_backend_runtime_access"
  ON "member_push_tokens";
CREATE POLICY "member_push_tokens_backend_runtime_access"
  ON "member_push_tokens"
  AS PERMISSIVE
  FOR ALL
  TO PUBLIC
  USING (current_user IN ('sakhi_dev_app', 'sakhi_test_app', 'sakhi_staging_app'))
  WITH CHECK (current_user IN ('sakhi_dev_app', 'sakhi_test_app', 'sakhi_staging_app'));

-- 3. Active Circles: Moderated Community/Channel Model (Section 7.3)
ALTER TABLE "community_groups"
  ADD COLUMN IF NOT EXISTS "slug" VARCHAR(80),
  ADD COLUMN IF NOT EXISTS "purpose" VARCHAR(500) NOT NULL DEFAULT 'Supportive women''s peer circle and moderated channel.',
  ADD COLUMN IF NOT EXISTS "owner_account_id" UUID,
  ADD COLUMN IF NOT EXISTS "owner_display_name" VARCHAR(120) NOT NULL DEFAULT 'Sakhi Community Host',
  ADD COLUMN IF NOT EXISTS "visibility" VARCHAR(32) NOT NULL DEFAULT 'PUBLIC_VERIFIED',
  ADD COLUMN IF NOT EXISTS "location_scope" VARCHAR(120) NOT NULL DEFAULT 'Pan-India',
  ADD COLUMN IF NOT EXISTS "rules" JSONB NOT NULL DEFAULT '["Be respectful and supportive","Protect member privacy","No spam or unsolicited promotions"]'::jsonb,
  ADD COLUMN IF NOT EXISTS "activity_state" VARCHAR(24) NOT NULL DEFAULT 'ACTIVE',
  ADD COLUMN IF NOT EXISTS "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP;

CREATE UNIQUE INDEX IF NOT EXISTS "community_groups_slug_key"
  ON "community_groups"("slug");

CREATE INDEX IF NOT EXISTS "community_groups_category_state_idx"
  ON "community_groups"("category", "activity_state");

CREATE TABLE IF NOT EXISTS "community_circle_memberships" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "circle_id" UUID NOT NULL,
  "account_id" UUID NOT NULL,
  "role" VARCHAR(24) NOT NULL DEFAULT 'MEMBER',
  "status" VARCHAR(24) NOT NULL DEFAULT 'ACTIVE',
  "notifications_enabled" BOOLEAN NOT NULL DEFAULT true,
  "joined_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "community_circle_memberships_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "community_circle_memberships_circle_id_fkey"
    FOREIGN KEY ("circle_id") REFERENCES "community_groups"("id")
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "community_circle_memberships_account_id_fkey"
    FOREIGN KEY ("account_id") REFERENCES "member_accounts"("id")
    ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE UNIQUE INDEX IF NOT EXISTS "community_circle_memberships_circle_account_key"
  ON "community_circle_memberships"("circle_id", "account_id");

CREATE INDEX IF NOT EXISTS "community_circle_memberships_account_status_idx"
  ON "community_circle_memberships"("account_id", "status");

CREATE INDEX IF NOT EXISTS "community_circle_memberships_circle_role_idx"
  ON "community_circle_memberships"("circle_id", "role", "status");

CREATE TABLE IF NOT EXISTS "community_circle_posts" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "circle_id" UUID NOT NULL,
  "author_account_id" UUID NOT NULL,
  "author_name" VARCHAR(100) NOT NULL,
  "author_username" VARCHAR(50) NOT NULL,
  "author_role" VARCHAR(24) NOT NULL DEFAULT 'MEMBER',
  "post_type" VARCHAR(24) NOT NULL DEFAULT 'DISCUSSION',
  "is_pinned" BOOLEAN NOT NULL DEFAULT false,
  "content" TEXT NOT NULL,
  "likes_count" INT NOT NULL DEFAULT 0,
  "comments" JSONB NOT NULL DEFAULT '[]'::jsonb,
  "status" VARCHAR(24) NOT NULL DEFAULT 'PUBLISHED',
  "moderation_reason" VARCHAR(500),
  "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "community_circle_posts_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "community_circle_posts_circle_id_fkey"
    FOREIGN KEY ("circle_id") REFERENCES "community_groups"("id")
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "community_circle_posts_author_account_fkey"
    FOREIGN KEY ("author_account_id") REFERENCES "member_accounts"("id")
    ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX IF NOT EXISTS "community_circle_posts_circle_status_created_idx"
  ON "community_circle_posts"("circle_id", "status", "is_pinned", "created_at");

CREATE INDEX IF NOT EXISTS "community_circle_posts_author_created_idx"
  ON "community_circle_posts"("author_account_id", "created_at");

-- 4. Admin Portal Credential Authentication & Session Rotation (Section 10)
ALTER TABLE "admin_staff_accounts"
  ADD COLUMN IF NOT EXISTS "username" VARCHAR(64),
  ADD COLUMN IF NOT EXISTS "password_hash" VARCHAR(255),
  ADD COLUMN IF NOT EXISTS "password_updated_at" TIMESTAMPTZ(6),
  ADD COLUMN IF NOT EXISTS "must_reset_password" BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS "failed_login_attempts" INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS "locked_until" TIMESTAMPTZ(6),
  ADD COLUMN IF NOT EXISTS "mfa_enabled" BOOLEAN NOT NULL DEFAULT false;

CREATE UNIQUE INDEX IF NOT EXISTS "admin_staff_accounts_username_key"
  ON "admin_staff_accounts"("username");

CREATE TABLE IF NOT EXISTS "admin_auth_sessions" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "staff_id" VARCHAR(64) NOT NULL,
  "session_token_digest" VARCHAR(64) NOT NULL,
  "refresh_token_digest" VARCHAR(64),
  "csrf_token" VARCHAR(64) NOT NULL,
  "ip_address_hash" VARCHAR(64),
  "user_agent" VARCHAR(255),
  "expires_at" TIMESTAMPTZ(6) NOT NULL,
  "revoked_at" TIMESTAMPTZ(6),
  "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "last_rotated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "admin_auth_sessions_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX IF NOT EXISTS "admin_auth_sessions_token_digest_key"
  ON "admin_auth_sessions"("session_token_digest");

CREATE UNIQUE INDEX IF NOT EXISTS "admin_auth_sessions_refresh_digest_key"
  ON "admin_auth_sessions"("refresh_token_digest");

CREATE INDEX IF NOT EXISTS "admin_auth_sessions_staff_expiry_idx"
  ON "admin_auth_sessions"("staff_id", "expires_at");

CREATE INDEX IF NOT EXISTS "admin_auth_sessions_expiry_idx"
  ON "admin_auth_sessions"("expires_at");

ALTER TABLE "admin_auth_sessions" ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "admin_auth_sessions_backend_runtime_access"
  ON "admin_auth_sessions";
CREATE POLICY "admin_auth_sessions_backend_runtime_access"
  ON "admin_auth_sessions"
  AS PERMISSIVE
  FOR ALL
  TO PUBLIC
  USING (current_user IN ('sakhi_dev_app', 'sakhi_test_app', 'sakhi_staging_app'))
  WITH CHECK (current_user IN ('sakhi_dev_app', 'sakhi_test_app', 'sakhi_staging_app'));

-- 5. Conditional Least-Privilege Runtime Role Grants
DO $grant_sakhi_20261107_runtime_permissions$
DECLARE
    role_name TEXT;
BEGIN
    FOREACH role_name IN ARRAY ARRAY['sakhi_dev_app', 'sakhi_test_app', 'sakhi_staging_app']
    LOOP
        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = role_name) THEN
            EXECUTE format(
                'GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.member_wellness_preferences TO %I',
                role_name
            );
            EXECUTE format(
                'GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.member_push_tokens TO %I',
                role_name
            );
            EXECUTE format(
                'GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.community_groups TO %I',
                role_name
            );
            EXECUTE format(
                'GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.community_circle_memberships TO %I',
                role_name
            );
            EXECUTE format(
                'GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.community_circle_posts TO %I',
                role_name
            );
            EXECUTE format(
                'GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.admin_staff_accounts TO %I',
                role_name
            );
            EXECUTE format(
                'GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.admin_auth_sessions TO %I',
                role_name
            );
        END IF;
    END LOOP;
END
$grant_sakhi_20261107_runtime_permissions$;
