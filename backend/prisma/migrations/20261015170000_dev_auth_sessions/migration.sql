-- Development/test authentication sessions and opt-in preference persistence.
-- This migration never resets or deletes data.
CREATE TABLE "auth_sessions" (
    "id" UUID NOT NULL,
    "account_id" UUID NOT NULL,
    "token_digest" VARCHAR(64) NOT NULL,
    "expires_at" TIMESTAMPTZ(6) NOT NULL,
    "revoked_at" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "last_seen_at" TIMESTAMPTZ(6),
    CONSTRAINT "auth_sessions_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "member_communication_preferences" (
    "account_id" UUID NOT NULL,
    "product_updates_accepted" BOOLEAN NOT NULL DEFAULT FALSE,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,
    CONSTRAINT "member_communication_preferences_pkey" PRIMARY KEY ("account_id")
);

CREATE UNIQUE INDEX "auth_sessions_token_digest_key"
    ON "auth_sessions"("token_digest");
CREATE INDEX "auth_sessions_account_expiry_idx"
    ON "auth_sessions"("account_id", "expires_at");
CREATE INDEX "auth_sessions_expiry_idx"
    ON "auth_sessions"("expires_at");

ALTER TABLE "auth_sessions"
    ADD CONSTRAINT "auth_sessions_account_id_fkey"
    FOREIGN KEY ("account_id") REFERENCES "member_accounts"("id")
    ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "member_communication_preferences"
    ADD CONSTRAINT "member_communication_preferences_account_id_fkey"
    FOREIGN KEY ("account_id") REFERENCES "member_accounts"("id")
    ON DELETE CASCADE ON UPDATE CASCADE;

-- Grant only the operations required by the local app runtime role, in the
-- database this migration is being applied to. The test role is never granted
-- access in sakhi_dev (and vice versa).
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
    EXECUTE format(
      'GRANT SELECT, INSERT, UPDATE ON TABLE member_accounts, member_profiles, otp_challenges, member_consents, auth_sessions, member_communication_preferences TO %I',
      app_role
    );
    EXECUTE format('GRANT SELECT ON TABLE policy_document_versions TO %I', app_role);
    EXECUTE format('GRANT INSERT ON TABLE audit_events TO %I', app_role);
    -- Prisma's create() returns inserted data; the app code selects only id.
    -- Keep the runtime role from reading the rest of the audit record.
    EXECUTE format('GRANT SELECT (id) ON TABLE audit_events TO %I', app_role);
END
$grant_runtime_permissions$;
