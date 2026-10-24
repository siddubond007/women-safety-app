BEGIN;

-- Supabase creates the public schema for this database. Do not CREATE SCHEMA here:
-- that operation requires database-level CREATE privilege, which the staging
-- migrator intentionally does not have. The role has USAGE and CREATE on public.

-- CreateEnum
CREATE TYPE "account_status" AS ENUM ('PENDING_VERIFICATION', 'ACTIVE', 'RESTRICTED', 'SUSPENDED', 'DELETED');

-- CreateEnum
CREATE TYPE "verification_status" AS ENUM ('UNVERIFIED', 'VERIFIED', 'REJECTED');

-- CreateEnum
CREATE TYPE "eligibility_submission_status" AS ENUM ('PENDING_MANUAL_REVIEW', 'APPROVED', 'REJECTED');

-- CreateEnum
CREATE TYPE "otp_purpose" AS ENUM ('LOGIN', 'REGISTRATION');

-- CreateEnum
CREATE TYPE "policy_document_type" AS ENUM ('TERMS', 'PRIVACY');

-- CreateEnum
CREATE TYPE "policy_document_status" AS ENUM ('DRAFT', 'PUBLISHED', 'RETIRED');

-- CreateTable
CREATE TABLE "member_accounts" (
    "id" UUID NOT NULL,
    "phone_e164" VARCHAR(16) NOT NULL,
    "phone_verified_at" TIMESTAMPTZ(6),
    "status" "account_status" NOT NULL DEFAULT 'PENDING_VERIFICATION',
    "verification_status" "verification_status" NOT NULL DEFAULT 'UNVERIFIED',
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "member_accounts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "member_profiles" (
    "account_id" UUID NOT NULL,
    "display_name" VARCHAR(100) NOT NULL,
    "username" VARCHAR(50),
    "bio" VARCHAR(300) NOT NULL DEFAULT 'A passionate learner, exploring wellness, technology and meaningful connections. ≡ƒÆ£',
    "location" VARCHAR(120) NOT NULL DEFAULT 'Bangalore, India',
    "avatar_asset" VARCHAR(255) NOT NULL DEFAULT 'assets/images/profile/avatar_siddhu.webp',
    "interests" JSONB NOT NULL DEFAULT '["Mental Wellness","Travel","Reading","WomenInTech","Art","Fitness"]',
    "business_profile_url" VARCHAR(255),
    "avatar_media_asset_id" UUID,
    "business_profile_name" VARCHAR(120),
    "business_category" VARCHAR(80),
    "two_factor_enabled" BOOLEAN NOT NULL DEFAULT false,
    "security_pin_updated_at" TIMESTAMPTZ(6),
    "date_of_birth" DATE NOT NULL,
    "email" VARCHAR(254),
    "profile_photo_ref" VARCHAR(512),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "member_profiles_pkey" PRIMARY KEY ("account_id")
);

-- CreateTable
CREATE TABLE "otp_challenges" (
    "id" UUID NOT NULL,
    "account_id" UUID,
    "phone_e164" VARCHAR(16) NOT NULL,
    "purpose" "otp_purpose" NOT NULL,
    "provider_reference" VARCHAR(255),
    "code_digest" VARCHAR(255),
    "attempt_count" INTEGER NOT NULL DEFAULT 0,
    "attempt_limit" INTEGER NOT NULL,
    "expires_at" TIMESTAMPTZ(6) NOT NULL,
    "resend_available_at" TIMESTAMPTZ(6) NOT NULL,
    "consumed_at" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "otp_challenges_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "policy_document_versions" (
    "id" UUID NOT NULL,
    "document_type" "policy_document_type" NOT NULL,
    "version" VARCHAR(64) NOT NULL,
    "status" "policy_document_status" NOT NULL DEFAULT 'DRAFT',
    "content_hash" VARCHAR(128),
    "effective_at" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "policy_document_versions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "member_consents" (
    "id" UUID NOT NULL,
    "account_id" UUID NOT NULL,
    "terms_version_id" UUID NOT NULL,
    "privacy_version_id" UUID NOT NULL,
    "accepted_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "source" VARCHAR(64) NOT NULL,

    CONSTRAINT "member_consents_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "auth_sessions" (
    "id" UUID NOT NULL,
    "account_id" UUID NOT NULL,
    "token_digest" VARCHAR(64) NOT NULL,
    "expires_at" TIMESTAMPTZ(6) NOT NULL,
    "revoked_at" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "last_seen_at" TIMESTAMPTZ(6),

    CONSTRAINT "auth_sessions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "member_communication_preferences" (
    "account_id" UUID NOT NULL,
    "product_updates_accepted" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "member_communication_preferences_pkey" PRIMARY KEY ("account_id")
);

-- CreateTable
CREATE TABLE "eligibility_submissions" (
    "id" UUID NOT NULL,
    "account_id" UUID NOT NULL,
    "status" "eligibility_submission_status" NOT NULL DEFAULT 'PENDING_MANUAL_REVIEW',
    "consent_version" VARCHAR(64) NOT NULL,
    "consent_accepted_at" TIMESTAMPTZ(6) NOT NULL,
    "submitted_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "reviewed_at" TIMESTAMPTZ(6),
    "reviewer_label" VARCHAR(80),
    "decision_reason" VARCHAR(500),

    CONSTRAINT "eligibility_submissions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "community_posts" (
    "id" UUID NOT NULL,
    "author_account_id" UUID,
    "author_name" VARCHAR(100) NOT NULL,
    "author_username" VARCHAR(50) NOT NULL,
    "author_avatar" VARCHAR(255) NOT NULL,
    "author_verified" BOOLEAN NOT NULL DEFAULT false,
    "content" TEXT NOT NULL,
    "image_asset" VARCHAR(255),
    "category_badge" VARCHAR(64),
    "feed_section" VARCHAR(32) NOT NULL DEFAULT 'community',
    "has_breathing_exercise_card" BOOLEAN NOT NULL DEFAULT false,
    "likes_count" INTEGER NOT NULL DEFAULT 0,
    "comments_count" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,
    "category_slug" VARCHAR(40) NOT NULL DEFAULT 'community',
    "visibility" VARCHAR(32) NOT NULL DEFAULT 'VERIFIED_MEMBERS',
    "status" VARCHAR(32) NOT NULL DEFAULT 'PUBLISHED',
    "hashtags" JSONB NOT NULL DEFAULT '[]',
    "location_tag" VARCHAR(120),
    "allow_comments" BOOLEAN NOT NULL DEFAULT true,
    "share_to_business_profile" BOOLEAN NOT NULL DEFAULT false,
    "crop_preset" VARCHAR(16) NOT NULL DEFAULT '4:5',
    "saves_count" INTEGER NOT NULL DEFAULT 0,
    "shares_count" INTEGER NOT NULL DEFAULT 0,
    "moderation_reason" VARCHAR(500),
    "deleted_at" TIMESTAMPTZ(6),

    CONSTRAINT "community_posts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "community_post_likes" (
    "id" UUID NOT NULL,
    "post_id" UUID NOT NULL,
    "account_id" UUID NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "community_post_likes_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "community_post_saves" (
    "id" UUID NOT NULL,
    "post_id" UUID NOT NULL,
    "account_id" UUID NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "community_post_saves_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "community_post_comments" (
    "id" UUID NOT NULL,
    "post_id" UUID NOT NULL,
    "account_id" UUID NOT NULL,
    "author_name" VARCHAR(100) NOT NULL,
    "content" VARCHAR(500) NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "is_removed_by_moderator" BOOLEAN NOT NULL DEFAULT false,
    "deleted_at" TIMESTAMPTZ(6),
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "community_post_comments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "community_groups" (
    "id" UUID NOT NULL,
    "name" VARCHAR(120) NOT NULL,
    "description" VARCHAR(300) NOT NULL,
    "category" VARCHAR(64) NOT NULL,
    "members_count" INTEGER NOT NULL DEFAULT 1,
    "new_posts_today" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "community_groups_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "community_directory_profiles" (
    "id" UUID NOT NULL,
    "name" VARCHAR(100) NOT NULL,
    "username" VARCHAR(50) NOT NULL,
    "avatar_asset" VARCHAR(255) NOT NULL,
    "bio" VARCHAR(255),
    "default_following" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "community_directory_profiles_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "member_follows" (
    "id" UUID NOT NULL,
    "account_id" UUID NOT NULL,
    "directory_profile_id" UUID NOT NULL,
    "is_following" BOOLEAN NOT NULL DEFAULT true,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "member_follows_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "member_privacy_preferences" (
    "account_id" UUID NOT NULL,
    "view_profile" VARCHAR(64) NOT NULL DEFAULT 'Verified members only',
    "message_me" VARCHAR(64) NOT NULL DEFAULT 'Verified members only',
    "see_posts" VARCHAR(64) NOT NULL DEFAULT 'Verified members only',
    "show_location" VARCHAR(64) NOT NULL DEFAULT 'General location only',
    "search_results" VARCHAR(32) NOT NULL DEFAULT 'Yes',
    "business_enquiries" VARCHAR(64) NOT NULL DEFAULT 'Yes',
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "member_privacy_preferences_pkey" PRIMARY KEY ("account_id")
);

-- CreateTable
CREATE TABLE "member_notification_preferences" (
    "account_id" UUID NOT NULL,
    "community_updates" BOOLEAN NOT NULL DEFAULT true,
    "group_activity" BOOLEAN NOT NULL DEFAULT true,
    "wellness_reminders" BOOLEAN NOT NULL DEFAULT true,
    "safety_alerts" BOOLEAN NOT NULL DEFAULT true,
    "messages" BOOLEAN NOT NULL DEFAULT true,
    "business_enquiries" BOOLEAN NOT NULL DEFAULT true,
    "marketing_updates" BOOLEAN NOT NULL DEFAULT false,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "member_notification_preferences_pkey" PRIMARY KEY ("account_id")
);

-- CreateTable
CREATE TABLE "safety_emergency_contacts" (
    "id" UUID NOT NULL,
    "account_id" UUID NOT NULL,
    "name" VARCHAR(100) NOT NULL,
    "relationship" VARCHAR(64) NOT NULL,
    "phone_e164" VARCHAR(16) NOT NULL,
    "is_trusted_location_contact" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "safety_emergency_contacts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "safety_sos_events" (
    "id" UUID NOT NULL,
    "account_id" UUID NOT NULL,
    "event_type" VARCHAR(32) NOT NULL,
    "status" VARCHAR(32) NOT NULL DEFAULT 'RECORDED',
    "location_label" VARCHAR(120),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "safety_sos_events_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "wellness_resources" (
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

-- CreateTable
CREATE TABLE "member_moderation_blocks" (
    "id" UUID NOT NULL,
    "account_id" UUID NOT NULL,
    "blocked_username" VARCHAR(50) NOT NULL,
    "blocked_display_name" VARCHAR(100) NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "member_moderation_blocks_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "member_user_reports" (
    "id" UUID NOT NULL,
    "reporter_account_id" UUID NOT NULL,
    "target_handle" VARCHAR(100) NOT NULL,
    "reason" VARCHAR(500) NOT NULL,
    "status" VARCHAR(32) NOT NULL DEFAULT 'SUBMITTED',
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "target_type" VARCHAR(32) NOT NULL DEFAULT 'POST',
    "post_id" UUID,
    "comment_id" UUID,
    "category" VARCHAR(64) NOT NULL DEFAULT 'SAFETY_CONCERN',
    "details" VARCHAR(1000),
    "reviewer_notes" VARCHAR(1000),
    "reviewed_by" VARCHAR(120),
    "reviewed_at" TIMESTAMPTZ(6),

    CONSTRAINT "member_user_reports_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "audit_events" (
    "id" UUID NOT NULL,
    "actor_type" VARCHAR(32) NOT NULL,
    "actor_id" UUID,
    "action" VARCHAR(128) NOT NULL,
    "target_type" VARCHAR(64),
    "target_id" VARCHAR(128),
    "outcome" VARCHAR(32) NOT NULL,
    "request_id" VARCHAR(128) NOT NULL,
    "redacted_metadata" JSONB,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "audit_events_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "feed_category_configs" (
    "slug" VARCHAR(40) NOT NULL,
    "name" VARCHAR(80) NOT NULL,
    "description" VARCHAR(300) NOT NULL,
    "icon_key" VARCHAR(40) NOT NULL DEFAULT 'sparkles',
    "accent_color_hex" VARCHAR(16) NOT NULL DEFAULT '#EC4899',
    "is_enabled" BOOLEAN NOT NULL DEFAULT true,
    "display_order" INTEGER NOT NULL DEFAULT 0,
    "updated_by" VARCHAR(120),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "feed_category_configs_pkey" PRIMARY KEY ("slug")
);

-- CreateTable
CREATE TABLE "media_assets" (
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

    CONSTRAINT "media_assets_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "community_post_reactions" (
    "id" UUID NOT NULL,
    "post_id" UUID NOT NULL,
    "account_id" UUID NOT NULL,
    "reaction_type" VARCHAR(32) NOT NULL DEFAULT 'LIKE',
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "community_post_reactions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "moderation_decisions" (
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

-- CreateIndex
CREATE UNIQUE INDEX "member_accounts_phone_e164_key" ON "member_accounts"("phone_e164");

-- CreateIndex
CREATE UNIQUE INDEX "member_profiles_username_key" ON "member_profiles"("username");

-- CreateIndex
CREATE INDEX "otp_challenges_phone_purpose_created_idx" ON "otp_challenges"("phone_e164", "purpose", "created_at");

-- CreateIndex
CREATE INDEX "otp_challenges_expires_at_idx" ON "otp_challenges"("expires_at");

-- CreateIndex
CREATE INDEX "otp_challenges_account_id_idx" ON "otp_challenges"("account_id");

-- CreateIndex
CREATE INDEX "policy_document_versions_type_status_idx" ON "policy_document_versions"("document_type", "status");

-- CreateIndex
CREATE UNIQUE INDEX "policy_document_versions_type_version_key" ON "policy_document_versions"("document_type", "version");

-- CreateIndex
CREATE INDEX "member_consents_account_accepted_idx" ON "member_consents"("account_id", "accepted_at");

-- CreateIndex
CREATE INDEX "member_consents_terms_version_idx" ON "member_consents"("terms_version_id");

-- CreateIndex
CREATE INDEX "member_consents_privacy_version_idx" ON "member_consents"("privacy_version_id");

-- CreateIndex
CREATE UNIQUE INDEX "auth_sessions_token_digest_key" ON "auth_sessions"("token_digest");

-- CreateIndex
CREATE INDEX "auth_sessions_account_expiry_idx" ON "auth_sessions"("account_id", "expires_at");

-- CreateIndex
CREATE INDEX "auth_sessions_expiry_idx" ON "auth_sessions"("expires_at");

-- CreateIndex
CREATE INDEX "eligibility_submissions_status_submitted_idx" ON "eligibility_submissions"("status", "submitted_at");

-- CreateIndex
CREATE INDEX "eligibility_submissions_account_submitted_idx" ON "eligibility_submissions"("account_id", "submitted_at");

-- CreateIndex
CREATE INDEX "community_posts_section_created_idx" ON "community_posts"("feed_section", "created_at");

-- CreateIndex
CREATE INDEX "community_posts_author_created_idx" ON "community_posts"("author_account_id", "created_at");

-- CreateIndex
CREATE INDEX "community_posts_category_status_created_idx" ON "community_posts"("category_slug", "status", "created_at");

-- CreateIndex
CREATE INDEX "community_post_likes_account_idx" ON "community_post_likes"("account_id");

-- CreateIndex
CREATE UNIQUE INDEX "community_post_likes_post_account_key" ON "community_post_likes"("post_id", "account_id");

-- CreateIndex
CREATE INDEX "community_post_saves_account_idx" ON "community_post_saves"("account_id");

-- CreateIndex
CREATE UNIQUE INDEX "community_post_saves_post_account_key" ON "community_post_saves"("post_id", "account_id");

-- CreateIndex
CREATE INDEX "community_post_comments_post_created_idx" ON "community_post_comments"("post_id", "created_at");

-- CreateIndex
CREATE UNIQUE INDEX "community_groups_name_key" ON "community_groups"("name");

-- CreateIndex
CREATE UNIQUE INDEX "community_directory_profiles_username_key" ON "community_directory_profiles"("username");

-- CreateIndex
CREATE INDEX "member_follows_account_idx" ON "member_follows"("account_id");

-- CreateIndex
CREATE UNIQUE INDEX "member_follows_account_profile_key" ON "member_follows"("account_id", "directory_profile_id");

-- CreateIndex
CREATE INDEX "safety_emergency_contacts_account_idx" ON "safety_emergency_contacts"("account_id");

-- CreateIndex
CREATE INDEX "safety_sos_events_account_created_idx" ON "safety_sos_events"("account_id", "created_at");

-- CreateIndex
CREATE UNIQUE INDEX "wellness_resources_slug_key" ON "wellness_resources"("slug");

-- CreateIndex
CREATE INDEX "member_moderation_blocks_account_idx" ON "member_moderation_blocks"("account_id");

-- CreateIndex
CREATE UNIQUE INDEX "member_moderation_blocks_account_username_key" ON "member_moderation_blocks"("account_id", "blocked_username");

-- CreateIndex
CREATE INDEX "member_user_reports_reporter_created_idx" ON "member_user_reports"("reporter_account_id", "created_at");

-- CreateIndex
CREATE INDEX "audit_events_created_at_idx" ON "audit_events"("created_at");

-- CreateIndex
CREATE INDEX "audit_events_actor_created_idx" ON "audit_events"("actor_type", "actor_id", "created_at");

-- CreateIndex
CREATE INDEX "audit_events_action_created_idx" ON "audit_events"("action", "created_at");

-- CreateIndex
CREATE INDEX "feed_category_configs_enabled_order_idx" ON "feed_category_configs"("is_enabled", "display_order");

-- CreateIndex
CREATE INDEX "media_assets_owner_purpose_status_idx" ON "media_assets"("owner_account_id", "purpose", "status");

-- CreateIndex
CREATE INDEX "media_assets_post_status_idx" ON "media_assets"("post_id", "status");

-- CreateIndex
CREATE INDEX "media_assets_drive_file_id_idx" ON "media_assets"("drive_file_id");

-- CreateIndex
CREATE INDEX "community_post_reactions_post_type_idx" ON "community_post_reactions"("post_id", "reaction_type");

-- CreateIndex
CREATE UNIQUE INDEX "community_post_reactions_post_account_key" ON "community_post_reactions"("post_id", "account_id");

-- CreateIndex
CREATE INDEX "moderation_decisions_target_created_idx" ON "moderation_decisions"("target_type", "created_at");

-- AddForeignKey
ALTER TABLE "member_profiles" ADD CONSTRAINT "member_profiles_account_id_fkey" FOREIGN KEY ("account_id") REFERENCES "member_accounts"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "otp_challenges" ADD CONSTRAINT "otp_challenges_account_id_fkey" FOREIGN KEY ("account_id") REFERENCES "member_accounts"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "member_consents" ADD CONSTRAINT "member_consents_account_id_fkey" FOREIGN KEY ("account_id") REFERENCES "member_accounts"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "member_consents" ADD CONSTRAINT "member_consents_terms_version_id_fkey" FOREIGN KEY ("terms_version_id") REFERENCES "policy_document_versions"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "member_consents" ADD CONSTRAINT "member_consents_privacy_version_id_fkey" FOREIGN KEY ("privacy_version_id") REFERENCES "policy_document_versions"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "auth_sessions" ADD CONSTRAINT "auth_sessions_account_id_fkey" FOREIGN KEY ("account_id") REFERENCES "member_accounts"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "member_communication_preferences" ADD CONSTRAINT "member_communication_preferences_account_id_fkey" FOREIGN KEY ("account_id") REFERENCES "member_accounts"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "eligibility_submissions" ADD CONSTRAINT "eligibility_submissions_account_id_fkey" FOREIGN KEY ("account_id") REFERENCES "member_accounts"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "community_posts" ADD CONSTRAINT "community_posts_author_account_id_fkey" FOREIGN KEY ("author_account_id") REFERENCES "member_accounts"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "community_post_likes" ADD CONSTRAINT "community_post_likes_post_id_fkey" FOREIGN KEY ("post_id") REFERENCES "community_posts"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "community_post_likes" ADD CONSTRAINT "community_post_likes_account_id_fkey" FOREIGN KEY ("account_id") REFERENCES "member_accounts"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "community_post_saves" ADD CONSTRAINT "community_post_saves_post_id_fkey" FOREIGN KEY ("post_id") REFERENCES "community_posts"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "community_post_saves" ADD CONSTRAINT "community_post_saves_account_id_fkey" FOREIGN KEY ("account_id") REFERENCES "member_accounts"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "community_post_comments" ADD CONSTRAINT "community_post_comments_post_id_fkey" FOREIGN KEY ("post_id") REFERENCES "community_posts"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "community_post_comments" ADD CONSTRAINT "community_post_comments_account_id_fkey" FOREIGN KEY ("account_id") REFERENCES "member_accounts"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "member_follows" ADD CONSTRAINT "member_follows_account_id_fkey" FOREIGN KEY ("account_id") REFERENCES "member_accounts"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "member_follows" ADD CONSTRAINT "member_follows_directory_profile_id_fkey" FOREIGN KEY ("directory_profile_id") REFERENCES "community_directory_profiles"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "member_privacy_preferences" ADD CONSTRAINT "member_privacy_preferences_account_id_fkey" FOREIGN KEY ("account_id") REFERENCES "member_accounts"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "member_notification_preferences" ADD CONSTRAINT "member_notification_preferences_account_id_fkey" FOREIGN KEY ("account_id") REFERENCES "member_accounts"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "safety_emergency_contacts" ADD CONSTRAINT "safety_emergency_contacts_account_id_fkey" FOREIGN KEY ("account_id") REFERENCES "member_accounts"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "safety_sos_events" ADD CONSTRAINT "safety_sos_events_account_id_fkey" FOREIGN KEY ("account_id") REFERENCES "member_accounts"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "member_moderation_blocks" ADD CONSTRAINT "member_moderation_blocks_account_id_fkey" FOREIGN KEY ("account_id") REFERENCES "member_accounts"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "member_user_reports" ADD CONSTRAINT "member_user_reports_reporter_account_id_fkey" FOREIGN KEY ("reporter_account_id") REFERENCES "member_accounts"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "media_assets" ADD CONSTRAINT "media_assets_owner_account_id_fkey" FOREIGN KEY ("owner_account_id") REFERENCES "member_accounts"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "media_assets" ADD CONSTRAINT "media_assets_post_id_fkey" FOREIGN KEY ("post_id") REFERENCES "community_posts"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "community_post_reactions" ADD CONSTRAINT "community_post_reactions_post_id_fkey" FOREIGN KEY ("post_id") REFERENCES "community_posts"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "community_post_reactions" ADD CONSTRAINT "community_post_reactions_account_id_fkey" FOREIGN KEY ("account_id") REFERENCES "member_accounts"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- Eligibility status is still SQL-managed rather than represented in the Prisma model.
CREATE TYPE "eligibility_verification_status" AS ENUM (
  'NOT_VERIFIED',
  'VERIFICATION_IN_PROGRESS',
  'PENDING_MANUAL_REVIEW',
  'VERIFIED',
  'VERIFICATION_FAILED',
  'TEMPORARILY_RESTRICTED',
  'REVERIFICATION_REQUIRED'
);
ALTER TABLE "member_accounts"
  ADD COLUMN "eligibility_status" "eligibility_verification_status"
  NOT NULL DEFAULT 'NOT_VERIFIED';

CREATE UNIQUE INDEX "eligibility_submissions_one_pending_per_account_idx"
  ON "eligibility_submissions"("account_id")
  WHERE "status" = 'PENDING_MANUAL_REVIEW';

-- Raw SQL-managed eligibility support objects from the existing migrations.
-- These are intentionally included in the fresh staging baseline even though
-- they are not Prisma models in the current schema.
CREATE TYPE "eligibility_verification_session_status" AS ENUM (
  'CREATED', 'REDIRECT_READY', 'COMPLETED', 'FAILED', 'EXPIRED', 'CANCELLED'
);

CREATE TYPE "eligibility_support_request_category" AS ENUM (
  'VERIFICATION_HELP', 'MANUAL_REVIEW_REQUEST',
  'ACCESSIBILITY_ALTERNATIVE', 'APPEAL_GUIDANCE'
);

CREATE TYPE "eligibility_support_request_status" AS ENUM (
  'OPEN', 'IN_REVIEW', 'RESOLVED', 'CLOSED'
);

CREATE TYPE "eligibility_provider_callback_outcome" AS ENUM (
  'VERIFIED', 'PENDING_MANUAL_REVIEW', 'VERIFICATION_FAILED'
);

CREATE TABLE "eligibility_consents" (
  "id" UUID NOT NULL,
  "account_id" UUID NOT NULL,
  "notice_version" VARCHAR(64) NOT NULL,
  "accepted_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "biometric_processing_consented" BOOLEAN NOT NULL DEFAULT FALSE,
  "source" VARCHAR(32) NOT NULL,
  CONSTRAINT "eligibility_consents_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "eligibility_verification_sessions" (
  "id" UUID NOT NULL,
  "account_id" UUID NOT NULL,
  "consent_id" UUID NOT NULL,
  "provider_key" VARCHAR(64) NOT NULL,
  "provider_reference" VARCHAR(255),
  "status" "eligibility_verification_session_status" NOT NULL DEFAULT 'CREATED',
  "expires_at" TIMESTAMPTZ(6),
  "completed_at" TIMESTAMPTZ(6),
  "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMPTZ(6) NOT NULL,
  CONSTRAINT "eligibility_verification_sessions_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "eligibility_support_requests" (
  "id" UUID NOT NULL,
  "account_id" UUID NOT NULL,
  "category" "eligibility_support_request_category" NOT NULL,
  "status" "eligibility_support_request_status" NOT NULL DEFAULT 'OPEN',
  "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMPTZ(6) NOT NULL,
  CONSTRAINT "eligibility_support_requests_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "eligibility_provider_callback_events" (
  "id" UUID NOT NULL,
  "provider_key" VARCHAR(64) NOT NULL,
  "provider_event_id" VARCHAR(255) NOT NULL,
  "session_id" UUID NOT NULL,
  "outcome" "eligibility_provider_callback_outcome" NOT NULL,
  "received_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "eligibility_provider_callback_events_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "eligibility_sessions_provider_reference_key"
  ON "eligibility_verification_sessions"("provider_key", "provider_reference");
CREATE INDEX "eligibility_consents_account_accepted_idx"
  ON "eligibility_consents"("account_id", "accepted_at");
CREATE INDEX "eligibility_sessions_account_created_idx"
  ON "eligibility_verification_sessions"("account_id", "created_at");
CREATE INDEX "eligibility_sessions_status_expiry_idx"
  ON "eligibility_verification_sessions"("status", "expires_at");
CREATE INDEX "eligibility_support_account_created_idx"
  ON "eligibility_support_requests"("account_id", "created_at");
CREATE INDEX "eligibility_support_status_created_idx"
  ON "eligibility_support_requests"("status", "created_at");
CREATE UNIQUE INDEX "eligibility_provider_callback_event_key"
  ON "eligibility_provider_callback_events"("provider_key", "provider_event_id");
CREATE INDEX "eligibility_provider_callback_session_received_idx"
  ON "eligibility_provider_callback_events"("session_id", "received_at");

ALTER TABLE "eligibility_consents"
  ADD CONSTRAINT "eligibility_consents_account_id_fkey"
  FOREIGN KEY ("account_id") REFERENCES "member_accounts"("id")
  ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "eligibility_verification_sessions"
  ADD CONSTRAINT "eligibility_sessions_account_id_fkey"
  FOREIGN KEY ("account_id") REFERENCES "member_accounts"("id")
  ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "eligibility_verification_sessions"
  ADD CONSTRAINT "eligibility_sessions_consent_id_fkey"
  FOREIGN KEY ("consent_id") REFERENCES "eligibility_consents"("id")
  ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "eligibility_support_requests"
  ADD CONSTRAINT "eligibility_support_account_id_fkey"
  FOREIGN KEY ("account_id") REFERENCES "member_accounts"("id")
  ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "eligibility_provider_callback_events"
  ADD CONSTRAINT "eligibility_provider_callback_events_session_id_fkey"
  FOREIGN KEY ("session_id") REFERENCES "eligibility_verification_sessions"("id")
  ON DELETE CASCADE ON UPDATE CASCADE;


CREATE TABLE "platform_registration_policies" (
  "policy_key" VARCHAR(40) NOT NULL DEFAULT 'default',
  "minimum_age_years" INTEGER NOT NULL DEFAULT 18,
  "updated_by" VARCHAR(120),
  "change_reason" VARCHAR(500),
  "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "platform_registration_policies_pkey" PRIMARY KEY ("policy_key")
);


ALTER TABLE "safety_emergency_contacts" ADD COLUMN "is_primary" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "safety_emergency_contacts" ADD COLUMN "alert_enabled" BOOLEAN NOT NULL DEFAULT true;

ALTER TABLE "safety_sos_events" ADD COLUMN "latitude" DOUBLE PRECISION;
ALTER TABLE "safety_sos_events" ADD COLUMN "longitude" DOUBLE PRECISION;
ALTER TABLE "safety_sos_events" ADD COLUMN "is_test_mode" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "safety_sos_events" ADD COLUMN "contacts_alerted_count" INTEGER NOT NULL DEFAULT 0;
ALTER TABLE "safety_sos_events" ADD COLUMN "share_token" VARCHAR(80);
ALTER TABLE "safety_sos_events" ADD COLUMN "resolved_at" TIMESTAMPTZ(6);

CREATE TABLE "safety_location_shares" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "account_id" UUID NOT NULL,
  "share_token" VARCHAR(80) NOT NULL,
  "status" VARCHAR(32) NOT NULL DEFAULT 'ACTIVE',
  "duration_label" VARCHAR(40) NOT NULL DEFAULT '1 Hour',
  "include_profile" BOOLEAN NOT NULL DEFAULT true,
  "include_timestamp" BOOLEAN NOT NULL DEFAULT true,
  "latitude" DOUBLE PRECISION NOT NULL,
  "longitude" DOUBLE PRECISION NOT NULL,
  "accuracy_meters" DOUBLE PRECISION,
  "battery_percent" INTEGER,
  "location_label" VARCHAR(160),
  "stopped_at" TIMESTAMPTZ(6),
  "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "safety_location_shares_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "verified_police_stations" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "station_code" VARCHAR(64) NOT NULL,
  "name" VARCHAR(160) NOT NULL,
  "address" VARCHAR(300) NOT NULL,
  "city" VARCHAR(80) NOT NULL DEFAULT 'Bengaluru',
  "state" VARCHAR(80) NOT NULL DEFAULT 'Karnataka',
  "latitude" DOUBLE PRECISION NOT NULL,
  "longitude" DOUBLE PRECISION NOT NULL,
  "phone_number" VARCHAR(40) NOT NULL,
  "emergency_number" VARCHAR(20) NOT NULL DEFAULT '112',
  "is_women_station" BOOLEAN NOT NULL DEFAULT false,
  "is_verified" BOOLEAN NOT NULL DEFAULT true,
  "updated_by" VARCHAR(120),
  "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "verified_police_stations_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "safety_helpline_configs" (
  "code" VARCHAR(40) NOT NULL,
  "number" VARCHAR(32) NOT NULL,
  "title" VARCHAR(160) NOT NULL,
  "subtitle" VARCHAR(255) NOT NULL,
  "category" VARCHAR(64) NOT NULL DEFAULT 'EMERGENCY',
  "is_enabled" BOOLEAN NOT NULL DEFAULT true,
  "display_order" INTEGER NOT NULL DEFAULT 1,
  "updated_by" VARCHAR(120),
  "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "safety_helpline_configs_pkey" PRIMARY KEY ("code")
);

CREATE UNIQUE INDEX "safety_location_shares_share_token_key" ON "safety_location_shares"("share_token");
CREATE INDEX "safety_location_shares_account_status_idx" ON "safety_location_shares"("account_id", "status");
CREATE UNIQUE INDEX "verified_police_stations_station_code_key" ON "verified_police_stations"("station_code");
CREATE INDEX "verified_police_stations_city_verified_idx" ON "verified_police_stations"("city", "is_verified");

ALTER TABLE "safety_location_shares"
  ADD CONSTRAINT "safety_location_shares_account_id_fkey"
  FOREIGN KEY ("account_id") REFERENCES "member_accounts"("id")
  ON DELETE CASCADE ON UPDATE CASCADE;

COMMIT;
