-- Module 2 Reconciled Migration (Idempotent compatibility with 20261018090000_module2_core_domain)
DO $module2_database_guard$
BEGIN
    IF current_database() NOT IN ('sakhi_dev', 'sakhi_test') THEN
        RAISE EXCEPTION 'Module 2 migration may only run on sakhi_dev or sakhi_test; current database is %', current_database();
    END IF;
END
$module2_database_guard$;

ALTER TABLE "member_profiles"
    ADD COLUMN IF NOT EXISTS "bio" VARCHAR(500),
    ADD COLUMN IF NOT EXISTS "location_city" VARCHAR(100);
