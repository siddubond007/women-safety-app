-- Add optional profile fields without rewriting or deleting existing user data.
-- Keep this migration scoped to Sakhi's isolated development/test databases.
DO $profile_columns_target_guard$
BEGIN
    IF current_database() NOT IN ('sakhi_dev', 'sakhi_test') THEN
        RAISE EXCEPTION 'Sakhi migrations may only run on sakhi_dev or sakhi_test';
    END IF;
END
$profile_columns_target_guard$;

ALTER TABLE "member_profiles"
    ADD COLUMN "bio" VARCHAR(500),
    ADD COLUMN "city" VARCHAR(100);
