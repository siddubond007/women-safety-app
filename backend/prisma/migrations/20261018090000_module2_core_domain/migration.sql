-- Module 2 Core Domain: Profile extensions, Community Feed, Explore, Wellness Hub,
-- Safety & SOS, Privacy Settings, Notification Preferences, Followers & Following,
-- Account Security & Moderation tables.

ALTER TABLE "member_profiles"
    ADD COLUMN IF NOT EXISTS "username" VARCHAR(50),
    ADD COLUMN IF NOT EXISTS "bio" VARCHAR(300) NOT NULL DEFAULT 'A passionate learner, exploring wellness, technology and meaningful connections. 💜',
    ADD COLUMN IF NOT EXISTS "location" VARCHAR(120) NOT NULL DEFAULT 'Bangalore, India',
    ADD COLUMN IF NOT EXISTS "avatar_asset" VARCHAR(255) NOT NULL DEFAULT 'assets/images/profile/avatar_siddhu.webp',
    ADD COLUMN IF NOT EXISTS "interests" JSONB NOT NULL DEFAULT '["Mental Wellness","Travel","Reading","WomenInTech","Art","Fitness"]'::jsonb,
    ADD COLUMN IF NOT EXISTS "business_profile_url" VARCHAR(255),
    ADD COLUMN IF NOT EXISTS "two_factor_enabled" BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS "security_pin_updated_at" TIMESTAMPTZ(6);

CREATE UNIQUE INDEX IF NOT EXISTS "member_profiles_username_key"
    ON "member_profiles"("username");

CREATE TABLE IF NOT EXISTS "community_posts" (
    "id" UUID NOT NULL,
    "author_account_id" UUID,
    "author_name" VARCHAR(100) NOT NULL,
    "author_username" VARCHAR(50) NOT NULL,
    "author_avatar" VARCHAR(255) NOT NULL,
    "author_verified" BOOLEAN NOT NULL DEFAULT FALSE,
    "content" TEXT NOT NULL,
    "image_asset" VARCHAR(255),
    "category_badge" VARCHAR(64),
    "feed_section" VARCHAR(32) NOT NULL DEFAULT 'community',
    "has_breathing_exercise_card" BOOLEAN NOT NULL DEFAULT FALSE,
    "likes_count" INTEGER NOT NULL DEFAULT 0,
    "comments_count" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "community_posts_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "community_posts_author_account_id_fkey"
        FOREIGN KEY ("author_account_id") REFERENCES "member_accounts"("id")
        ON DELETE SET NULL ON UPDATE CASCADE
);

CREATE INDEX IF NOT EXISTS "community_posts_section_created_idx"
    ON "community_posts"("feed_section", "created_at");
CREATE INDEX IF NOT EXISTS "community_posts_author_created_idx"
    ON "community_posts"("author_account_id", "created_at");

CREATE TABLE IF NOT EXISTS "community_post_likes" (
    "id" UUID NOT NULL,
    "post_id" UUID NOT NULL,
    "account_id" UUID NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "community_post_likes_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "community_post_likes_post_id_fkey"
        FOREIGN KEY ("post_id") REFERENCES "community_posts"("id")
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT "community_post_likes_account_id_fkey"
        FOREIGN KEY ("account_id") REFERENCES "member_accounts"("id")
        ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE UNIQUE INDEX IF NOT EXISTS "community_post_likes_post_account_key"
    ON "community_post_likes"("post_id", "account_id");
CREATE INDEX IF NOT EXISTS "community_post_likes_account_idx"
    ON "community_post_likes"("account_id");

CREATE TABLE IF NOT EXISTS "community_post_saves" (
    "id" UUID NOT NULL,
    "post_id" UUID NOT NULL,
    "account_id" UUID NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "community_post_saves_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "community_post_saves_post_id_fkey"
        FOREIGN KEY ("post_id") REFERENCES "community_posts"("id")
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT "community_post_saves_account_id_fkey"
        FOREIGN KEY ("account_id") REFERENCES "member_accounts"("id")
        ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE UNIQUE INDEX IF NOT EXISTS "community_post_saves_post_account_key"
    ON "community_post_saves"("post_id", "account_id");
CREATE INDEX IF NOT EXISTS "community_post_saves_account_idx"
    ON "community_post_saves"("account_id");

CREATE TABLE IF NOT EXISTS "community_post_comments" (
    "id" UUID NOT NULL,
    "post_id" UUID NOT NULL,
    "account_id" UUID NOT NULL,
    "author_name" VARCHAR(100) NOT NULL,
    "content" VARCHAR(500) NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "community_post_comments_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "community_post_comments_post_id_fkey"
        FOREIGN KEY ("post_id") REFERENCES "community_posts"("id")
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT "community_post_comments_account_id_fkey"
        FOREIGN KEY ("account_id") REFERENCES "member_accounts"("id")
        ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX IF NOT EXISTS "community_post_comments_post_created_idx"
    ON "community_post_comments"("post_id", "created_at");

CREATE TABLE IF NOT EXISTS "community_groups" (
    "id" UUID NOT NULL,
    "name" VARCHAR(120) NOT NULL,
    "description" VARCHAR(300) NOT NULL,
    "category" VARCHAR(64) NOT NULL,
    "members_count" INTEGER NOT NULL DEFAULT 1,
    "new_posts_today" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "community_groups_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX IF NOT EXISTS "community_groups_name_key"
    ON "community_groups"("name");

CREATE TABLE IF NOT EXISTS "community_directory_profiles" (
    "id" UUID NOT NULL,
    "name" VARCHAR(100) NOT NULL,
    "username" VARCHAR(50) NOT NULL,
    "avatar_asset" VARCHAR(255) NOT NULL,
    "bio" VARCHAR(255),
    "default_following" BOOLEAN NOT NULL DEFAULT FALSE,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "community_directory_profiles_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX IF NOT EXISTS "community_directory_profiles_username_key"
    ON "community_directory_profiles"("username");

CREATE TABLE IF NOT EXISTS "member_follows" (
    "id" UUID NOT NULL,
    "account_id" UUID NOT NULL,
    "directory_profile_id" UUID NOT NULL,
    "is_following" BOOLEAN NOT NULL DEFAULT TRUE,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "member_follows_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "member_follows_account_id_fkey"
        FOREIGN KEY ("account_id") REFERENCES "member_accounts"("id")
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT "member_follows_directory_profile_id_fkey"
        FOREIGN KEY ("directory_profile_id") REFERENCES "community_directory_profiles"("id")
        ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE UNIQUE INDEX IF NOT EXISTS "member_follows_account_profile_key"
    ON "member_follows"("account_id", "directory_profile_id");
CREATE INDEX IF NOT EXISTS "member_follows_account_idx"
    ON "member_follows"("account_id");

CREATE TABLE IF NOT EXISTS "member_privacy_preferences" (
    "account_id" UUID NOT NULL,
    "view_profile" VARCHAR(64) NOT NULL DEFAULT 'Verified members only',
    "message_me" VARCHAR(64) NOT NULL DEFAULT 'Verified members only',
    "see_posts" VARCHAR(64) NOT NULL DEFAULT 'Verified members only',
    "show_location" VARCHAR(64) NOT NULL DEFAULT 'General location only',
    "search_results" VARCHAR(32) NOT NULL DEFAULT 'Yes',
    "business_enquiries" VARCHAR(64) NOT NULL DEFAULT 'Yes',
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "member_privacy_preferences_pkey" PRIMARY KEY ("account_id"),
    CONSTRAINT "member_privacy_preferences_account_id_fkey"
        FOREIGN KEY ("account_id") REFERENCES "member_accounts"("id")
        ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE IF NOT EXISTS "member_notification_preferences" (
    "account_id" UUID NOT NULL,
    "community_updates" BOOLEAN NOT NULL DEFAULT TRUE,
    "group_activity" BOOLEAN NOT NULL DEFAULT TRUE,
    "wellness_reminders" BOOLEAN NOT NULL DEFAULT TRUE,
    "safety_alerts" BOOLEAN NOT NULL DEFAULT TRUE,
    "messages" BOOLEAN NOT NULL DEFAULT TRUE,
    "business_enquiries" BOOLEAN NOT NULL DEFAULT TRUE,
    "marketing_updates" BOOLEAN NOT NULL DEFAULT FALSE,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "member_notification_preferences_pkey" PRIMARY KEY ("account_id"),
    CONSTRAINT "member_notification_preferences_account_id_fkey"
        FOREIGN KEY ("account_id") REFERENCES "member_accounts"("id")
        ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE IF NOT EXISTS "safety_emergency_contacts" (
    "id" UUID NOT NULL,
    "account_id" UUID NOT NULL,
    "name" VARCHAR(100) NOT NULL,
    "relationship" VARCHAR(64) NOT NULL,
    "phone_e164" VARCHAR(16) NOT NULL,
    "is_trusted_location_contact" BOOLEAN NOT NULL DEFAULT TRUE,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "safety_emergency_contacts_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "safety_emergency_contacts_account_id_fkey"
        FOREIGN KEY ("account_id") REFERENCES "member_accounts"("id")
        ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX IF NOT EXISTS "safety_emergency_contacts_account_idx"
    ON "safety_emergency_contacts"("account_id");

CREATE TABLE IF NOT EXISTS "safety_sos_events" (
    "id" UUID NOT NULL,
    "account_id" UUID NOT NULL,
    "event_type" VARCHAR(32) NOT NULL,
    "status" VARCHAR(32) NOT NULL DEFAULT 'RECORDED',
    "location_label" VARCHAR(120),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "safety_sos_events_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "safety_sos_events_account_id_fkey"
        FOREIGN KEY ("account_id") REFERENCES "member_accounts"("id")
        ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX IF NOT EXISTS "safety_sos_events_account_created_idx"
    ON "safety_sos_events"("account_id", "created_at");

CREATE TABLE IF NOT EXISTS "wellness_resources" (
    "id" UUID NOT NULL,
    "slug" VARCHAR(64) NOT NULL,
    "category" VARCHAR(64) NOT NULL,
    "title" VARCHAR(150) NOT NULL,
    "subtitle" VARCHAR(255) NOT NULL,
    "duration_label" VARCHAR(64),
    "thumb_asset" VARCHAR(255),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "wellness_resources_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX IF NOT EXISTS "wellness_resources_slug_key"
    ON "wellness_resources"("slug");

CREATE TABLE IF NOT EXISTS "member_moderation_blocks" (
    "id" UUID NOT NULL,
    "account_id" UUID NOT NULL,
    "blocked_username" VARCHAR(50) NOT NULL,
    "blocked_display_name" VARCHAR(100) NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "member_moderation_blocks_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "member_moderation_blocks_account_id_fkey"
        FOREIGN KEY ("account_id") REFERENCES "member_accounts"("id")
        ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE UNIQUE INDEX IF NOT EXISTS "member_moderation_blocks_account_username_key"
    ON "member_moderation_blocks"("account_id", "blocked_username");
CREATE INDEX IF NOT EXISTS "member_moderation_blocks_account_idx"
    ON "member_moderation_blocks"("account_id");

CREATE TABLE IF NOT EXISTS "member_user_reports" (
    "id" UUID NOT NULL,
    "reporter_account_id" UUID NOT NULL,
    "target_handle" VARCHAR(100) NOT NULL,
    "reason" VARCHAR(500) NOT NULL,
    "status" VARCHAR(32) NOT NULL DEFAULT 'SUBMITTED',
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "member_user_reports_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "member_user_reports_reporter_account_id_fkey"
        FOREIGN KEY ("reporter_account_id") REFERENCES "member_accounts"("id")
        ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX IF NOT EXISTS "member_user_reports_reporter_created_idx"
    ON "member_user_reports"("reporter_account_id", "created_at");

DO $grant_module2_permissions$
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

    EXECUTE format('GRANT USAGE ON SCHEMA public TO %I', app_role);
    EXECUTE format(
        'GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE
            community_posts,
            community_post_likes,
            community_post_saves,
            community_post_comments,
            community_groups,
            community_directory_profiles,
            member_follows,
            member_privacy_preferences,
            member_notification_preferences,
            safety_emergency_contacts,
            safety_sos_events,
            wellness_resources,
            member_moderation_blocks,
            member_user_reports
         TO %I',
        app_role
    );
END
$grant_module2_permissions$;
