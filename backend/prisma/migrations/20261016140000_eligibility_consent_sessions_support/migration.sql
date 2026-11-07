-- Add provider-neutral eligibility consent/session metadata and category-only support intake.
-- This is additive and contains no identity documents, Aadhaar numbers, OTPs, selfies or biometrics.
CREATE TYPE "eligibility_verification_session_status" AS ENUM (
  'CREATED',
  'REDIRECT_READY',
  'COMPLETED',
  'FAILED',
  'EXPIRED',
  'CANCELLED'
);

CREATE TYPE "eligibility_support_request_category" AS ENUM (
  'VERIFICATION_HELP',
  'MANUAL_REVIEW_REQUEST',
  'ACCESSIBILITY_ALTERNATIVE',
  'APPEAL_GUIDANCE'
);

CREATE TYPE "eligibility_support_request_status" AS ENUM (
  'OPEN',
  'IN_REVIEW',
  'RESOLVED',
  'CLOSED'
);

CREATE TABLE "eligibility_consents" (
  "id" UUID NOT NULL,
  "account_id" UUID NOT NULL,
  "notice_version" VARCHAR(64) NOT NULL,
  "accepted_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "biometric_processing_consented" BOOLEAN NOT NULL DEFAULT FALSE,
  "source" VARCHAR(32) NOT NULL,
  CONSTRAINT "eligibility_consents_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "eligibility_verification_sessions" (
  "id" UUID NOT NULL,
  "account_id" UUID NOT NULL,
  "consent_id" UUID NOT NULL,
  "provider_key" VARCHAR(64) NOT NULL,
  "provider_reference" VARCHAR(255),
  "status" "eligibility_verification_session_status" NOT NULL DEFAULT 'CREATED',
  "expires_at" TIMESTAMPTZ(6),
  "completed_at" TIMESTAMPTZ(6),
  "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMPTZ(6) NOT NULL,
  CONSTRAINT "eligibility_verification_sessions_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "eligibility_support_requests" (
  "id" UUID NOT NULL,
  "account_id" UUID NOT NULL,
  "category" "eligibility_support_request_category" NOT NULL,
  "status" "eligibility_support_request_status" NOT NULL DEFAULT 'OPEN',
  "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMPTZ(6) NOT NULL,
  CONSTRAINT "eligibility_support_requests_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "eligibility_sessions_provider_reference_key"
  ON "eligibility_verification_sessions"("provider_key", "provider_reference");
CREATE INDEX "eligibility_consents_account_accepted_idx"
  ON "eligibility_consents"("account_id", "accepted_at");
CREATE INDEX "eligibility_sessions_account_created_idx"
  ON "eligibility_verification_sessions"("account_id", "created_at");
CREATE INDEX "eligibility_sessions_status_expiry_idx"
  ON "eligibility_verification_sessions"("status", "expires_at");
CREATE INDEX "eligibility_support_account_created_idx"
  ON "eligibility_support_requests"("account_id", "created_at");
CREATE INDEX "eligibility_support_status_created_idx"
  ON "eligibility_support_requests"("status", "created_at");

ALTER TABLE "eligibility_consents"
  ADD CONSTRAINT "eligibility_consents_account_id_fkey"
  FOREIGN KEY ("account_id") REFERENCES "member_accounts"("id")
  ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "eligibility_verification_sessions"
  ADD CONSTRAINT "eligibility_sessions_account_id_fkey"
  FOREIGN KEY ("account_id") REFERENCES "member_accounts"("id")
  ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "eligibility_verification_sessions"
  ADD CONSTRAINT "eligibility_sessions_consent_id_fkey"
  FOREIGN KEY ("consent_id") REFERENCES "eligibility_consents"("id")
  ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "eligibility_support_requests"
  ADD CONSTRAINT "eligibility_support_account_id_fkey"
  FOREIGN KEY ("account_id") REFERENCES "member_accounts"("id")
  ON DELETE CASCADE ON UPDATE CASCADE;

-- Apply least-privilege permissions only to the matching Sakhi test/development app role.
DO $grant_eligibility_permissions$
DECLARE
  app_role TEXT;
BEGIN
  IF current_database() = 'sakhi_dev' THEN
    app_role := 'sakhi_dev_app';
  ELSIF current_database() = 'sakhi_test' THEN
    app_role := 'sakhi_test_app';
  ELSE
    RAISE EXCEPTION 'Sakhi migrations may only run on sakhi_dev or sakhi_test';
  END IF;

  EXECUTE format('GRANT SELECT, INSERT, UPDATE ON TABLE public.eligibility_consents, public.eligibility_verification_sessions TO %I', app_role);
  EXECUTE format('GRANT SELECT, INSERT ON TABLE public.eligibility_support_requests TO %I', app_role);
END
$grant_eligibility_permissions$;
