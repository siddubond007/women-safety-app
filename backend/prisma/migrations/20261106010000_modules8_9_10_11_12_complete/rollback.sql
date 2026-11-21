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

-- The forward migration grants CRUD on the three Module 7 tables to these
-- runtime roles. Module 1–7 baseline grants did not include these tables, and
-- bootstrap-roles.sql explicitly disables blanket default privileges. Revoke
-- only the privileges introduced by this migration before restoring pre-v8 RLS.
DO $revoke_modules8_to_12_menstrual_runtime_permissions$
DECLARE
    role_name TEXT;
BEGIN
    FOREACH role_name IN ARRAY ARRAY['sakhi_dev_app', 'sakhi_test_app', 'sakhi_staging_app']
    LOOP
        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = role_name) THEN
            EXECUTE format(
                'REVOKE SELECT, INSERT, UPDATE, DELETE ON TABLE public.menstrual_cycle_logs, public.menstrual_daily_logs, public.menstrual_tracker_preferences FROM %I',
                role_name
            );
        END IF;
    END LOOP;
END
$revoke_modules8_to_12_menstrual_runtime_permissions$;

DROP POLICY IF EXISTS "menstrual_tracker_preferences_backend_runtime_access"
  ON "menstrual_tracker_preferences";
DROP POLICY IF EXISTS "menstrual_daily_logs_backend_runtime_access"
  ON "menstrual_daily_logs";
DROP POLICY IF EXISTS "menstrual_cycle_logs_backend_runtime_access"
  ON "menstrual_cycle_logs";

-- Module 7's tracked migration created these tables without enabling RLS.
-- Module 8–12 enabled RLS above; disable it here after removing the policies
-- so rollback restores the pre-migration access behavior instead of leaving
-- the tables in RLS default-deny mode.
ALTER TABLE "menstrual_tracker_preferences" DISABLE ROW LEVEL SECURITY;
ALTER TABLE "menstrual_daily_logs" DISABLE ROW LEVEL SECURITY;
ALTER TABLE "menstrual_cycle_logs" DISABLE ROW LEVEL SECURITY;

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
