# Staging legacy media integrity receipt backfill

## Purpose

Older Sakhi member-media uploads predate the Drive `sakhiSha256` and `sakhiByteSize` appProperties. Their PostgreSQL `media_assets.sha256_checksum` values are null. The member-media resolver intentionally fails closed when it cannot verify a trusted receipt.

This one-shot internal worker establishes a checksum baseline for eligible legacy staging media. It is not an API route and must never be enabled in production.

## Scope and safeguards

The worker selects only non-deleted Google Drive assets with null database checksums, status `UPLOADED` or `ATTACHED`, and purpose `PROFILE_PHOTO` or `COMMUNITY_POST_IMAGE`.

For every file it verifies:
- Drive file ID and non-trashed status
- Existing Sakhi owner account ID and upload ID metadata
- Existing Sakhi purpose metadata (`avatar` or `post`)
- Post category metadata when applicable
- Expected Drive parent folder
- Drive MIME type and stored byte size
- Downloaded byte count and SHA-256

If the metadata or bytes do not match, the asset is left unchanged and the job does not write its completion marker.

The worker never changes media content, ownership, post association, visibility, status, or folder location. Apply mode only adds the missing SHA-256/byte-size appProperties to the existing Drive file, updates the matching database checksum, and writes audit events. A narrowly scoped RLS INSERT policy permits only these two backfill audit actions from the staging/test app roles when the internal system-job identity is active; it does not grant generic SYSTEM audit writes.

The worker is limited to 25 assets per run. It uses the internal system-job database identity and is not exposed through a controller.

## Preview (read-only)

On the Render service `sakhi-staging-api` only, set:

- `SAKHI_STAGING_MEDIA_INTEGRITY_BACKFILL_MODE=preview`

Keep `SAKHI_STAGING_MEDIA_INTEGRITY_BACKFILL_CONFIRM` unset.

The worker runs once during startup, downloads and hashes eligible objects, and logs per-media-ID results plus a summary. Preview mode does not patch Drive metadata, update PostgreSQL, or write audit events.

Review the Render logs. Proceed to apply only if every eligible asset reports `status=verified` and no rejection or failure reason is present.

## Apply (requires separate approval)

Only after reviewing the preview and receiving explicit approval, set both variables on the staging API service:

- `SAKHI_STAGING_MEDIA_INTEGRITY_BACKFILL_MODE=apply`
- `SAKHI_STAGING_MEDIA_INTEGRITY_BACKFILL_CONFIRM=APPLY_STAGING_MEDIA_INTEGRITY_BACKFILL_V1`

The worker patches only missing Drive receipts, verifies the patch response, updates each matching database checksum, and records an audit event. It writes a completion marker only if every eligible asset verifies and persists successfully.

If any asset fails or is rejected, it remains unchanged and no completion marker is written. The operation is idempotent: a retry recognizes a valid existing Drive receipt and can complete the corresponding database checksum.

## After completion

1. Confirm the completion summary and per-asset audit records in Render logs.
2. Read-only query staging to confirm no eligible legacy media rows remain with null checksums.
3. Remove both temporary environment variables from the Render service and allow the normal deployment to restart.
4. Verify API readiness and Google Drive connectivity.
5. Perform an authenticated member media retrieval and a new upload from the staging app.

Never copy the temporary confirmation value into logs or commit it to source control. Do not enable this worker on production.
