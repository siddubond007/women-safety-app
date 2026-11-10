-- Stage 3D: database-enforced member isolation for strictly private menstrual data.
-- Identity is transaction-local and is set only by PrismaService.withMemberIdentity().
-- Missing/empty identity yields NULL and therefore no row matches (fail closed).

DO $stage3d_preflight$
DECLARE
  v_table_name TEXT;
BEGIN
  FOREACH v_table_name IN ARRAY ARRAY[
    'menstrual_cycle_logs',
    'menstrual_daily_logs',
    'menstrual_tracker_preferences'
  ] LOOP
    IF to_regclass(format('public.%I', v_table_name)) IS NULL THEN
      RAISE EXCEPTION 'Stage 3D requires existing table public.%', v_table_name;
    END IF;
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public' AND information_schema.columns.table_name = v_table_name
        AND column_name = 'account_id' AND data_type = 'uuid'
    ) THEN
      RAISE EXCEPTION 'Stage 3D requires UUID account_id on public.%', v_table_name;
    END IF;
  END LOOP;
END
$stage3d_preflight$;

-- Remove the previous role-only policy. Do not leave a permissive policy that
-- would OR with and defeat the new account-scoped policy.
DROP POLICY IF EXISTS "menstrual_cycle_logs_backend_runtime_access" ON public.menstrual_cycle_logs;
DROP POLICY IF EXISTS "menstrual_daily_logs_backend_runtime_access" ON public.menstrual_daily_logs;
DROP POLICY IF EXISTS "menstrual_tracker_preferences_backend_runtime_access" ON public.menstrual_tracker_preferences;

ALTER TABLE public.menstrual_cycle_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.menstrual_cycle_logs FORCE ROW LEVEL SECURITY;
ALTER TABLE public.menstrual_daily_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.menstrual_daily_logs FORCE ROW LEVEL SECURITY;
ALTER TABLE public.menstrual_tracker_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.menstrual_tracker_preferences FORCE ROW LEVEL SECURITY;

CREATE POLICY menstrual_cycle_logs_member_isolation
  ON public.menstrual_cycle_logs FOR ALL TO PUBLIC
  USING (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND account_id = NULLIF(current_setting('app.account_id', true), '')::uuid)
  WITH CHECK (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND account_id = NULLIF(current_setting('app.account_id', true), '')::uuid);

CREATE POLICY menstrual_daily_logs_member_isolation
  ON public.menstrual_daily_logs FOR ALL TO PUBLIC
  USING (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND account_id = NULLIF(current_setting('app.account_id', true), '')::uuid)
  WITH CHECK (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND account_id = NULLIF(current_setting('app.account_id', true), '')::uuid);

CREATE POLICY menstrual_tracker_preferences_member_isolation
  ON public.menstrual_tracker_preferences FOR ALL TO PUBLIC
  USING (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND account_id = NULLIF(current_setting('app.account_id', true), '')::uuid)
  WITH CHECK (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app') AND account_id = NULLIF(current_setting('app.account_id', true), '')::uuid);

-- Refuse to install if a runtime login owns a protected table. Table owners can
-- otherwise bypass ordinary RLS; FORCE RLS is defense in depth, not a substitute
-- for separating migration and runtime identities.
DO $stage3d_owner_preflight$
DECLARE owner_record RECORD;
BEGIN
  FOR owner_record IN
    SELECT c.relname, r.rolname
    FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
    JOIN pg_roles r ON r.oid = c.relowner
    WHERE n.nspname = 'public'
      AND c.relname IN ('menstrual_cycle_logs','menstrual_daily_logs','menstrual_tracker_preferences')
      AND r.rolname IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app')
  LOOP
    RAISE EXCEPTION 'Protected table % must not be owned by runtime role %', owner_record.relname, owner_record.rolname;
  END LOOP;
END
$stage3d_owner_preflight$;

-- Existing table grants are intentionally preserved; RLS now narrows the rows.
-- Runtime roles must not own these tables or have SUPERUSER/BYPASSRLS attributes.
DO $stage3d_role_preflight$
DECLARE role_record RECORD;
BEGIN
  FOR role_record IN
    SELECT rolname FROM pg_roles
    WHERE rolname IN ('sakhi_dev_app', 'sakhi_test_app', 'sakhi_staging_app')
      AND (rolsuper OR rolbypassrls)
  LOOP
    RAISE EXCEPTION 'Stage 3D runtime role % must not be SUPERUSER or BYPASSRLS', role_record.rolname;
  END LOOP;
END
$stage3d_role_preflight$;
