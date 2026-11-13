BEGIN;

-- Sakhi P0 administrative security foundation.
-- Additive only: preserves existing staff records and legacy credential columns.
-- This migration is NOT applied to any database by this change.
-- Complaint lockout fields and staff digest uniqueness are source-only additions.

ALTER TABLE public.discreet_complaints
  ALTER COLUMN passkey_digest TYPE varchar(192),
  ADD COLUMN IF NOT EXISTS passkey_failed_attempts integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS passkey_locked_until timestamptz(6);

ALTER TABLE public.admin_staff_accounts
  ADD COLUMN IF NOT EXISTS suspended_at timestamptz(6),
  ADD COLUMN IF NOT EXISTS suspended_by uuid,
  ADD COLUMN IF NOT EXISTS deleted_at timestamptz(6),
  ADD COLUMN IF NOT EXISTS deleted_by uuid;

-- Database-enforced one-time bootstrap guard. Later Super Admins created
-- through normal staff governance are not constrained by this partial index.
DO $$
BEGIN
  IF (
    SELECT count(*)
    FROM public.admin_staff_accounts
    WHERE role = 'SUPER_ADMIN'
      AND created_by = 'One-time protected Super Admin bootstrap'
  ) > 1 THEN
    RAISE EXCEPTION
      'Multiple bootstrap Super Admin rows already exist; resolve them before applying the security baseline.';
  END IF;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS admin_staff_one_time_super_admin_bootstrap_unique
  ON public.admin_staff_accounts (created_by)
  WHERE role = 'SUPER_ADMIN'
    AND created_by = 'One-time protected Super Admin bootstrap';

CREATE TABLE IF NOT EXISTS public.admin_staff_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  staff_id uuid NOT NULL,
  session_family_id uuid NOT NULL,
  token_digest varchar(64) NOT NULL,
  created_at timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  last_seen_at timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  expires_at timestamptz(6) NOT NULL,
  rotated_at timestamptz(6),
  revoked_at timestamptz(6),
  revoke_reason varchar(80),
  replaced_by_session_id uuid,
  CONSTRAINT admin_staff_sessions_token_digest_key UNIQUE (token_digest),
  CONSTRAINT admin_staff_sessions_staff_id_fkey
    FOREIGN KEY (staff_id) REFERENCES public.admin_staff_accounts(id)
    ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE INDEX IF NOT EXISTS admin_staff_sessions_staff_active_idx
  ON public.admin_staff_sessions (staff_id, revoked_at, expires_at);
CREATE INDEX IF NOT EXISTS admin_staff_sessions_family_active_idx
  ON public.admin_staff_sessions (session_family_id, revoked_at);
CREATE INDEX IF NOT EXISTS admin_staff_sessions_expires_idx
  ON public.admin_staff_sessions (expires_at);

CREATE TABLE IF NOT EXISTS public.admin_staff_mfa (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  staff_id uuid NOT NULL,
  encrypted_secret text NOT NULL,
  secret_iv varchar(32) NOT NULL,
  secret_auth_tag varchar(32) NOT NULL,
  encryption_key_version varchar(24) NOT NULL DEFAULT 'v1',
  enrollment_verified_at timestamptz(6),
  last_accepted_time_step bigint NOT NULL DEFAULT -1,
  failed_attempt_count integer NOT NULL DEFAULT 0,
  locked_until timestamptz(6),
  disabled_at timestamptz(6),
  created_at timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT admin_staff_mfa_staff_id_key UNIQUE (staff_id),
  CONSTRAINT admin_staff_mfa_staff_id_fkey
    FOREIGN KEY (staff_id) REFERENCES public.admin_staff_accounts(id)
    ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE IF NOT EXISTS public.admin_staff_backup_codes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  staff_id uuid NOT NULL,
  code_digest varchar(64) NOT NULL,
  used_at timestamptz(6),
  created_at timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT admin_staff_backup_codes_digest_key UNIQUE (code_digest),
  CONSTRAINT admin_staff_backup_codes_staff_id_fkey
    FOREIGN KEY (staff_id) REFERENCES public.admin_staff_accounts(id)
    ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE INDEX IF NOT EXISTS admin_staff_backup_codes_staff_used_idx
  ON public.admin_staff_backup_codes (staff_id, used_at);

CREATE TABLE IF NOT EXISTS public.admin_staff_recovery_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  staff_id uuid NOT NULL,
  challenge_digest varchar(64) NOT NULL,
  status varchar(24) NOT NULL DEFAULT 'PENDING',
  requested_at timestamptz(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  expires_at timestamptz(6) NOT NULL,
  attempt_count integer NOT NULL DEFAULT 0,
  approved_by_staff_id uuid,
  completed_at timestamptz(6),
  CONSTRAINT admin_staff_recovery_requests_digest_key UNIQUE (challenge_digest),
  CONSTRAINT admin_staff_recovery_requests_staff_id_fkey
    FOREIGN KEY (staff_id) REFERENCES public.admin_staff_accounts(id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT admin_staff_recovery_requests_attempt_count_check
    CHECK (attempt_count >= 0)
);

CREATE INDEX IF NOT EXISTS admin_staff_recovery_requests_staff_status_idx
  ON public.admin_staff_recovery_requests (staff_id, status, expires_at);

-- Expired requests are no longer active. Refuse to silently choose between
-- multiple still-valid requests; resolve those explicitly before deployment.
DO $$
BEGIN
  IF EXISTS (
    SELECT staff_id
    FROM public.admin_staff_recovery_requests
    WHERE status IN ('PENDING', 'APPROVED')
      AND expires_at > CURRENT_TIMESTAMP
    GROUP BY staff_id
    HAVING count(*) > 1
  ) THEN
    RAISE EXCEPTION
      'Multiple active MFA recovery requests exist for a staff account; resolve them before applying the security baseline.';
  END IF;
END $$;

-- SQL-managed partial unique index (not representable in Prisma schema DSL):
-- at most one active recovery request per staff account, even under concurrency.
CREATE UNIQUE INDEX IF NOT EXISTS admin_staff_recovery_one_active_per_staff_unique
  ON public.admin_staff_recovery_requests (staff_id)
  WHERE status IN ('PENDING', 'APPROVED');

-- These records are backend-only. Do not expose them through Supabase's
-- anon/authenticated Data API roles.
REVOKE ALL ON TABLE
  public.admin_staff_accounts,
  public.admin_staff_sessions,
  public.admin_staff_mfa,
  public.admin_staff_backup_codes,
  public.admin_staff_recovery_requests
FROM PUBLIC;

ALTER TABLE public.admin_staff_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_staff_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_staff_mfa ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_staff_backup_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_staff_recovery_requests ENABLE ROW LEVEL SECURITY;

DO $$
DECLARE
  runtime_role text;
  table_name text;
  policy_name text;
BEGIN
  -- This managed staging role is a required security principal, not an
  -- optional capability. Fail before applying any grants or policies if it
  -- has not been provisioned by the Supabase project owner.
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'sakhi_staging_app') THEN
    RAISE EXCEPTION
      'Required managed staging runtime role sakhi_staging_app is missing; provision it before applying the P0 staff-security baseline.';
  END IF;

  -- Never grant staging staff-security tables to dev/test roles.
  FOREACH runtime_role IN ARRAY ARRAY['sakhi_staging_app'] LOOP
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = runtime_role) THEN
      EXECUTE format(
        'REVOKE ALL ON TABLE public.admin_staff_accounts, public.admin_staff_sessions, public.admin_staff_mfa, public.admin_staff_backup_codes, public.admin_staff_recovery_requests FROM %I',
        runtime_role
      );
      EXECUTE format(
        'GRANT SELECT, INSERT, UPDATE ON TABLE public.admin_staff_accounts, public.admin_staff_sessions, public.admin_staff_mfa, public.admin_staff_backup_codes, public.admin_staff_recovery_requests TO %I',
        runtime_role
      );

      FOREACH table_name IN ARRAY ARRAY[
        'admin_staff_accounts',
        'admin_staff_sessions',
        'admin_staff_mfa',
        'admin_staff_backup_codes',
        'admin_staff_recovery_requests'
      ] LOOP
        EXECUTE format(
          'ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY',
          table_name
        );
        EXECUTE format('ALTER TABLE public.%I FORCE ROW LEVEL SECURITY', table_name);
        policy_name := table_name || '_runtime_' || runtime_role;
        IF EXISTS (
          SELECT 1 FROM pg_policies
          WHERE schemaname = 'public'
            AND tablename = table_name
            AND policyname = policy_name
            AND (qual <> 'true' OR with_check <> 'true')
        ) THEN
          RAISE EXCEPTION 'Existing P0 runtime policy % has an incompatible expression.', policy_name;
        END IF;
        IF NOT EXISTS (
          SELECT 1
          FROM pg_policies
          WHERE schemaname = 'public'
            AND tablename = table_name
            AND policyname = policy_name
        ) THEN
          EXECUTE format(
            'CREATE POLICY %I ON public.%I FOR ALL TO %I USING (true) WITH CHECK (true)',
            policy_name,
            table_name,
            runtime_role
          );
        END IF;
      END LOOP;
    END IF;
  END LOOP;

  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
    REVOKE ALL ON TABLE
      public.admin_staff_accounts,
      public.admin_staff_sessions,
      public.admin_staff_mfa,
      public.admin_staff_backup_codes,
      public.admin_staff_recovery_requests
    FROM anon;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
    REVOKE ALL ON TABLE
      public.admin_staff_accounts,
      public.admin_staff_sessions,
      public.admin_staff_mfa,
      public.admin_staff_backup_codes,
      public.admin_staff_recovery_requests
    FROM authenticated;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN
    REVOKE ALL ON TABLE
      public.admin_staff_accounts,
      public.admin_staff_sessions,
      public.admin_staff_mfa,
      public.admin_staff_backup_codes,
      public.admin_staff_recovery_requests
    FROM service_role;
  END IF;
  IF EXISTS (
    SELECT 1 FROM pg_roles
    WHERE rolname = 'sakhi_staging_app'
      AND (rolsuper OR rolbypassrls OR rolcreatedb OR rolcreaterole)
  ) THEN
    RAISE EXCEPTION 'sakhi_staging_app must be pre-provisioned without SUPERUSER, BYPASSRLS, CREATEDB, or CREATEROLE; managed Supabase does not permit role alteration from migrations.';
  END IF;
  IF EXISTS (
    SELECT 1 FROM pg_class c
    JOIN pg_roles r ON r.oid = c.relowner
    WHERE c.relnamespace = 'public'::regnamespace
      AND c.relname IN ('admin_staff_accounts','admin_staff_sessions','admin_staff_mfa','admin_staff_backup_codes','admin_staff_recovery_requests')
      AND r.rolname = 'sakhi_staging_app'
  ) THEN
    RAISE EXCEPTION 'sakhi_staging_app must not own P0 staff-security tables.';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role')
     AND (
       has_table_privilege('service_role','public.admin_staff_accounts','SELECT')
       OR has_table_privilege('service_role','public.admin_staff_sessions','SELECT')
       OR has_table_privilege('service_role','public.admin_staff_mfa','SELECT')
       OR has_table_privilege('service_role','public.admin_staff_backup_codes','SELECT')
       OR has_table_privilege('service_role','public.admin_staff_recovery_requests','SELECT')
     ) THEN
    RAISE EXCEPTION 'service_role retains effective SELECT access to P0 staff-security tables.';
  END IF;
END $$;

-- A staff credential digest must identify at most one account. This explicit
-- preflight prevents a silent deployment over duplicate historical digests.
DO $$
BEGIN
  IF EXISTS (
    SELECT access_token_digest
    FROM public.admin_staff_accounts
    GROUP BY access_token_digest
    HAVING count(*) > 1
  ) THEN
    RAISE EXCEPTION 'Duplicate admin staff credential digests exist; resolve before P0 migration.';
  END IF;
END $$;
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_indexes
    WHERE schemaname = 'public'
      AND indexname = 'admin_staff_accounts_token_digest_key'
      AND indexdef NOT ILIKE '%UNIQUE% (access_token_digest)%'
  ) THEN
    RAISE EXCEPTION 'Existing admin staff credential digest index has an incompatible definition.';
  END IF;
END $$;
CREATE UNIQUE INDEX IF NOT EXISTS admin_staff_accounts_token_digest_key
  ON public.admin_staff_accounts (access_token_digest);


-- Actor/reference foreign keys omitted from the initial source draft.
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'admin_staff_accounts_suspended_by_fkey') THEN
    ALTER TABLE public.admin_staff_accounts
      ADD CONSTRAINT admin_staff_accounts_suspended_by_fkey
      FOREIGN KEY (suspended_by) REFERENCES public.admin_staff_accounts(id)
      ON DELETE SET NULL ON UPDATE CASCADE;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'admin_staff_accounts_deleted_by_fkey') THEN
    ALTER TABLE public.admin_staff_accounts
      ADD CONSTRAINT admin_staff_accounts_deleted_by_fkey
      FOREIGN KEY (deleted_by) REFERENCES public.admin_staff_accounts(id)
      ON DELETE SET NULL ON UPDATE CASCADE;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'admin_staff_sessions_replaced_by_session_fkey') THEN
    ALTER TABLE public.admin_staff_sessions
      ADD CONSTRAINT admin_staff_sessions_replaced_by_session_fkey
      FOREIGN KEY (replaced_by_session_id) REFERENCES public.admin_staff_sessions(id)
      ON DELETE SET NULL ON UPDATE CASCADE;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'admin_staff_recovery_requests_approved_by_staff_fkey') THEN
    ALTER TABLE public.admin_staff_recovery_requests
      ADD CONSTRAINT admin_staff_recovery_requests_approved_by_staff_fkey
      FOREIGN KEY (approved_by_staff_id) REFERENCES public.admin_staff_accounts(id)
      ON DELETE SET NULL ON UPDATE CASCADE;
  END IF;
END $$;

-- Fail before adding constraints if existing data violates the security model.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM public.admin_staff_accounts WHERE role NOT IN
    ('SUPER_ADMIN','VERIFICATION_ADMIN','CONTENT_MODERATOR','COMPLAINT_REVIEWER','SOS_SAFETY_ADMIN','BUSINESS_ADMIN')) THEN
    RAISE EXCEPTION 'Unknown admin staff role values exist; reconcile before migration.';
  END IF;
  IF EXISTS (SELECT 1 FROM public.admin_staff_accounts WHERE status NOT IN ('ACTIVE','SUSPENDED','REVOKED')) THEN
    RAISE EXCEPTION 'Unknown admin staff status values exist; reconcile before migration.';
  END IF;
  IF EXISTS (SELECT 1 FROM public.admin_staff_accounts WHERE access_token_digest !~ '^[0-9a-fA-F]{64}$') THEN
    RAISE EXCEPTION 'Invalid staff credential digest format exists; reconcile before migration.';
  END IF;
  IF EXISTS (SELECT 1 FROM public.admin_staff_sessions WHERE token_digest !~ '^[0-9a-fA-F]{64}$') THEN
    RAISE EXCEPTION 'Invalid staff session digest format exists; reconcile before migration.';
  END IF;
  IF EXISTS (SELECT 1 FROM public.admin_staff_backup_codes WHERE code_digest !~ '^[0-9a-fA-F]{64}$') THEN
    RAISE EXCEPTION 'Invalid backup-code digest format exists; reconcile before migration.';
  END IF;
  IF EXISTS (SELECT 1 FROM public.admin_staff_recovery_requests WHERE challenge_digest !~ '^[0-9a-fA-F]{64}$') THEN
    RAISE EXCEPTION 'Invalid recovery digest format exists; reconcile before migration.';
  END IF;
  IF EXISTS (SELECT 1 FROM public.admin_staff_mfa WHERE
    failed_attempt_count < 0 OR failed_attempt_count > 5 OR last_accepted_time_step < -1
    OR secret_iv !~ '^[0-9a-fA-F]{24}$' OR secret_auth_tag !~ '^[0-9a-fA-F]{32}$'
    OR encryption_key_version !~ '^v[1-9][0-9]{0,3}$') THEN
    RAISE EXCEPTION 'Invalid MFA state exists; reconcile before migration.';
  END IF;
  IF EXISTS (SELECT 1 FROM public.admin_staff_sessions WHERE expires_at <= created_at) THEN
    RAISE EXCEPTION 'Invalid staff session expiry ordering exists; reconcile before migration.';
  END IF;
  IF EXISTS (SELECT 1 FROM public.admin_staff_recovery_requests WHERE
    attempt_count < 0 OR expires_at <= requested_at OR
    status NOT IN ('PENDING','APPROVED','COMPLETED','EXPIRED','CANCELLED')) THEN
    RAISE EXCEPTION 'Invalid MFA recovery state exists; reconcile before migration.';
  END IF;
  IF EXISTS (SELECT 1 FROM public.discreet_complaints WHERE
    passkey_digest !~ '^[0-9a-fA-F]{64}$'
    AND passkey_digest !~ '^scrypt\$[0-9a-fA-F]{32}\$[0-9a-fA-F]{128}$') THEN
    RAISE EXCEPTION 'Invalid complaint passkey verifier format exists; reconcile before migration.';
  END IF;
  IF EXISTS (SELECT 1 FROM public.discreet_complaints WHERE passkey_failed_attempts < 0 OR passkey_failed_attempts > 5) THEN
    RAISE EXCEPTION 'Invalid complaint passkey lockout counters exist; reconcile before migration.';
  END IF;
END $$;

DO $$
BEGIN
  -- Reconcile a pre-existing six-role constraint in place. The seven-role
  -- model is the canonical target; all legacy role values remain accepted.
  IF EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'admin_staff_accounts_role_check'
      AND conrelid = 'public.admin_staff_accounts'::regclass
      AND pg_get_constraintdef(oid) NOT LIKE '%READ_ONLY_AUDITOR%'
  ) THEN
    ALTER TABLE public.admin_staff_accounts
      DROP CONSTRAINT admin_staff_accounts_role_check;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'admin_staff_accounts_role_check'
      AND conrelid = 'public.admin_staff_accounts'::regclass
  ) THEN
    ALTER TABLE public.admin_staff_accounts ADD CONSTRAINT admin_staff_accounts_role_check
      CHECK (role IN ('SUPER_ADMIN','VERIFICATION_ADMIN','CONTENT_MODERATOR','COMPLAINT_REVIEWER','SOS_SAFETY_ADMIN','BUSINESS_ADMIN','READ_ONLY_AUDITOR'));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'admin_staff_accounts_status_check') THEN
    ALTER TABLE public.admin_staff_accounts ADD CONSTRAINT admin_staff_accounts_status_check
      CHECK (status IN ('ACTIVE','SUSPENDED','REVOKED'));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'admin_staff_mfa_counters_check') THEN
    ALTER TABLE public.admin_staff_mfa ADD CONSTRAINT admin_staff_mfa_counters_check
      CHECK (failed_attempt_count BETWEEN 0 AND 5 AND last_accepted_time_step >= -1);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'admin_staff_mfa_crypto_shape_check') THEN
    ALTER TABLE public.admin_staff_mfa ADD CONSTRAINT admin_staff_mfa_crypto_shape_check
      CHECK (secret_iv ~ '^[0-9a-fA-F]{24}$' AND secret_auth_tag ~ '^[0-9a-fA-F]{32}$'
        AND encryption_key_version ~ '^v[1-9][0-9]{0,3}$');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'admin_staff_accounts_access_digest_check') THEN
    ALTER TABLE public.admin_staff_accounts ADD CONSTRAINT admin_staff_accounts_access_digest_check
      CHECK (access_token_digest ~ '^[0-9a-fA-F]{64}$');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'admin_staff_sessions_digest_check') THEN
    ALTER TABLE public.admin_staff_sessions ADD CONSTRAINT admin_staff_sessions_digest_check
      CHECK (token_digest ~ '^[0-9a-fA-F]{64}$');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'admin_staff_backup_codes_digest_check') THEN
    ALTER TABLE public.admin_staff_backup_codes ADD CONSTRAINT admin_staff_backup_codes_digest_check
      CHECK (code_digest ~ '^[0-9a-fA-F]{64}$');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'admin_staff_recovery_digest_check') THEN
    ALTER TABLE public.admin_staff_recovery_requests ADD CONSTRAINT admin_staff_recovery_digest_check
      CHECK (challenge_digest ~ '^[0-9a-fA-F]{64}$');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'admin_staff_sessions_expiry_check') THEN
    ALTER TABLE public.admin_staff_sessions ADD CONSTRAINT admin_staff_sessions_expiry_check
      CHECK (expires_at > created_at);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'admin_staff_recovery_state_check') THEN
    ALTER TABLE public.admin_staff_recovery_requests ADD CONSTRAINT admin_staff_recovery_state_check
      CHECK (attempt_count >= 0 AND expires_at > requested_at
        AND status IN ('PENDING','APPROVED','COMPLETED','EXPIRED','CANCELLED'));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'discreet_complaints_passkey_lockout_check') THEN
    ALTER TABLE public.discreet_complaints ADD CONSTRAINT discreet_complaints_passkey_lockout_check
      CHECK (passkey_failed_attempts BETWEEN 0 AND 5);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'discreet_complaints_passkey_verifier_check') THEN
    ALTER TABLE public.discreet_complaints ADD CONSTRAINT discreet_complaints_passkey_verifier_check
      CHECK (passkey_digest ~ '^[0-9a-fA-F]{64}$'
        OR passkey_digest ~ '^scrypt\$[0-9a-fA-F]{32}\$[0-9a-fA-F]{128}$');
  END IF;
END $$;

-- CREATE TABLE IF NOT EXISTS is not accepted as proof of schema compatibility.
-- Assert required columns exist after creation; an incompatible pre-existing
-- same-named table fails this migration rather than silently being reused.
DO $$
DECLARE
  required record;
BEGIN
  FOR required IN
    SELECT * FROM (VALUES
      ('admin_staff_sessions','id','uuid',NULL::integer),
      ('admin_staff_sessions','staff_id','uuid',NULL::integer),
      ('admin_staff_sessions','token_digest','varchar',64),
      ('admin_staff_sessions','replaced_by_session_id','uuid',NULL::integer),
      ('admin_staff_mfa','staff_id','uuid',NULL::integer),
      ('admin_staff_mfa','encrypted_secret','text',NULL::integer),
      ('admin_staff_mfa','encryption_key_version','varchar',24),
      ('admin_staff_backup_codes','code_digest','varchar',64),
      ('admin_staff_recovery_requests','staff_id','uuid',NULL::integer),
      ('admin_staff_recovery_requests','approved_by_staff_id','uuid',NULL::integer),
      ('admin_staff_recovery_requests','challenge_digest','varchar',64)
    ) AS required_columns(table_name, column_name, expected_udt, expected_length)
  LOOP
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns c
      WHERE c.table_schema = 'public'
        AND c.table_name = required.table_name
        AND c.column_name = required.column_name
        AND c.udt_name = required.expected_udt
        AND (required.expected_length IS NULL OR c.character_maximum_length = required.expected_length)
    ) THEN
      RAISE EXCEPTION 'Existing P0 table %.% has an incompatible type or is missing.', required.table_name, required.column_name;
    END IF;
  END LOOP;
END $$;

COMMIT;
