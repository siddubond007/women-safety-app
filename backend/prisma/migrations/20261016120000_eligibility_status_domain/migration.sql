-- Add eligibility status independently from account status and the legacy
-- phone/authentication verification flag. This is a forward-only migration.
CREATE TYPE "eligibility_verification_status" AS ENUM (
  'NOT_VERIFIED',
  'VERIFICATION_IN_PROGRESS',
  'PENDING_MANUAL_REVIEW',
  'VERIFIED',
  'VERIFICATION_FAILED',
  'TEMPORARILY_RESTRICTED',
  'REVERIFICATION_REQUIRED'
);

ALTER TABLE "member_accounts"
  ADD COLUMN "eligibility_status" "eligibility_verification_status"
  NOT NULL DEFAULT 'NOT_VERIFIED';
