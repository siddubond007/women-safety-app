-- CreateSchema
CREATE SCHEMA IF NOT EXISTS "public";

-- CreateEnum
CREATE TYPE "account_status" AS ENUM ('PENDING_VERIFICATION', 'ACTIVE', 'RESTRICTED', 'SUSPENDED', 'DELETED');

-- CreateEnum
CREATE TYPE "verification_status" AS ENUM ('UNVERIFIED', 'VERIFIED');

-- CreateEnum
CREATE TYPE "otp_purpose" AS ENUM ('LOGIN', 'REGISTRATION');

-- CreateEnum
CREATE TYPE "policy_document_type" AS ENUM ('TERMS', 'PRIVACY');

-- CreateEnum
CREATE TYPE "policy_document_status" AS ENUM ('DRAFT', 'PUBLISHED', 'RETIRED');

-- CreateTable
CREATE TABLE "member_accounts" (
    "id" UUID NOT NULL,
    "phone_e164" VARCHAR(16) NOT NULL,
    "phone_verified_at" TIMESTAMPTZ(6),
    "status" "account_status" NOT NULL DEFAULT 'PENDING_VERIFICATION',
    "verification_status" "verification_status" NOT NULL DEFAULT 'UNVERIFIED',
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "member_accounts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "member_profiles" (
    "account_id" UUID NOT NULL,
    "display_name" VARCHAR(100) NOT NULL,
    "date_of_birth" DATE NOT NULL,
    "email" VARCHAR(254),
    "profile_photo_ref" VARCHAR(512),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "member_profiles_pkey" PRIMARY KEY ("account_id")
);

-- CreateTable
CREATE TABLE "otp_challenges" (
    "id" UUID NOT NULL,
    "account_id" UUID,
    "phone_e164" VARCHAR(16) NOT NULL,
    "purpose" "otp_purpose" NOT NULL,
    "provider_reference" VARCHAR(255),
    "code_digest" VARCHAR(255),
    "attempt_count" INTEGER NOT NULL DEFAULT 0,
    "attempt_limit" INTEGER NOT NULL,
    "expires_at" TIMESTAMPTZ(6) NOT NULL,
    "resend_available_at" TIMESTAMPTZ(6) NOT NULL,
    "consumed_at" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "otp_challenges_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "policy_document_versions" (
    "id" UUID NOT NULL,
    "document_type" "policy_document_type" NOT NULL,
    "version" VARCHAR(64) NOT NULL,
    "status" "policy_document_status" NOT NULL DEFAULT 'DRAFT',
    "content_hash" VARCHAR(128),
    "effective_at" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "policy_document_versions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "member_consents" (
    "id" UUID NOT NULL,
    "account_id" UUID NOT NULL,
    "terms_version_id" UUID NOT NULL,
    "privacy_version_id" UUID NOT NULL,
    "accepted_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "source" VARCHAR(64) NOT NULL,

    CONSTRAINT "member_consents_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "audit_events" (
    "id" UUID NOT NULL,
    "actor_type" VARCHAR(32) NOT NULL,
    "actor_id" UUID,
    "action" VARCHAR(128) NOT NULL,
    "target_type" VARCHAR(64),
    "target_id" VARCHAR(128),
    "outcome" VARCHAR(32) NOT NULL,
    "request_id" VARCHAR(128) NOT NULL,
    "redacted_metadata" JSONB,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "audit_events_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "member_accounts_phone_e164_key" ON "member_accounts"("phone_e164");

-- CreateIndex
CREATE INDEX "otp_challenges_phone_purpose_created_idx" ON "otp_challenges"("phone_e164", "purpose", "created_at");

-- CreateIndex
CREATE INDEX "otp_challenges_expires_at_idx" ON "otp_challenges"("expires_at");

-- CreateIndex
CREATE INDEX "otp_challenges_account_id_idx" ON "otp_challenges"("account_id");

-- CreateIndex
CREATE INDEX "policy_document_versions_type_status_idx" ON "policy_document_versions"("document_type", "status");

-- CreateIndex
CREATE UNIQUE INDEX "policy_document_versions_type_version_key" ON "policy_document_versions"("document_type", "version");

-- CreateIndex
CREATE INDEX "member_consents_account_accepted_idx" ON "member_consents"("account_id", "accepted_at");

-- CreateIndex
CREATE INDEX "member_consents_terms_version_idx" ON "member_consents"("terms_version_id");

-- CreateIndex
CREATE INDEX "member_consents_privacy_version_idx" ON "member_consents"("privacy_version_id");

-- CreateIndex
CREATE INDEX "audit_events_created_at_idx" ON "audit_events"("created_at");

-- CreateIndex
CREATE INDEX "audit_events_actor_created_idx" ON "audit_events"("actor_type", "actor_id", "created_at");

-- CreateIndex
CREATE INDEX "audit_events_action_created_idx" ON "audit_events"("action", "created_at");

-- AddForeignKey
ALTER TABLE "member_profiles" ADD CONSTRAINT "member_profiles_account_id_fkey" FOREIGN KEY ("account_id") REFERENCES "member_accounts"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "otp_challenges" ADD CONSTRAINT "otp_challenges_account_id_fkey" FOREIGN KEY ("account_id") REFERENCES "member_accounts"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "member_consents" ADD CONSTRAINT "member_consents_account_id_fkey" FOREIGN KEY ("account_id") REFERENCES "member_accounts"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "member_consents" ADD CONSTRAINT "member_consents_terms_version_id_fkey" FOREIGN KEY ("terms_version_id") REFERENCES "policy_document_versions"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "member_consents" ADD CONSTRAINT "member_consents_privacy_version_id_fkey" FOREIGN KEY ("privacy_version_id") REFERENCES "policy_document_versions"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
