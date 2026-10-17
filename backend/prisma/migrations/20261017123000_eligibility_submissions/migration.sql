-- Dedicated, explicit eligibility review requests.
-- This migration adds metadata only. It does not store selfie/image evidence.
CREATE TYPE "eligibility_submission_status" AS ENUM (
    'PENDING_MANUAL_REVIEW',
    'APPROVED',
    'REJECTED'
);

CREATE TABLE "eligibility_submissions" (
    "id" UUID NOT NULL,
    "account_id" UUID NOT NULL,
    "status" "eligibility_submission_status" NOT NULL DEFAULT 'PENDING_MANUAL_REVIEW',
    "consent_version" VARCHAR(64) NOT NULL,
    "consent_accepted_at" TIMESTAMPTZ(6) NOT NULL,
    "submitted_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "reviewed_at" TIMESTAMPTZ(6),
    "reviewer_label" VARCHAR(80),
    "decision_reason" VARCHAR(500),
    CONSTRAINT "eligibility_submissions_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "eligibility_submissions_account_id_fkey"
        FOREIGN KEY ("account_id") REFERENCES "member_accounts"("id")
        ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE INDEX "eligibility_submissions_status_submitted_idx"
    ON "eligibility_submissions"("status", "submitted_at");
CREATE INDEX "eligibility_submissions_account_submitted_idx"
    ON "eligibility_submissions"("account_id", "submitted_at");

-- At most one open manual review per account. Rejected cases can be resubmitted.
CREATE UNIQUE INDEX "eligibility_submissions_one_pending_per_account_idx"
    ON "eligibility_submissions"("account_id")
    WHERE "status" = 'PENDING_MANUAL_REVIEW';

DO $grant_runtime_permissions$
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

    EXECUTE format('GRANT USAGE ON SCHEMA public TO %I', app_role);
    EXECUTE format('GRANT SELECT, INSERT, UPDATE ON TABLE eligibility_submissions TO %I', app_role);
    EXECUTE format('GRANT SELECT ON TABLE audit_events TO %I', app_role);
END
$grant_runtime_permissions$;
