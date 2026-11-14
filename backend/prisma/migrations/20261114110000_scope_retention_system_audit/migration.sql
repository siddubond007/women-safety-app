BEGIN;

-- Keep the OTP SYSTEM exception unchanged. Add only the two exact audit event
-- shapes emitted by the internal retention/deletion worker. The transaction
-- context is set only by PrismaService.withSystemAdminIdentity().
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
      OR (
        actor_type='SYSTEM'
        AND actor_id IS NULL
        AND current_setting('app.system_job',true)='true'
        AND action='module2.account.deletion_completed'
        AND target_type='account_deletion_request'
        AND target_id IS NOT NULL
        AND request_id=target_id
        AND outcome='completed'
        AND redacted_metadata->>'externalMediaPurged'='true'
        AND COALESCE(redacted_metadata->>'mediaAssetCount','') ~ '^(0|[1-9][0-9]*)$'
      )
      OR (
        actor_type='SYSTEM'
        AND actor_id IS NULL
        AND current_setting('app.system_job',true)='true'
        AND action='module5.complaint.evidence.retention_purged'
        AND target_type='module5_complaint'
        AND target_id LIKE '#SKH-ANON-%'
        AND outcome='purged'
        AND redacted_metadata->>'retentionPurge'='true'
        AND COALESCE(redacted_metadata->>'evidenceCount','') ~ '^(0|[1-9][0-9]*)$'
        AND request_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
      )
    )
  );

DO $retention_system_audit_postflight$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname='public'
      AND tablename='audit_events'
      AND policyname='audit_events_member_or_admin_insert'
      AND cmd='INSERT'
      AND with_check LIKE '%app.system_job%'
      AND with_check LIKE '%module2.account.deletion_completed%'
      AND with_check LIKE '%module5.complaint.evidence.retention_purged%'
      AND with_check LIKE '%auth.otp.requested%'
  ) THEN
    RAISE EXCEPTION 'Scoped retention SYSTEM audit policy was not installed';
  END IF;
END
$retention_system_audit_postflight$;

COMMIT;
