-- ============================================================================
-- Sakhi Platform — Modules 8, 9, 10, 11 & 12 Additive Schema Migration
-- Migration ID: 20261106010000_modules8_9_10_11_12_complete
-- Strictly aligned with backend/prisma/schema.prisma and existing migrations.
-- ============================================================================

-- 1. Module 8: DirectMessage attachments, message-request state, read receipts, and client deduplication
ALTER TABLE "direct_messages"
  ADD COLUMN IF NOT EXISTS "attachment_url" TEXT,
  ADD COLUMN IF NOT EXISTS "attachment_type" VARCHAR(40),
  ADD COLUMN IF NOT EXISTS "media_upload_id" VARCHAR(128),
  ADD COLUMN IF NOT EXISTS "request_status" VARCHAR(24) NOT NULL DEFAULT 'ACCEPTED',
  ADD COLUMN IF NOT EXISTS "read_at" TIMESTAMPTZ(6),
  ADD COLUMN IF NOT EXISTS "client_message_id" VARCHAR(80);

CREATE UNIQUE INDEX IF NOT EXISTS "direct_messages_sender_client_msg_key"
  ON "direct_messages"("sender_account_id", "client_message_id");

CREATE UNIQUE INDEX IF NOT EXISTS "direct_messages_media_upload_id_key"
  ON "direct_messages"("media_upload_id");

CREATE INDEX IF NOT EXISTS "direct_messages_recipient_read_idx"
  ON "direct_messages"("recipient_account_id", "read_at");

CREATE INDEX IF NOT EXISTS "direct_messages_sender_client_msg_idx"
  ON "direct_messages"("sender_account_id", "client_message_id");

-- 2. Module 8: Dedicated Member Notifications Inbox Table (SRS Section 10.2)
CREATE TABLE IF NOT EXISTS "member_notifications" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "account_id" UUID NOT NULL,
  "category" VARCHAR(48) NOT NULL DEFAULT 'COMMUNITY_ANNOUNCEMENT',
  "title" VARCHAR(160) NOT NULL,
  "body" VARCHAR(500) NOT NULL,
  "discreet_title" VARCHAR(160),
  "discreet_body" VARCHAR(500),
  "deep_link" VARCHAR(255),
  "actor_handle" VARCHAR(80),
  "actor_name" VARCHAR(100),
  "actor_avatar" VARCHAR(255),
  "metadata" JSONB NOT NULL DEFAULT '{}'::jsonb,
  "is_read" BOOLEAN NOT NULL DEFAULT false,
  "read_at" TIMESTAMPTZ(6),
  "idempotency_key" VARCHAR(128),
  "delivery_status" VARCHAR(24) NOT NULL DEFAULT 'DELIVERED',
  "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "member_notifications_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "member_notifications_account_id_fkey"
    FOREIGN KEY ("account_id") REFERENCES "member_accounts"("id")
    ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE UNIQUE INDEX IF NOT EXISTS "member_notifications_idempotency_key"
  ON "member_notifications"("idempotency_key");

CREATE INDEX IF NOT EXISTS "member_notifications_account_read_created_idx"
  ON "member_notifications"("account_id", "is_read", "created_at");

CREATE INDEX IF NOT EXISTS "member_notifications_account_category_created_idx"
  ON "member_notifications"("account_id", "category", "created_at");

-- Enable Row Level Security on member_notifications so PostgREST/anon clients
-- cannot read private notifications directly (least privilege).
ALTER TABLE "member_notifications" ENABLE ROW LEVEL SECURITY;

-- Permit only the dedicated Sakhi API runtime login roles. The NestJS service
-- still scopes every operation by the authenticated accountId; this policy is
-- a database-role boundary, not per-row account isolation.
DROP POLICY IF EXISTS "member_notifications_backend_runtime_access"
  ON "member_notifications";
CREATE POLICY "member_notifications_backend_runtime_access"
  ON "member_notifications"
  AS PERMISSIVE
  FOR ALL
  TO PUBLIC
  USING (
    current_user IN ('sakhi_dev_app', 'sakhi_test_app', 'sakhi_staging_app')
  )
  WITH CHECK (
    current_user IN ('sakhi_dev_app', 'sakhi_test_app', 'sakhi_staging_app')
  );

-- 3. Module 10: MemberUserReport durable triage, evidence URLs, target snapshot & reviewer fields
ALTER TABLE "member_user_reports"
  ADD COLUMN IF NOT EXISTS "reported_account_id" UUID,
  ADD COLUMN IF NOT EXISTS "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  ADD COLUMN IF NOT EXISTS "business_id" UUID,
  ADD COLUMN IF NOT EXISTS "message_id" UUID,
  ADD COLUMN IF NOT EXISTS "evidence_urls" JSONB NOT NULL DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS "target_snapshot" JSONB,
  ADD COLUMN IF NOT EXISTS "priority" VARCHAR(24) NOT NULL DEFAULT 'P2_NORMAL',
  ADD COLUMN IF NOT EXISTS "severity" VARCHAR(24) NOT NULL DEFAULT 'S2_MEDIUM',
  ADD COLUMN IF NOT EXISTS "assigned_reviewer_id" VARCHAR(64),
  ADD COLUMN IF NOT EXISTS "assigned_reviewer_name" VARCHAR(120),
  ADD COLUMN IF NOT EXISTS "internal_notes" JSONB NOT NULL DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS "appeal_status" VARCHAR(32),
  ADD COLUMN IF NOT EXISTS "appeal_reason" VARCHAR(500);

CREATE INDEX IF NOT EXISTS "member_user_reports_status_priority_created_idx"
  ON "member_user_reports"("status", "priority", "created_at");

CREATE INDEX IF NOT EXISTS "member_user_reports_target_handle_created_idx"
  ON "member_user_reports"("target_handle", "created_at");

CREATE INDEX IF NOT EXISTS "member_user_reports_post_id_idx"
  ON "member_user_reports"("post_id");

-- 4. Module 2 & 3: Durable mute, restrict & hidden-post lists on member_privacy_preferences
ALTER TABLE "member_privacy_preferences"
  ADD COLUMN IF NOT EXISTS "muted_handles" JSONB NOT NULL DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS "restricted_handles" JSONB NOT NULL DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS "hidden_post_ids" JSONB NOT NULL DEFAULT '[]'::jsonb;

-- 5. Module 7: Explicit Automatic vs Custom cycle length mode flag on menstrual_tracker_preferences
ALTER TABLE "menstrual_tracker_preferences"
  ADD COLUMN IF NOT EXISTS "use_custom_cycle_length" BOOLEAN NOT NULL DEFAULT false;

-- 6. Module 9 & 12: Composite indexes matching exact Prisma schema definitions
CREATE INDEX IF NOT EXISTS "community_posts_username_status_created_idx"
  ON "community_posts"("author_username", "status", "created_at");

CREATE INDEX IF NOT EXISTS "member_moderation_blocks_blocked_username_idx"
  ON "member_moderation_blocks"("blocked_username");

-- 7. Conditional least-privilege runtime role grants (local dev/test/staging roles when present)
DO $grant_modules8_to_12_runtime_permissions$
DECLARE
    role_name TEXT;
BEGIN
    FOREACH role_name IN ARRAY ARRAY['sakhi_dev_app', 'sakhi_test_app', 'sakhi_staging_app']
    LOOP
        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = role_name) THEN
            EXECUTE format(
                'GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.member_notifications TO %I',
                role_name
            );
            EXECUTE format(
                'GRANT UPDATE ("read_at", "request_status") ON TABLE public.direct_messages TO %I',
                role_name
            );
        END IF;
    END LOOP;
END
$grant_modules8_to_12_runtime_permissions$;
