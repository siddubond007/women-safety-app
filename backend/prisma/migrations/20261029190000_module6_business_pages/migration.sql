-- Module 6: Women-owned business pages, saved listings, enquiry threads and reports.
-- Additive and idempotent so this can be safely applied to an existing Sakhi staging schema.
ALTER TABLE "business_directory_listings"
  ADD COLUMN IF NOT EXISTS "service_area" VARCHAR(160),
  ADD COLUMN IF NOT EXISTS "latitude" DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS "longitude" DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS "price_range" VARCHAR(80) NOT NULL DEFAULT '₹500 – ₹2,500',
  ADD COLUMN IF NOT EXISTS "logo_asset" TEXT,
  ADD COLUMN IF NOT EXISTS "cover_image" TEXT,
  ADD COLUMN IF NOT EXISTS "hide_phone_number" BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS "whatsapp_number" VARCHAR(32),
  ADD COLUMN IF NOT EXISTS "instagram_handle" VARCHAR(120),
  ADD COLUMN IF NOT EXISTS "business_hours" JSONB NOT NULL DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS "products_services" JSONB NOT NULL DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS "media_gallery" JSONB NOT NULL DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS "offers_and_posts" JSONB NOT NULL DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS "saved_by_account_ids" JSONB NOT NULL DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS "enquiries_count" INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS "views_count" INTEGER NOT NULL DEFAULT 0;

ALTER TABLE "business_directory_listings"
  ALTER COLUMN "category" SET DEFAULT 'Fashion and clothing';

CREATE INDEX IF NOT EXISTS "business_directory_listings_owner_idx"
  ON "business_directory_listings"("owner_account_id");

CREATE TABLE IF NOT EXISTS "business_enquiries" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "enquiry_code" VARCHAR(40) NOT NULL,
  "business_id" UUID NOT NULL,
  "business_name" VARCHAR(160) NOT NULL,
  "owner_account_id" UUID,
  "sender_account_id" UUID NOT NULL,
  "sender_display_name" VARCHAR(120) NOT NULL,
  "sender_username" VARCHAR(80),
  "subject_or_product" VARCHAR(160) NOT NULL DEFAULT 'General Business Enquiry',
  "status" VARCHAR(32) NOT NULL DEFAULT 'OPEN',
  "messages" JSONB NOT NULL DEFAULT '[]'::jsonb,
  "unread_for_owner" BOOLEAN NOT NULL DEFAULT true,
  "unread_for_sender" BOOLEAN NOT NULL DEFAULT false,
  "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "business_enquiries_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX IF NOT EXISTS "business_enquiries_code_key"
  ON "business_enquiries"("enquiry_code");
CREATE INDEX IF NOT EXISTS "business_enquiries_business_created_idx"
  ON "business_enquiries"("business_id", "created_at");
CREATE INDEX IF NOT EXISTS "business_enquiries_sender_created_idx"
  ON "business_enquiries"("sender_account_id", "created_at");
CREATE INDEX IF NOT EXISTS "business_enquiries_owner_created_idx"
  ON "business_enquiries"("owner_account_id", "created_at");

CREATE TABLE IF NOT EXISTS "business_reports" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "business_id" UUID NOT NULL,
  "business_name" VARCHAR(160) NOT NULL,
  "reporter_account_id" UUID NOT NULL,
  "reason" VARCHAR(160) NOT NULL,
  "details" TEXT,
  "status" VARCHAR(32) NOT NULL DEFAULT 'OPEN',
  "reviewed_by" VARCHAR(120),
  "review_notes" VARCHAR(500),
  "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "business_reports_pkey" PRIMARY KEY ("id")
);

CREATE INDEX IF NOT EXISTS "business_reports_business_status_idx"
  ON "business_reports"("business_id", "status", "created_at");

-- These nullable fields support safe threaded replies in Module 3 without altering existing comments.
ALTER TABLE "community_post_comments"
  ADD COLUMN IF NOT EXISTS "parent_comment_id" UUID,
  ADD COLUMN IF NOT EXISTS "reply_to_handle" VARCHAR(80);
