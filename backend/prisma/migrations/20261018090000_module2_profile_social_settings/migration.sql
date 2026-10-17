-- Module 2: profile, community/social graph, privacy, notifications and account lifecycle.
-- Additive migration only. No reset/drop operations. The migration is restricted
-- to the two Sakhi development/test databases by the role grant block below.

CREATE TYPE "profile_visibility" AS ENUM ('VERIFIED_MEMBERS', 'FOLLOWERS_ONLY', 'ONLY_ME');
CREATE TYPE "message_permission" AS ENUM ('VERIFIED_MEMBERS', 'FOLLOWING_ONLY', 'NO_ONE');
CREATE TYPE "post_audience" AS ENUM ('VERIFIED_MEMBERS', 'FOLLOWERS', 'SELECTED_MEMBERS', 'ONLY_ME');
CREATE TYPE "location_sharing_mode" AS ENUM ('HIDDEN', 'CITY_ONLY');
CREATE TYPE "business_enquiry_permission" AS ENUM ('ALL_VERIFIED', 'VERIFIED_BUSINESSES', 'NONE');
CREATE TYPE "member_post_status" AS ENUM ('PUBLISHED', 'HIDDEN', 'REMOVED');
CREATE TYPE "member_report_reason" AS ENUM ('HARASSMENT', 'IMPERSONATION', 'SPAM', 'UNSAFE_CONTENT', 'OTHER');
CREATE TYPE "member_report_status" AS ENUM ('OPEN', 'REVIEWED', 'CLOSED');
CREATE TYPE "business_profile_status" AS ENUM ('PENDING_REVIEW', 'VERIFIED', 'REJECTED');
CREATE TYPE "account_deletion_status" AS ENUM ('REQUESTED', 'PROCESSING', 'COMPLETED', 'CANCELLED');

ALTER TABLE "member_profiles"
    ADD COLUMN "bio" VARCHAR(500),
    ADD COLUMN "location_city" VARCHAR(100),
    ADD COLUMN "interests" TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[];

CREATE TABLE "member_posts" (
    "id" UUID NOT NULL,
    "account_id" UUID NOT NULL,
    "body" VARCHAR(5000) NOT NULL,
    "media_ref" VARCHAR(512),
    "audience" "post_audience" NOT NULL DEFAULT 'VERIFIED_MEMBERS',
    "status" "member_post_status" NOT NULL DEFAULT 'PUBLISHED',
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,
    "deleted_at" TIMESTAMPTZ(6),
    CONSTRAINT "member_posts_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "member_posts_account_id_fkey"
        FOREIGN KEY ("account_id") REFERENCES "member_accounts"("id")
        ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE "post_audience_members" (
    "post_id" UUID NOT NULL,
    "account_id" UUID NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "post_audience_members_pkey" PRIMARY KEY ("post_id", "account_id"),
    CONSTRAINT "post_audience_members_post_id_fkey"
        FOREIGN KEY ("post_id") REFERENCES "member_posts"("id")
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT "post_audience_members_account_id_fkey"
        FOREIGN KEY ("account_id") REFERENCES "member_accounts"("id")
        ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE "member_post_likes" (
    "post_id" UUID NOT NULL,
    "account_id" UUID NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "member_post_likes_pkey" PRIMARY KEY ("post_id", "account_id"),
    CONSTRAINT "member_post_likes_post_id_fkey"
        FOREIGN KEY ("post_id") REFERENCES "member_posts"("id")
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT "member_post_likes_account_id_fkey"
        FOREIGN KEY ("account_id") REFERENCES "member_accounts"("id")
        ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE "member_post_bookmarks" (
    "post_id" UUID NOT NULL,
    "account_id" UUID NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "member_post_bookmarks_pkey" PRIMARY KEY ("post_id", "account_id"),
    CONSTRAINT "member_post_bookmarks_post_id_fkey"
        FOREIGN KEY ("post_id") REFERENCES "member_posts"("id")
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT "member_post_bookmarks_account_id_fkey"
        FOREIGN KEY ("account_id") REFERENCES "member_accounts"("id")
        ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE "member_post_comments" (
    "id" UUID NOT NULL,
    "post_id" UUID NOT NULL,
    "account_id" UUID NOT NULL,
    "body" VARCHAR(2000) NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,
    "deleted_at" TIMESTAMPTZ(6),
    CONSTRAINT "member_post_comments_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "member_post_comments_post_id_fkey"
        FOREIGN KEY ("post_id") REFERENCES "member_posts"("id")
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT "member_post_comments_account_id_fkey"
        FOREIGN KEY ("account_id") REFERENCES "member_accounts"("id")
        ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE "social_follows" (
    "follower_account_id" UUID NOT NULL,
    "following_account_id" UUID NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "social_follows_pkey" PRIMARY KEY ("follower_account_id", "following_account_id"),
    CONSTRAINT "social_follows_not_self_check" CHECK ("follower_account_id" <> "following_account_id"),
    CONSTRAINT "social_follows_follower_account_id_fkey"
        FOREIGN KEY ("follower_account_id") REFERENCES "member_accounts"("id")
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT "social_follows_following_account_id_fkey"
        FOREIGN KEY ("following_account_id") REFERENCES "member_accounts"("id")
        ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE "member_privacy_settings" (
    "account_id" UUID NOT NULL,
    "profile_visibility" "profile_visibility" NOT NULL DEFAULT 'VERIFIED_MEMBERS',
    "message_permission" "message_permission" NOT NULL DEFAULT 'VERIFIED_MEMBERS',
    "default_post_audience" "post_audience" NOT NULL DEFAULT 'VERIFIED_MEMBERS',
    "location_sharing" "location_sharing_mode" NOT NULL DEFAULT 'HIDDEN',
    "appear_in_search" BOOLEAN NOT NULL DEFAULT TRUE,
    "business_enquiry_permission" "business_enquiry_permission" NOT NULL DEFAULT 'VERIFIED_BUSINESSES',
    "updated_at" TIMESTAMPTZ(6) NOT NULL,
    CONSTRAINT "member_privacy_settings_pkey" PRIMARY KEY ("account_id"),
    CONSTRAINT "member_privacy_settings_account_id_fkey"
        FOREIGN KEY ("account_id") REFERENCES "member_accounts"("id")
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT "member_privacy_default_audience_check"
        CHECK ("default_post_audience" <> 'SELECTED_MEMBERS')
);

CREATE TABLE "member_notification_preferences" (
    "account_id" UUID NOT NULL,
    "community_updates" BOOLEAN NOT NULL DEFAULT TRUE,
    "group_activity" BOOLEAN NOT NULL DEFAULT TRUE,
    "wellness_reminders" BOOLEAN NOT NULL DEFAULT TRUE,
    "safety_alerts" BOOLEAN NOT NULL DEFAULT TRUE,
    "messages" BOOLEAN NOT NULL DEFAULT TRUE,
    "business_enquiries" BOOLEAN NOT NULL DEFAULT TRUE,
    "marketing_updates" BOOLEAN NOT NULL DEFAULT FALSE,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,
    CONSTRAINT "member_notification_preferences_pkey" PRIMARY KEY ("account_id"),
    CONSTRAINT "member_notification_preferences_account_id_fkey"
        FOREIGN KEY ("account_id") REFERENCES "member_accounts"("id")
        ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE "member_blocks" (
    "blocker_account_id" UUID NOT NULL,
    "blocked_account_id" UUID NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "member_blocks_pkey" PRIMARY KEY ("blocker_account_id", "blocked_account_id"),
    CONSTRAINT "member_blocks_not_self_check" CHECK ("blocker_account_id" <> "blocked_account_id"),
    CONSTRAINT "member_blocks_blocker_account_id_fkey"
        FOREIGN KEY ("blocker_account_id") REFERENCES "member_accounts"("id")
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT "member_blocks_blocked_account_id_fkey"
        FOREIGN KEY ("blocked_account_id") REFERENCES "member_accounts"("id")
        ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE "member_reports" (
    "id" UUID NOT NULL,
    "reporter_account_id" UUID NOT NULL,
    "reported_account_id" UUID NOT NULL,
    "post_id" UUID,
    "reason" "member_report_reason" NOT NULL,
    "details" VARCHAR(1000),
    "status" "member_report_status" NOT NULL DEFAULT 'OPEN',
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "reviewed_at" TIMESTAMPTZ(6),
    CONSTRAINT "member_reports_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "member_reports_not_self_check" CHECK ("reporter_account_id" <> "reported_account_id"),
    CONSTRAINT "member_reports_reporter_account_id_fkey"
        FOREIGN KEY ("reporter_account_id") REFERENCES "member_accounts"("id")
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "member_reports_reported_account_id_fkey"
        FOREIGN KEY ("reported_account_id") REFERENCES "member_accounts"("id")
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "member_reports_post_id_fkey"
        FOREIGN KEY ("post_id") REFERENCES "member_posts"("id")
        ON DELETE SET NULL ON UPDATE CASCADE
);

CREATE TABLE "business_profiles" (
    "account_id" UUID NOT NULL,
    "display_name" VARCHAR(120) NOT NULL,
    "description" VARCHAR(1000),
    "website_url" VARCHAR(2048),
    "status" "business_profile_status" NOT NULL DEFAULT 'PENDING_REVIEW',
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,
    CONSTRAINT "business_profiles_pkey" PRIMARY KEY ("account_id"),
    CONSTRAINT "business_profiles_account_id_fkey"
        FOREIGN KEY ("account_id") REFERENCES "member_accounts"("id")
        ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE "account_deletion_requests" (
    "id" UUID NOT NULL,
    "account_id" UUID NOT NULL,
    "status" "account_deletion_status" NOT NULL DEFAULT 'REQUESTED',
    "requested_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "completed_at" TIMESTAMPTZ(6),
    "request_reason" VARCHAR(500),
    CONSTRAINT "account_deletion_requests_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "account_deletion_requests_account_id_fkey"
        FOREIGN KEY ("account_id") REFERENCES "member_accounts"("id")
        ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE INDEX "member_posts_status_created_idx" ON "member_posts"("status", "created_at");
CREATE INDEX "member_posts_account_status_created_idx" ON "member_posts"("account_id", "status", "created_at");
CREATE INDEX "post_audience_members_account_created_idx" ON "post_audience_members"("account_id", "created_at");
CREATE INDEX "member_post_likes_account_created_idx" ON "member_post_likes"("account_id", "created_at");
CREATE INDEX "member_post_bookmarks_account_created_idx" ON "member_post_bookmarks"("account_id", "created_at");
CREATE INDEX "member_post_comments_post_created_idx" ON "member_post_comments"("post_id", "created_at");
CREATE INDEX "member_post_comments_account_created_idx" ON "member_post_comments"("account_id", "created_at");
CREATE INDEX "social_follows_following_created_idx" ON "social_follows"("following_account_id", "created_at");
CREATE INDEX "social_follows_follower_created_idx" ON "social_follows"("follower_account_id", "created_at");
CREATE INDEX "member_blocks_target_created_idx" ON "member_blocks"("blocked_account_id", "created_at");
CREATE INDEX "member_reports_status_created_idx" ON "member_reports"("status", "created_at");
CREATE INDEX "member_reports_reporter_created_idx" ON "member_reports"("reporter_account_id", "created_at");
CREATE INDEX "account_deletion_requests_status_requested_idx" ON "account_deletion_requests"("status", "requested_at");
CREATE UNIQUE INDEX "account_deletion_requests_one_open_per_account_idx"
    ON "account_deletion_requests"("account_id")
    WHERE "status" IN ('REQUESTED', 'PROCESSING');

DO $grant_module2_runtime_permissions$
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
    EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE member_posts TO %I', app_role);
    EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE post_audience_members TO %I', app_role);
    EXECUTE format('GRANT SELECT, INSERT, DELETE ON TABLE member_post_likes TO %I', app_role);
    EXECUTE format('GRANT SELECT, INSERT, DELETE ON TABLE member_post_bookmarks TO %I', app_role);
    EXECUTE format('GRANT SELECT, INSERT, UPDATE ON TABLE member_post_comments TO %I', app_role);
    EXECUTE format('GRANT SELECT, INSERT, DELETE ON TABLE social_follows TO %I', app_role);
    EXECUTE format('GRANT SELECT, INSERT, UPDATE ON TABLE member_privacy_settings TO %I', app_role);
    EXECUTE format('GRANT SELECT, INSERT, UPDATE ON TABLE member_notification_preferences TO %I', app_role);
    EXECUTE format('GRANT SELECT, INSERT, DELETE ON TABLE member_blocks TO %I', app_role);
    EXECUTE format('GRANT SELECT, INSERT, UPDATE ON TABLE member_reports TO %I', app_role);
    EXECUTE format('GRANT SELECT, INSERT, UPDATE ON TABLE business_profiles TO %I', app_role);
    EXECUTE format('GRANT SELECT, INSERT, UPDATE ON TABLE account_deletion_requests TO %I', app_role);
    EXECUTE format('GRANT SELECT, UPDATE ON TABLE member_profiles TO %I', app_role);
    EXECUTE format('GRANT SELECT, UPDATE ON TABLE member_accounts TO %I', app_role);
    EXECUTE format('GRANT SELECT, UPDATE ON TABLE auth_sessions TO %I', app_role);
    EXECUTE format('GRANT INSERT ON TABLE audit_events TO %I', app_role);
END
$grant_module2_runtime_permissions$;
