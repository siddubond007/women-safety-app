-- ============================================================================
-- Sakhi Platform — Rollback Script for 20261106010000_modules8_9_10_11_12_complete
-- ============================================================================

DROP INDEX IF EXISTS "member_moderation_blocks_blocked_username_idx";
DROP INDEX IF EXISTS "community_posts_username_status_created_idx";

ALTER TABLE "menstrual_tracker_preferences"
  DROP COLUMN IF EXISTS "use_custom_cycle_length";

ALTER TABLE "member_privacy_preferences"
  DROP COLUMN IF EXISTS "hidden_post_ids",
  DROP COLUMN IF EXISTS "restricted_handles",
  DROP COLUMN IF EXISTS "muted_handles";

DROP INDEX IF EXISTS "member_user_reports_post_id_idx";
DROP INDEX IF EXISTS "member_user_reports_target_handle_created_idx";
DROP INDEX IF EXISTS "member_user_reports_status_priority_created_idx";

ALTER TABLE "member_user_reports"
  DROP COLUMN IF EXISTS "appeal_reason",
  DROP COLUMN IF EXISTS "appeal_status",
  DROP COLUMN IF EXISTS "internal_notes",
  DROP COLUMN IF EXISTS "assigned_reviewer_name",
  DROP COLUMN IF EXISTS "assigned_reviewer_id",
  DROP COLUMN IF EXISTS "severity",
  DROP COLUMN IF EXISTS "priority",
  DROP COLUMN IF EXISTS "target_snapshot",
  DROP COLUMN IF EXISTS "evidence_urls",
  DROP COLUMN IF EXISTS "message_id",
  DROP COLUMN IF EXISTS "business_id",
  DROP COLUMN IF EXISTS "updated_at",
  DROP COLUMN IF EXISTS "reported_account_id";

DROP POLICY IF EXISTS "menstrual_tracker_preferences_backend_runtime_access"
  ON "menstrual_tracker_preferences";
DROP POLICY IF EXISTS "menstrual_daily_logs_backend_runtime_access"
  ON "menstrual_daily_logs";
DROP POLICY IF EXISTS "menstrual_cycle_logs_backend_runtime_access"
  ON "menstrual_cycle_logs";

DROP TABLE IF EXISTS "member_notifications";

DROP INDEX IF EXISTS "direct_messages_sender_client_msg_idx";
DROP INDEX IF EXISTS "direct_messages_media_upload_id_key";
DROP INDEX IF EXISTS "direct_messages_recipient_read_idx";
DROP INDEX IF EXISTS "direct_messages_sender_client_msg_key";

ALTER TABLE "direct_messages"
  DROP COLUMN IF EXISTS "client_message_id",
  DROP COLUMN IF EXISTS "read_at",
  DROP COLUMN IF EXISTS "request_status",
  DROP COLUMN IF EXISTS "media_upload_id",
  DROP COLUMN IF EXISTS "attachment_type",
  DROP COLUMN IF EXISTS "attachment_url";
