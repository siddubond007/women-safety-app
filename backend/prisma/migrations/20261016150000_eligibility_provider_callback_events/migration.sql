-- Persist only normalized provider callback event identifiers/outcomes for replay protection.
-- Raw callback payloads and raw identity-provider attributes are never stored here.
CREATE TYPE "eligibility_provider_callback_outcome" AS ENUM (
  'VERIFIED',
  'PENDING_MANUAL_REVIEW',
  'VERIFICATION_FAILED'
);

CREATE TABLE "eligibility_provider_callback_events" (
  "id" UUID NOT NULL,
  "provider_key" VARCHAR(64) NOT NULL,
  "provider_event_id" VARCHAR(255) NOT NULL,
  "session_id" UUID NOT NULL,
  "outcome" "eligibility_provider_callback_outcome" NOT NULL,
  "received_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "eligibility_provider_callback_events_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "eligibility_provider_callback_event_key"
  ON "eligibility_provider_callback_events"("provider_key", "provider_event_id");
CREATE INDEX "eligibility_provider_callback_session_received_idx"
  ON "eligibility_provider_callback_events"("session_id", "received_at");

ALTER TABLE "eligibility_provider_callback_events"
  ADD CONSTRAINT "eligibility_provider_callback_events_session_id_fkey"
  FOREIGN KEY ("session_id") REFERENCES "eligibility_verification_sessions"("id")
  ON DELETE CASCADE ON UPDATE CASCADE;

-- Least-privilege access for the selected Sakhi environment only.
DO $grant_eligibility_callback_permissions$
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

  EXECUTE format(
    'GRANT SELECT, INSERT ON TABLE public.eligibility_provider_callback_events TO %I',
    app_role
  );
END
$grant_eligibility_callback_permissions$;
