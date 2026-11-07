# Sakhi Module 3 — Database Migration & Persistence Report

## 1. Database Safety & Isolation Guardrails
- **Target Databases**: Strictly `sakhi_dev` and `sakhi_test`.
- **Forbidden Databases**: `marketplacedb` and any other PostgreSQL database on your machine are explicitly blocked by SQL `DO $$` guards inside the migration files, URL checks in `prisma/seed.ts` (`assertSafeSeedDatabaseTarget`), and PowerShell checks in `Verify-Sakhi-DatabaseAndEnvironment.ps1` and `Run-Sakhi-SafeMigration.ps1`.
- **Zero Destructive Operations**: No `DROP TABLE`, `TRUNCATE`, or `prisma migrate reset` is used anywhere.

## 2. Reconciliation of Existing Module 2 Migrations
In the base snapshot (`5357ed8`), two migration directories shared the `20261018090000_` prefix:
- `20261018090000_module2_core_domain`
- `20261018090000_module2_profile_social_settings`

We updated `20261018090000_module2_profile_social_settings/migration.sql` to use `ADD COLUMN IF NOT EXISTS` with a `sakhi_dev`/`sakhi_test` database check, and `Run-Sakhi-SafeMigration.ps1` automatically marks it resolved if `20261018090000_module2_core_domain` was already applied.

## 3. New Additive Module 3 Migration (`20261019120000_module3_social_wall_and_drive_media`)

### New Tables Created
1. **`feed_category_configs`**:
   - Stores the 6 SRS 5.3 categories (`following`, `community`, `trending`, `business_updates`, `safety_awareness`, `wellness_lifestyle`) with `name`, `description`, `icon_key`, `accent_color_hex`, `is_enabled`, `display_order`, and `updated_by`.
   - Pre-seeded idempotently via `INSERT ... ON CONFLICT ("slug") DO NOTHING`.
2. **`media_assets`**:
   - Relational metadata table for Google Drive and local media (`id`, `owner_account_id`, `post_id`, `purpose` [`PROFILE_PHOTO`, `COMMUNITY_POST_IMAGE`, `COMMUNITY_POST_VIDEO`], `storage_provider` [`GOOGLE_DRIVE`, `LOCAL_ASSET`], `status` [`UPLOADED`, `ATTACHED`, `SUPERSEDED`, `DELETED`, `QUARANTINED`], `category_slug`, `drive_file_id`, `drive_folder_id`, `drive_folder_path`, `original_file_name`, `content_type`, `byte_size`, `crop_aspect_ratio`, `visibility`, `sha256_checksum`).
3. **`community_post_reactions`**:
   - Persists member reactions per post (`post_id`, `account_id`, `reaction_type` [`LIKE`, `LOVE`, `SUPPORT`, `INSPIRED`, `HAPPY`, `GRATEFUL`, `STRONG`, `CARE`]) with `UNIQUE (post_id, account_id)`.
4. **`moderation_decisions`**:
   - Immutable audit trail of Super Admin moderation actions (`report_id`, `target_type`, `target_account_id`, `target_post_id`, `target_comment_id`, `action_type`, `reason`, `reviewer_label`, `created_at`).

### Additive Columns Added to Existing Tables
- **`member_profiles`**: `avatar_media_asset_id`, `business_profile_name`, `business_category`
- **`community_posts`**: `category_slug`, `visibility`, `status`, `hashtags` (`JSONB`), `location_tag`, `allow_comments`, `share_to_business_profile`, `crop_preset`, `saves_count`, `shares_count`, `moderation_reason`, `deleted_at`
- **`community_post_comments`**: `is_removed_by_moderator`, `deleted_at`, `updated_at`
- **`member_user_reports`**: `target_type`, `comment_id`, `category`, `details`, `reviewer_notes`, `reviewed_by`, `reviewed_at`
