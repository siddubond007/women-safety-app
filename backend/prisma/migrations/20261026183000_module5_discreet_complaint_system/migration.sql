-- Module 5: Discreet and Anonymous Complaint System (SRS Sections 7.1–7.6)
-- Safe idempotent migration

CREATE TABLE IF NOT EXISTS "discreet_complaints" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "reference_number" VARCHAR(40) NOT NULL,
  "passkey_digest" VARCHAR(128) NOT NULL,
  "disguised_backup_serial" VARCHAR(64) NOT NULL,
  "reporting_mode" VARCHAR(24) NOT NULL DEFAULT 'ANONYMOUS',
  "confidential_account_id" UUID,
  "blinded_rate_limit_bucket" VARCHAR(64),
  "category_slug" VARCHAR(64) NOT NULL,
  "category_title" VARCHAR(120) NOT NULL,
  "custom_category_label" VARCHAR(120),
  "urgency" VARCHAR(32) NOT NULL DEFAULT 'PAST_INCIDENT',
  "description" TEXT NOT NULL,
  "pii_guard_redacted" BOOLEAN NOT NULL DEFAULT false,
  "approximate_date_label" VARCHAR(80) NOT NULL,
  "approximate_time_window" VARCHAR(80) NOT NULL,
  "location_type" VARCHAR(32) NOT NULL DEFAULT 'COARSE_AREA',
  "general_location_label" VARCHAR(180),
  "linked_target_type" VARCHAR(32),
  "linked_target_handle" VARCHAR(120),
  "linked_post_id" VARCHAR(80),
  "linked_business_id" VARCHAR(80),
  "evidence_files" JSONB NOT NULL DEFAULT '[]',
  "supporting_links" JSONB NOT NULL DEFAULT '[]',
  "wants_updates" BOOLEAN NOT NULL DEFAULT true,
  "submit_anonymously_to_review_team" BOOLEAN NOT NULL DEFAULT true,
  "acknowledged_non_police_legal_notice" BOOLEAN NOT NULL DEFAULT true,
  "status" VARCHAR(40) NOT NULL DEFAULT 'SUBMITTED',
  "severity" VARCHAR(24) NOT NULL DEFAULT 'S2_HIGH',
  "priority" VARCHAR(24) NOT NULL DEFAULT 'P1_URGENT',
  "assigned_reviewer_id" VARCHAR(64),
  "assigned_reviewer_name" VARCHAR(120),
  "duplicate_cluster_id" VARCHAR(64),
  "merged_into_reference" VARCHAR(40),
  "is_flagged_malicious_abuse" BOOLEAN NOT NULL DEFAULT false,
  "malicious_abuse_reason" VARCHAR(500),
  "rejection_reason_code" VARCHAR(80),
  "public_resolution_summary" TEXT,
  "enforcement_actions" JSONB NOT NULL DEFAULT '[]',
  "complainant_messages" JSONB NOT NULL DEFAULT '[]',
  "internal_notes" JSONB NOT NULL DEFAULT '[]',
  "audit_history" JSONB NOT NULL DEFAULT '[]',
  "media_purged_at" TIMESTAMPTZ(6),
  "retention_expires_at" TIMESTAMPTZ(6),
  "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "discreet_complaints_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "complaint_category_configs" (
  "slug" VARCHAR(64) NOT NULL,
  "name" VARCHAR(120) NOT NULL,
  "description" VARCHAR(300) NOT NULL,
  "icon_key" VARCHAR(40) NOT NULL DEFAULT 'shield',
  "flower_type" VARCHAR(40) NOT NULL DEFAULT 'peonySoft',
  "default_priority" VARCHAR(24) NOT NULL DEFAULT 'P2_HIGH',
  "default_severity" VARCHAR(24) NOT NULL DEFAULT 'S2_HIGH',
  "safety_guidance_text" TEXT NOT NULL,
  "legal_helpline_note" VARCHAR(500) NOT NULL,
  "is_enabled" BOOLEAN NOT NULL DEFAULT true,
  "display_order" INTEGER NOT NULL DEFAULT 1,
  "updated_by" VARCHAR(120),
  "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "complaint_category_configs_pkey" PRIMARY KEY ("slug")
);

CREATE TABLE IF NOT EXISTS "complaint_retention_policies" (
  "policy_key" VARCHAR(40) NOT NULL DEFAULT 'default',
  "closed_evidence_retention_days" INTEGER NOT NULL DEFAULT 90,
  "rejected_report_retention_days" INTEGER NOT NULL DEFAULT 30,
  "technical_rate_limit_log_days" INTEGER NOT NULL DEFAULT 14,
  "updated_by" VARCHAR(120),
  "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "complaint_retention_policies_pkey" PRIMARY KEY ("policy_key")
);

CREATE UNIQUE INDEX IF NOT EXISTS "discreet_complaints_reference_number_key" ON "discreet_complaints"("reference_number");
CREATE INDEX IF NOT EXISTS "discreet_complaints_status_priority_created_idx" ON "discreet_complaints"("status", "priority", "created_at");
CREATE INDEX IF NOT EXISTS "discreet_complaints_category_created_idx" ON "discreet_complaints"("category_slug", "created_at");
CREATE INDEX IF NOT EXISTS "discreet_complaints_target_handle_idx" ON "discreet_complaints"("linked_target_handle");
CREATE INDEX IF NOT EXISTS "discreet_complaints_duplicate_cluster_idx" ON "discreet_complaints"("duplicate_cluster_id");
CREATE INDEX IF NOT EXISTS "complaint_category_configs_enabled_order_idx" ON "complaint_category_configs"("is_enabled", "display_order");
