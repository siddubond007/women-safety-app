-- Module 10 & Module 11: Real Role-Based Admin Staff Governance, Business Directory & Platform Config
-- Safe idempotent migration compatible with PostgreSQL and Supabase

CREATE TABLE IF NOT EXISTS "admin_staff_accounts" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "staff_code" VARCHAR(40) NOT NULL,
  "full_name" VARCHAR(120) NOT NULL,
  "email" VARCHAR(254) NOT NULL,
  "role" VARCHAR(40) NOT NULL DEFAULT 'COMPLAINT_REVIEWER',
  "status" VARCHAR(24) NOT NULL DEFAULT 'ACTIVE',
  "access_token_digest" VARCHAR(128) NOT NULL,
  "access_token_preview" VARCHAR(64) NOT NULL,
  "is_authorised_complaint_reviewer" BOOLEAN NOT NULL DEFAULT false,
  "clearance_level" VARCHAR(64) NOT NULL DEFAULT 'LEVEL_2_TRUST_SAFETY',
  "permissions" JSONB NOT NULL DEFAULT '{}',
  "created_by" VARCHAR(120),
  "last_login_at" TIMESTAMPTZ(6),
  "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "admin_staff_accounts_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "business_directory_listings" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "business_code" VARCHAR(40) NOT NULL,
  "business_name" VARCHAR(160) NOT NULL,
  "owner_account_id" UUID,
  "owner_display_name" VARCHAR(120) NOT NULL,
  "category" VARCHAR(80) NOT NULL DEFAULT 'Women-Owned Boutique & Services',
  "city" VARCHAR(80) NOT NULL DEFAULT 'Bengaluru',
  "description" TEXT NOT NULL,
  "contact_phone" VARCHAR(32),
  "website_or_instagram" VARCHAR(255),
  "approval_status" VARCHAR(32) NOT NULL DEFAULT 'PENDING_APPROVAL',
  "verification_badge_status" VARCHAR(32) NOT NULL DEFAULT 'NONE',
  "is_featured" BOOLEAN NOT NULL DEFAULT false,
  "is_reported_fraudulent" BOOLEAN NOT NULL DEFAULT false,
  "report_reason" VARCHAR(500),
  "reviewed_by" VARCHAR(120),
  "review_notes" VARCHAR(500),
  "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "business_directory_listings_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "platform_config_settings" (
  "config_key" VARCHAR(40) NOT NULL DEFAULT 'default',
  "feature_flags" JSONB NOT NULL DEFAULT '{}',
  "media_upload_limits" JSONB NOT NULL DEFAULT '{}',
  "business_categories" JSONB NOT NULL DEFAULT '[]',
  "announcement_banner" VARCHAR(500),
  "updated_by" VARCHAR(120),
  "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "platform_config_settings_pkey" PRIMARY KEY ("config_key")
);

CREATE UNIQUE INDEX IF NOT EXISTS "admin_staff_accounts_staff_code_key" ON "admin_staff_accounts"("staff_code");
CREATE UNIQUE INDEX IF NOT EXISTS "admin_staff_accounts_email_key" ON "admin_staff_accounts"("email");
CREATE INDEX IF NOT EXISTS "admin_staff_accounts_role_status_idx" ON "admin_staff_accounts"("role", "status");
CREATE INDEX IF NOT EXISTS "admin_staff_accounts_token_digest_idx" ON "admin_staff_accounts"("access_token_digest");

CREATE UNIQUE INDEX IF NOT EXISTS "business_directory_listings_code_key" ON "business_directory_listings"("business_code");
CREATE INDEX IF NOT EXISTS "business_directory_listings_status_created_idx" ON "business_directory_listings"("approval_status", "created_at");
CREATE INDEX IF NOT EXISTS "business_directory_listings_category_status_idx" ON "business_directory_listings"("category", "approval_status");
