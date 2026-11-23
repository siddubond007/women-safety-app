-- Allow only the dedicated staging media-integrity system job to write its two audit event types.
-- This does not grant generic SYSTEM audit insertion and does not apply to production DB roles.
CREATE POLICY audit_events_staging_media_integrity_backfill_insert
ON public.audit_events
FOR INSERT
TO public
WITH CHECK (
  CURRENT_USER = ANY (ARRAY[
    'sakhi_dev_app'::name,
    'sakhi_test_app'::name,
    'sakhi_staging_app'::name
  ])
  AND actor_type = 'SYSTEM'
  AND actor_id IS NULL
  AND current_setting('app.system_job', true) = 'true'
  AND (
    (
      action = 'media.integrity.receipt_backfilled'
      AND target_type = 'media_asset'
      AND target_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
      AND outcome = 'success'
      AND request_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
      AND redacted_metadata ->> 'source' = 'google_drive_verified_download'
      AND COALESCE(redacted_metadata ->> 'receiptPatched', '') IN ('true', 'false')
      AND COALESCE(redacted_metadata ->> 'byteSize', '') ~ '^[1-9][0-9]*$'
    )
    OR
    (
      action = 'media.integrity.receipt_backfill.completed'
      AND target_type = 'maintenance_job'
      AND target_id = 'staging_media_integrity_receipts_v1'
      AND outcome = 'success'
      AND request_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
      AND redacted_metadata ->> 'version' = '1'
      AND COALESCE(redacted_metadata ->> 'assetsScanned', '') ~ '^(0|[1-9][0-9]*)$'
      AND COALESCE(redacted_metadata ->> 'assetsPersisted', '') ~ '^(0|[1-9][0-9]*)$'
      AND COALESCE(redacted_metadata ->> 'bytesProcessed', '') ~ '^(0|[1-9][0-9]*)$'
    )
  )
);

COMMENT ON POLICY audit_events_staging_media_integrity_backfill_insert ON public.audit_events
IS 'Least-privilege INSERT policy for the disabled-by-default staging legacy media integrity backfill system job.';
