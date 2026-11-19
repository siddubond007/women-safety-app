BEGIN;

-- Admin staff privilege-bearing attributes must be explicit. Existing records
-- are checked before constraints are installed; unexpected values abort safely.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM public.admin_staff_accounts
    WHERE role NOT IN (
      'SUPER_ADMIN',
      'VERIFICATION_ADMIN',
      'CONTENT_MODERATOR',
      'COMPLAINT_REVIEWER',
      'SOS_SAFETY_ADMIN',
      'BUSINESS_ADMIN',
      'READ_ONLY_AUDITOR'
    )
  ) THEN
    RAISE EXCEPTION 'Unknown admin staff role exists; reconcile records before applying role constraints.';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.admin_staff_accounts
    WHERE status NOT IN ('ACTIVE', 'SUSPENDED', 'REVOKED')
  ) THEN
    RAISE EXCEPTION 'Unknown admin staff status exists; reconcile records before applying status constraints.';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.admin_staff_accounts
    WHERE is_authorised_complaint_reviewer IS TRUE
      AND role NOT IN ('SUPER_ADMIN', 'COMPLAINT_REVIEWER')
  ) THEN
    RAISE EXCEPTION 'Complaint-reviewer clearance conflicts with a staff role; reconcile records before applying constraints.';
  END IF;
END $$;

-- Do not silently create an active staff identity with an implicit role.
ALTER TABLE public.admin_staff_accounts
  ALTER COLUMN role DROP DEFAULT,
  ALTER COLUMN status DROP DEFAULT;

ALTER TABLE public.admin_staff_accounts
  ADD CONSTRAINT admin_staff_accounts_role_allowed_check
    CHECK (role IN (
      'SUPER_ADMIN',
      'VERIFICATION_ADMIN',
      'CONTENT_MODERATOR',
      'COMPLAINT_REVIEWER',
      'SOS_SAFETY_ADMIN',
      'BUSINESS_ADMIN',
      'READ_ONLY_AUDITOR'
    )) NOT VALID,
  ADD CONSTRAINT admin_staff_accounts_status_allowed_check
    CHECK (status IN ('ACTIVE', 'SUSPENDED', 'REVOKED')) NOT VALID,
  ADD CONSTRAINT admin_staff_accounts_reviewer_role_check
    CHECK (
      is_authorised_complaint_reviewer IS NOT TRUE
      OR role IN ('SUPER_ADMIN', 'COMPLAINT_REVIEWER')
    ) NOT VALID;

ALTER TABLE public.admin_staff_accounts
  VALIDATE CONSTRAINT admin_staff_accounts_role_allowed_check,
  VALIDATE CONSTRAINT admin_staff_accounts_status_allowed_check,
  VALIDATE CONSTRAINT admin_staff_accounts_reviewer_role_check;

COMMIT;
