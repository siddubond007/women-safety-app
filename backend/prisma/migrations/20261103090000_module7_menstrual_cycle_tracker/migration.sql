-- Module 7: Women's Menstrual Cycle Tracker (SRS Sections 9.1–9.5)
-- Strictly owner-isolated health tables with foreign-key cascade deletion.
-- Idempotent because staging already contains these tables from an earlier out-of-band apply.

CREATE TABLE IF NOT EXISTS "menstrual_cycle_logs" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "account_id" UUID NOT NULL,
  "start_date" DATE NOT NULL,
  "end_date" DATE,
  "cycle_length_days" INTEGER,
  "period_duration_days" INTEGER,
  "flow_intensity" VARCHAR(24) NOT NULL DEFAULT 'MEDIUM',
  "symptoms" JSONB NOT NULL DEFAULT '[]'::jsonb,
  "mood" VARCHAR(40),
  "energy_level" INTEGER,
  "cramps_severity" VARCHAR(24),
  "notes_encrypted" TEXT,
  "is_irregular" BOOLEAN NOT NULL DEFAULT false,
  "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "menstrual_cycle_logs_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "menstrual_cycle_logs_account_id_fkey"
    FOREIGN KEY ("account_id") REFERENCES "member_accounts"("id")
    ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE IF NOT EXISTS "menstrual_daily_logs" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "account_id" UUID NOT NULL,
  "log_date" DATE NOT NULL,
  "flow_intensity" VARCHAR(24),
  "cramps_severity" VARCHAR(24) NOT NULL DEFAULT 'NONE',
  "mood" VARCHAR(40),
  "energy_level" INTEGER NOT NULL DEFAULT 3,
  "symptoms" JSONB NOT NULL DEFAULT '[]'::jsonb,
  "hydration_glasses" INTEGER NOT NULL DEFAULT 0,
  "sleep_hours" DOUBLE PRECISION,
  "notes_encrypted" TEXT,
  "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "menstrual_daily_logs_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "menstrual_daily_logs_account_id_fkey"
    FOREIGN KEY ("account_id") REFERENCES "member_accounts"("id")
    ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE IF NOT EXISTS "menstrual_tracker_preferences" (
  "account_id" UUID NOT NULL,
  "default_cycle_length" INTEGER NOT NULL DEFAULT 28,
  "default_period_duration" INTEGER NOT NULL DEFAULT 5,
  "discreet_notifications" BOOLEAN NOT NULL DEFAULT true,
  "period_reminder_enabled" BOOLEAN NOT NULL DEFAULT true,
  "period_reminder_days_before" INTEGER NOT NULL DEFAULT 2,
  "ovulation_reminder_enabled" BOOLEAN NOT NULL DEFAULT false,
  "hydration_reminder_enabled" BOOLEAN NOT NULL DEFAULT true,
  "self_care_reminder_enabled" BOOLEAN NOT NULL DEFAULT true,
  "show_fertility_estimates" BOOLEAN NOT NULL DEFAULT true,
  "medical_disclaimer_accepted_at" TIMESTAMPTZ(6),
  "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "menstrual_tracker_preferences_pkey" PRIMARY KEY ("account_id"),
  CONSTRAINT "menstrual_tracker_preferences_account_id_fkey"
    FOREIGN KEY ("account_id") REFERENCES "member_accounts"("id")
    ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX IF NOT EXISTS "menstrual_cycle_logs_account_start_idx" ON "menstrual_cycle_logs"("account_id", "start_date");
CREATE UNIQUE INDEX IF NOT EXISTS "menstrual_daily_logs_account_date_key" ON "menstrual_daily_logs"("account_id", "log_date");
CREATE INDEX IF NOT EXISTS "menstrual_daily_logs_account_date_idx" ON "menstrual_daily_logs"("account_id", "log_date");
