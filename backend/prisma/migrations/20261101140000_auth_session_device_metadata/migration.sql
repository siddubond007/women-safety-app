-- Store a coarse platform label for each authenticated session so members
-- can distinguish their own devices without collecting precise location.
ALTER TABLE "auth_sessions"
ADD COLUMN "device_name" VARCHAR(80);

-- The previous 2FA switch only changed a UI/database boolean and did not
-- provision or enforce a second factor. Clear those misleading legacy flags.
UPDATE "member_profiles"
SET "two_factor_enabled" = FALSE
WHERE "two_factor_enabled" IS DISTINCT FROM FALSE;
