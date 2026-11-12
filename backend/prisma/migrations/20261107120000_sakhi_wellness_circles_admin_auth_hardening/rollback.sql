-- Rollback for 20261107120000_sakhi_wellness_circles_admin_auth_hardening
DROP TABLE IF EXISTS "admin_auth_sessions";
ALTER TABLE "admin_staff_accounts"
  DROP COLUMN IF EXISTS "username",
  DROP COLUMN IF EXISTS "password_hash",
  DROP COLUMN IF EXISTS "password_updated_at",
  DROP COLUMN IF EXISTS "must_reset_password",
  DROP COLUMN IF EXISTS "failed_login_attempts",
  DROP COLUMN IF EXISTS "locked_until",
  DROP COLUMN IF EXISTS "mfa_enabled";

DROP TABLE IF EXISTS "community_circle_posts";
DROP TABLE IF EXISTS "community_circle_memberships";
ALTER TABLE "community_groups"
  DROP COLUMN IF EXISTS "slug",
  DROP COLUMN IF EXISTS "purpose",
  DROP COLUMN IF EXISTS "owner_account_id",
  DROP COLUMN IF EXISTS "owner_display_name",
  DROP COLUMN IF EXISTS "visibility",
  DROP COLUMN IF EXISTS "location_scope",
  DROP COLUMN IF EXISTS "rules",
  DROP COLUMN IF EXISTS "activity_state",
  DROP COLUMN IF EXISTS "updated_at";

DROP TABLE IF EXISTS "member_push_tokens";
ALTER TABLE "member_notification_preferences"
  DROP COLUMN IF EXISTS "circle_activity",
  DROP COLUMN IF EXISTS "quiet_hours_enabled",
  DROP COLUMN IF EXISTS "quiet_hours_start",
  DROP COLUMN IF EXISTS "quiet_hours_end",
  DROP COLUMN IF EXISTS "quiet_hours_timezone";

DROP TABLE IF EXISTS "member_wellness_preferences";
