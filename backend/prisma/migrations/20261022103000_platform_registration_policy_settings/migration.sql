CREATE TABLE "platform_registration_policies" (
  "policy_key" VARCHAR(40) NOT NULL DEFAULT 'default',
  "minimum_age_years" INTEGER NOT NULL DEFAULT 18,
  "updated_by" VARCHAR(120),
  "change_reason" VARCHAR(500),
  "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "platform_registration_policies_pkey" PRIMARY KEY ("policy_key")
);
