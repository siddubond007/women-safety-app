# Sakhi Stage 1 — Gemini ZIP Reconciliation Audit

Audit date: 2026-11-07
Repository: https://github.com/siddubond007/women-safety-app
Integration branch: `integration/gemini-modules8-12-reconciliation-20261107`
Integration base: `a60094e86ed48b1c8fc39061550bbb4ef2e0e9a0`

## 1. Source archive integrity

- Archive: `SAKHI_MODULES8-12_FINAL_REVIEWED_SOURCE_20261106.zip`
- SHA-256: `da877c3256298427cd91a6eb51359a4cec4c7d4cc79295c790ebb424d19e33b1`
- Compressed size: 19,043,122 bytes
- ZIP entries/files: 575 (no explicit directory entries)
- Total uncompressed size: 24,109,224 bytes
- `ZipFile.testzip()`: passed; no corrupt member reported
- Duplicate member paths: 0
- Unsafe absolute, drive-letter, or parent-traversal paths: 0
- Extracted only to `/mnt/data/sakhi_stage1_audit`, outside the repository.

### Manifest discrepancy

The embedded `SAKHI_ZIP_MANIFEST.txt` reports 572 files and 24,069,253 uncompressed bytes. The actual archive has 575 file entries and 24,109,224 bytes: +3 entries and +39,971 bytes. The manifest's declared archive filename also names the older `SAKHI_MODULES8-12_REPAIRED_COMPLETE_SOURCE_20261106.zip`, not the actual reviewed archive. Treat the manifest counts/name as stale; the actual ZIP inventory and hash above are authoritative.

### Inventory by top-level component

| Component | Files |
|---|---:|
| app | 364 |
| backend | 130 |
| super-admin | 37 |
| docs | 25 |
| repository root | 12 |
| .github | 4 |
| scripts | 3 |
| **Total** | **575** |

## 2. Supporting documentation reviewed

- `SAKHI_FINAL_REVIEW_HANDOFF.md`
- `SAKHI_REPAIR_REPORT.md`
- `SAKHI_ZIP_MANIFEST.txt`
- `SAKHI_SOURCE_EXPORT_README.txt`

The handoff and repair report explicitly distinguish static review from runtime validation. Their limitations were retained rather than promoting Gemini's feature claims to verified behavior.

## 3. Reconciliation against PR #36 candidate

Live candidate at audit start:
- Branch: `review/sakhi-modules8-12-clean-candidate-20261107`
- Commit: `a60094e86ed48b1c8fc39061550bbb4ef2e0e9a0`
- PR #36: open, draft, unmerged; 57 changed-file paths.

The GitHub candidate tree contains 575 files. The archive was compared against all 57 paths changed by PR #36 using Git blob SHA-1 checks, including CRLF/LF normalization:

- 32 paths match the archive after line-ending normalization (29 line-ending-only matches and 3 byte-identical matches).
- 21 paths contain substantive content differences beyond line endings.
- 4 candidate paths are absent from the ZIP: `.gitattributes`, the ZIP itself (expected not to self-embed), `backend/scripts/staging-build.sh`, and `backend/scripts/staging-migrate-reviewed.sh`.

The 21 substantive differences were not blindly overwritten. Safety-critical candidate differences inspected include:
- Prisma staging command gates and explicit migration/bootstrap approvals.
- Full Module 1–7 predecessor migration preflight and exact pending-migration allowlist.
- Render compile-only build behavior.
- Modules 8–12 forward migration and rollback.
- Runtime grants and RLS policies.
- Backend messaging, admin evidence-preview and moderation paths.
- Corresponding regression tests and CI workflow changes.

The clean candidate is later and safer than the ZIP in important staging/deployment safeguards. It remains the integration base; no ZIP overlay was performed.

## 4. Engineering changes on this isolated branch

1. `backend/scripts/build.mjs`: corrected a stale comment that still described a removed Module 6 migration flag. The build script now clearly states it never applies migrations or executes SQL.
2. `backend/prisma/migrations/20261106010000_modules8_9_10_11_12_complete/rollback.sql`: added a guarded revoke of the CRUD grants that the forward migration adds to the three Module 7 menstrual tables for `sakhi_dev_app`, `sakhi_test_app`, and `sakhi_staging_app`. The Module 1–7 staging grants and bootstrap-role script were checked; those tables were not granted in the prior staging baseline and blanket default privileges are disabled. The rollback then drops the migration policies and disables RLS to restore the Module 7 pre-migration state.
3. `backend/test/modules8_to_12_complete.spec.ts`: added a rollback-contract test covering the grant revocation and RLS restoration.
4. `backend/src/admin-review/admin-review.service.ts`: evidence preview now propagates media/audit lookup errors and fails closed if the preview audit event cannot be written. Report moderation side effects, account/session enforcement, moderation-decision persistence, media quarantine/restore and police-station deletion no longer swallow database write failures.
5. `backend/test/modules8_to_12_complete.spec.ts`: added regression cases for evidence lookup failure and preview-audit write failure.

No live database mutation, Render deployment, or change to main/PR #35/PR #36 was performed.

## 5. Source review findings retained for follow-up

- The previously identified message, notification and report-triage persistence maps are absent from the relevant backend services; those flows now use Prisma persistence.
- `Module2Service` still has process-local `commentLikesMap`, `postPollMetaMap`, and `postExtraMediaMap`. Poll votes, comment-like state and additional post-media lists are therefore not demonstrably durable across service restarts. These are separate from the removed messaging/notification/report-triage maps and were not redesigned in this stage.
- Unified search applies category selection and pagination, but its per-category service calls still catch failures and may return empty collections instead of surfacing partial backend failures. Record as an error-reporting improvement.
- The handoff's known product gaps remain: quiet-hours persistence/enforcement; FCM/APNs push delivery and token lifecycle; demonstrated end-to-end encryption and retention policy; complete active-conversation block/report controls; business-owner enquiry inbox verification; and physical-device validation of TTS, synthesized AudioTrack soundscapes and Android alarm/reboot behavior.
- RLS on the three menstrual tables is a database-role boundary using the API runtime login; account ownership remains enforced in NestJS. It is not per-row isolation for arbitrary direct SQL access by that runtime role.
- No physical Android/iOS device tests or live staging feature tests were performed.

## 6. Migration and deployment safety review

- Normal backend build is compile-only; no migration command is invoked by `build.mjs`.
- `prisma.config.ts` gates staging mutation commands behind exact explicit approval and invokes preflight for the reviewed migration.
- `staging-preflight.cjs` checks the dedicated Supabase project/host/user/TLS, Module 1–7 migration ledger, unfinished migrations, and the exact pending migration set.
- `staging-migrate-reviewed.sh` runs preflight before deploy and applies reviewed runtime grants afterward.
- `bootstrap-staging.ps1` checks the target and empty schema and requires a separate explicit bootstrap phrase.
- Forward migration, rollback and Prisma schema were inspected together. The grant rollback correction is covered by a new contract test; SQL has not been executed.
- `render.yaml` was inspected only as source. Live Render service settings were not changed or deployed.
- Supabase migration status remains unapplied/unverified in this stage; no SQL was executed.

## 7. Validation status

Previously completed on the clean candidate commit `a60094e86ed48b1c8fc39061550bbb4ef2e0e9a0`:
- 4/4 GitHub Actions workflows completed successfully.
- 9/9 jobs completed successfully, including backend Prisma validation/type-check/tests/build, Super Admin type-check/lint/build, Flutter analysis/tests and staging APK build/signature checks, plus iOS source validation/build.

Those results predate the integration-branch fixes. New integration-branch CI must run before Stage 1 can be declared complete. The connected Codespace/device was unavailable during this audit; no local full toolchain test is claimed.

## 8. Safety state

At the time of this audit:
- `main` remains `d304f119e62c4be1c7624873f7ce0c5e2a53f2d5`.
- PR #35 remains open/draft/unmerged at `aeeb9bf6e3485ebf9b3a590e1fa7e0f33c6bbf52`.
- PR #36 remains open/draft/unmerged at `a60094e86ed48b1c8fc39061550bbb4ef2e0e9a0`.
- The integration branch was created from PR #36's exact head; no existing branch was overwritten.
- No Render settings, Supabase schema, migrations, or live deployment were changed.
- The archive and supporting assets were not deleted or overwritten.

## 9. Outstanding Stage 1 gates

1. Run integration-branch GitHub Actions against the rollback and admin error-handling fixes; inspect every job and log.
2. Resolve any test/build failures.
3. Review the full PR diff and confirm no unintended files or secret material.
4. Keep the branch and any validation PR draft/unmerged.
5. Record any remaining SQL review limitations; never execute the migration in this stage.

Stage 1 is not complete until the integration-branch CI and final diff review are complete.


## 10. Additional handoff findings and live-staging caveats

The full Gemini handoff and repair report were re-read after the initial inventory. The following exact limitations remain relevant:

- Quiet hours: no persisted quiet-hours fields, API contract or time-window enforcement was found.
- Push delivery: no Firebase Cloud Messaging/APNs delivery integration or device-token lifecycle was found; the in-app inbox is not push delivery.
- Message security: end-to-end encryption is not demonstrated; retention and moderator-access policy still require a product/security decision.
- Active conversations: the Requests tab has Accept/Decline/Block, but the active conversation view lacks a complete message-level Block/Report control set.
- Business enquiries: member-to-member messaging exists; the business-owner enquiry inbox still requires end-to-end verification.
- TTS and soundscapes: FlutterTts is device-native and voice varies by engine; Android AudioTrack soundscapes are synthesized harmonic tones, not recorded music or generative AI audio. Device audio-focus and perceived quality remain unverified.
- The prior handoff reported that Supabase's security advisor saw the three Module 7 menstrual tables with RLS enabled but no policies, while the tracked Module 7 migration creates them without enabling RLS. The current Modules 8–12 forward migration adds runtime-role policies; its rollback restores the tracked Module 7 state by disabling RLS. This is a live-environment drift caveat: before any future migration/rollback approval, read-only inspection must establish the actual current RLS flags and ACLs so rollback does not silently change a pre-existing live state.
- The prior handoff reported the Supabase migration-list API returned an empty list. The actual `public._prisma_migrations` ledger has not been queried in this stage. The current preflight requires that ledger and every Module 1–7 predecessor to be recorded; if the ledger is absent/incomplete, preflight intentionally refuses. The empty-schema bootstrap also refuses non-empty application schemas. A separate, audited baseline-adoption procedure may be needed; do not bypass the gate or mark migrations as resolved without inspecting the live schema and migration history.
- At the time of the handoff, the two Render services tracked `main`. The candidate `render.yaml` contains a feature-branch setting, but no live Render service setting was inspected or changed during this stage. No deploy occurred.

These are release/deployment follow-up blockers or product gaps, not reasons to expand Stage 1 into live infrastructure changes.
