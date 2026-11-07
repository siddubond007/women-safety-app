-- Module 3: Social Media Wall, 6 Feed Categories, Reactions, MediaAssets (Google Drive Hierarchy), and Moderation Decisions
-- Strictly additive migration on sakhi_dev / sakhi_test only.

DO $module3_database_guard$
BEGIN
    IF current_database() NOT IN ('sakhi_dev', 'sakhi_test') THEN
        RAISE EXCEPTION 'Module 3 migration may only run on sakhi_dev or sakhi_test; current database is %', current_database();
    END IF;
END
$module3_database_guard$;

ALTER TABLE "member_profiles"
    ADD COLUMN IF NOT EXISTS "avatar_media_asset_id" UUID,
    ADD COLUMN IF NOT EXISTS "business_profile_name" VARCHAR(120),
    ADD COLUMN IF NOT EXISTS "business_category" VARCHAR(80);

ALTER TABLE "community_posts"
    ADD COLUMN IF NOT EXISTS "category_slug" VARCHAR(40) NOT NULL DEFAULT 'community',
    ADD COLUMN IF NOT EXISTS "visibility" VARCHAR(32) NOT NULL DEFAULT 'VERIFIED_MEMBERS',
    ADD COLUMN IF NOT EXISTS "status" VARCHAR(32) NOT NULL DEFAULT 'PUBLISHED',
    ADD COLUMN IF NOT EXISTS "hashtags" JSONB NOT NULL DEFAULT '[]'::jsonb,
    ADD COLUMN IF NOT EXISTS "location_tag" VARCHAR(120),
    ADD COLUMN IF NOT EXISTS "allow_comments" BOOLEAN NOT NULL DEFAULT TRUE,
    ADD COLUMN IF NOT EXISTS "share_to_business_profile" BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS "crop_preset" VARCHAR(16) NOT NULL DEFAULT '4:5',
    ADD COLUMN IF NOT EXISTS "saves_count" INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS "shares_count" INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS "moderation_reason" VARCHAR(500),
    ADD COLUMN IF NOT EXISTS "deleted_at" TIMESTAMPTZ(6);

CREATE INDEX IF NOT EXISTS "community_posts_category_status_created_idx"
    ON "community_posts"("category_slug", "status", "created_at" DESC);

ALTER TABLE "community_post_comments"
    ADD COLUMN IF NOT EXISTS "is_removed_by_moderator" BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS "deleted_at" TIMESTAMPTZ(6),
    ADD COLUMN IF NOT EXISTS "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE "member_user_reports"
    ADD COLUMN IF NOT EXISTS "target_type" VARCHAR(32) NOT NULL DEFAULT 'POST',
    ADD COLUMN IF NOT EXISTS "post_id" UUID,
    ADD COLUMN IF NOT EXISTS "comment_id" UUID,
    ADD COLUMN IF NOT EXISTS "category" VARCHAR(64) NOT NULL DEFAULT 'SAFETY_CONCERN',
    ADD COLUMN IF NOT EXISTS "details" VARCHAR(1000),
    ADD COLUMN IF NOT EXISTS "reviewer_notes" VARCHAR(1000),
    ADD COLUMN IF NOT EXISTS "reviewed_by" VARCHAR(120),
    ADD COLUMN IF NOT EXISTS "reviewed_at" TIMESTAMPTZ(6);

CREATE TABLE IF NOT EXISTS "feed_category_configs" (
    "slug" VARCHAR(40) NOT NULL,
    "name" VARCHAR(80) NOT NULL,
    "description" VARCHAR(300) NOT NULL,
    "icon_key" VARCHAR(40) NOT NULL DEFAULT 'sparkles',
    "accent_color_hex" VARCHAR(16) NOT NULL DEFAULT '#EC4899',
    "is_enabled" BOOLEAN NOT NULL DEFAULT TRUE,
    "display_order" INTEGER NOT NULL DEFAULT 0,
    "updated_by" VARCHAR(120),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "feed_category_configs_pkey" PRIMARY KEY ("slug")
);

CREATE INDEX IF NOT EXISTS "feed_category_configs_enabled_order_idx"
    ON "feed_category_configs"("is_enabled", "display_order" ASC);

CREATE TABLE IF NOT EXISTS "media_assets" (
    "id" UUID NOT NULL,
    "owner_account_id" UUID NOT NULL,
    "post_id" UUID,
    "purpose" VARCHAR(32) NOT NULL DEFAULT 'COMMUNITY_POST_IMAGE',
    "storage_provider" VARCHAR(32) NOT NULL DEFAULT 'GOOGLE_DRIVE',
    "status" VARCHAR(32) NOT NULL DEFAULT 'UPLOADED',
    "category_slug" VARCHAR(40),
    "drive_file_id" VARCHAR(160),
    "drive_folder_id" VARCHAR(160),
    "drive_folder_path" VARCHAR(500) NOT NULL,
    "local_asset_path" VARCHAR(255),
    "original_file_name" VARCHAR(255) NOT NULL,
    "content_type" VARCHAR(80) NOT NULL,
    "byte_size" INTEGER NOT NULL,
    "width_px" INTEGER,
    "height_px" INTEGER,
    "crop_aspect_ratio" VARCHAR(16) NOT NULL DEFAULT '4:5',
    "sha256_checksum" VARCHAR(64),
    "visibility" VARCHAR(32) NOT NULL DEFAULT 'VERIFIED_MEMBERS',
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "deleted_at" TIMESTAMPTZ(6),
    CONSTRAINT "media_assets_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "media_assets_owner_account_id_fkey"
        FOREIGN KEY ("owner_account_id") REFERENCES "member_accounts"("id")
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT "media_assets_post_id_fkey"
        FOREIGN KEY ("post_id") REFERENCES "community_posts"("id")
        ON DELETE SET NULL ON UPDATE CASCADE
);

CREATE INDEX IF NOT EXISTS "media_assets_owner_purpose_status_idx"
    ON "media_assets"("owner_account_id", "purpose", "status");
CREATE INDEX IF NOT EXISTS "media_assets_post_status_idx"
    ON "media_assets"("post_id", "status");
CREATE INDEX IF NOT EXISTS "media_assets_drive_file_id_idx"
    ON "media_assets"("drive_file_id");

CREATE TABLE IF NOT EXISTS "community_post_reactions" (
    "id" UUID NOT NULL,
    "post_id" UUID NOT NULL,
    "account_id" UUID NOT NULL,
    "reaction_type" VARCHAR(32) NOT NULL DEFAULT 'LIKE',
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "community_post_reactions_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "community_post_reactions_post_id_fkey"
        FOREIGN KEY ("post_id") REFERENCES "community_posts"("id")
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT "community_post_reactions_account_id_fkey"
        FOREIGN KEY ("account_id") REFERENCES "member_accounts"("id")
        ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE UNIQUE INDEX IF NOT EXISTS "community_post_reactions_post_account_key"
    ON "community_post_reactions"("post_id", "account_id");
CREATE INDEX IF NOT EXISTS "community_post_reactions_post_type_idx"
    ON "community_post_reactions"("post_id", "reaction_type");

CREATE TABLE IF NOT EXISTS "moderation_decisions" (
    "id" UUID NOT NULL,
    "report_id" UUID,
    "target_type" VARCHAR(32) NOT NULL,
    "target_account_id" UUID,
    "target_post_id" UUID,
    "target_comment_id" UUID,
    "action_type" VARCHAR(40) NOT NULL,
    "reason" VARCHAR(1000) NOT NULL,
    "reviewer_label" VARCHAR(120) NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "moderation_decisions_pkey" PRIMARY KEY ("id")
);

CREATE INDEX IF NOT EXISTS "moderation_decisions_target_created_idx"
    ON "moderation_decisions"("target_type", "created_at" DESC);

INSERT INTO "feed_category_configs" ("slug", "name", "description", "icon_key", "accent_color_hex", "is_enabled", "display_order", "updated_by")
VALUES
    ('following', 'Following', 'Updates from verified Sakhi members and circles you follow.', 'heart_handshake', '#EC4899', TRUE, 1, 'system-seed'),
    ('community', 'Community', 'Open discussions, peer encouragement, and shared experiences.', 'users', '#A855F7', TRUE, 2, 'system-seed'),
    ('trending', 'Trending', 'High-engagement conversations and timely topics across Sakhi.', 'flame', '#F59E0B', TRUE, 3, 'system-seed'),
    ('business_updates', 'Business Updates', 'Showcases, launches, and announcements from women-led businesses.', 'briefcase', '#8B5CF6', TRUE, 4, 'system-seed'),
    ('safety_awareness', 'Safety Awareness', 'Verified safety advisories, commute tips, and legal/self-defense awareness.', 'shield_check', '#10B981', TRUE, 5, 'system-seed'),
    ('wellness_lifestyle', 'Wellness and Lifestyle', 'Mindfulness, physical health, journaling, and holistic lifestyle guidance.', 'sparkles', '#14B8A6', TRUE, 6, 'system-seed')
ON CONFLICT ("slug") DO NOTHING;

DO $grant_module3_runtime_permissions$
DECLARE
    app_role TEXT;
BEGIN
    IF current_database() = 'sakhi_dev' THEN
        app_role := 'sakhi_dev_app';
    ELSIF current_database() = 'sakhi_test' THEN
        app_role := 'sakhi_test_app';
    ELSE
        RAISE EXCEPTION 'Sakhi migrations may only run on sakhi_dev or sakhi_test';
    END IF;

    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = app_role) THEN
        EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE feed_category_configs TO %I', app_role);
        EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE media_assets TO %I', app_role);
        EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE community_post_reactions TO %I', app_role);
        EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE moderation_decisions TO %I', app_role);
        EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE community_posts TO %I', app_role);
        EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE community_post_comments TO %I', app_role);
        EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE member_user_reports TO %I', app_role);
    END IF;
END
$grant_module3_runtime_permissions$;
