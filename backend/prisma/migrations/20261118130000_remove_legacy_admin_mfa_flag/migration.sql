-- Remove the unused legacy account-level MFA Boolean.
-- The authoritative MFA state is admin_staff_mfa.enrollment_verified_at
-- together with admin_staff_mfa.disabled_at. No MFA enrollment, TOTP secret,
-- replay-prevention state, recovery code, or audit record is modified.

DO $$
BEGIN
  IF to_regclass('public.admin_staff_accounts') IS NULL THEN
    RAISE EXCEPTION 'admin_staff_accounts is missing; refusing legacy MFA flag cleanup.';
  END IF;

  IF to_regclass('public.admin_staff_mfa') IS NULL THEN
    RAISE EXCEPTION 'admin_staff_mfa is missing; refusing legacy MFA flag cleanup.';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'admin_staff_mfa'
      AND column_name = 'enrollment_verified_at'
  ) OR NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'admin_staff_mfa'
      AND column_name = 'disabled_at'
  ) THEN
    RAISE EXCEPTION 'Authoritative MFA state columns are missing; refusing legacy flag cleanup.';
  END IF;
END $$;

-- Deliberately omit CASCADE: any unexpected database dependency must fail
-- the migration for review rather than be silently removed.
ALTER TABLE public.admin_staff_accounts
  DROP COLUMN IF EXISTS mfa_enabled;
