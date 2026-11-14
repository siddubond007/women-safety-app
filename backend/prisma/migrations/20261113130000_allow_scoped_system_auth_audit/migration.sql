BEGIN;

-- Permit only the narrowly scoped system audit event emitted by the public OTP
-- request flow. The request middleware sets auth_lookup transaction-locally;
-- this does not grant general SYSTEM audit insertion or member-row access.
DROP POLICY IF EXISTS audit_events_member_or_admin_insert ON public.audit_events;

CREATE POLICY audit_events_member_or_admin_insert ON public.audit_events
  FOR INSERT TO PUBLIC
  WITH CHECK (
    current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app')
    AND (
      (actor_type='MEMBER' AND actor_id=NULLIF(current_setting('app.account_id',true),'')::uuid)
      OR (
        actor_type='ADMIN'
        AND actor_id=NULLIF(current_setting('app.admin_staff_id',true),'')::uuid
        AND NULLIF(current_setting('app.admin_role',true),'') IS NOT NULL
      )
      OR (
        actor_type='SYSTEM'
        AND actor_id IS NULL
        AND action='auth.otp.requested'
        AND target_type='otp_challenge'
        AND target_id IS NOT NULL
        AND request_id=target_id
        AND current_setting('app.auth_lookup',true)='true'
      )
    )
  );

DO $auth_audit_policy_postflight$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname='public'
      AND tablename='audit_events'
      AND policyname='audit_events_member_or_admin_insert'
      AND cmd='INSERT'
  ) THEN
    RAISE EXCEPTION 'Scoped auth OTP system audit insert policy was not installed';
  END IF;
END
$auth_audit_policy_postflight$;

COMMIT;
