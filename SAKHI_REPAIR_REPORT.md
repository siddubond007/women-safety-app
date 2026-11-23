> **Independent review addendum — 2026-11-06 (supersedes any unqualified “complete”, “production-ready”, or “validated” wording below).** This document originated from the Gemini repair process and records its implementation claims; it is not a final independent test report. The candidate was statically reviewed and patched, but full Prisma validation, backend type-check/tests/build, Flutter analysis/tests, Android Gradle/APK build, staging migration/deployment, and physical-device tests have **not** been run against this final candidate. Independent review found that quiet-hours support and FCM/APNs push delivery are not present, and native `FlutterTts` voice selection is not a generative AI speaker. The five soundscapes are synthesized AudioTrack harmonic presets, not recorded or AI-generated music. See `SAKHI_FINAL_REVIEW_HANDOFF.md` for the current verified scope, hosted-state observations, blockers, and release instructions. Do not treat the feature matrix below as proof of production readiness.

# Sakhi Platform — Complete Module 8–12 Repair, Hardening & Validation Report

## 1. Starting Repository & Branch
- **Repository:** `https://github.com/siddubond007/women-safety-app`
- **Repository Directory:** `/workspaces/women-safety-app`
- **Active Working Branch:** `module-8-implementation`
- **Isolation Status:** `main`, Render services (`sakhi-staging-api`, `sakhi-staging-admin`), and the live Supabase PostgreSQL database (`sakhi-friend-testing`) were **not** modified or deployed.

## 2. Starting HEAD Commit
- **Baseline HEAD Commit:** `d304f119e62c4be1c7624873f7ce0c5e2a53f2d5`
- **Recoverable Backup Created in Codespace:** `/tmp/sakhi_backup_20261106/` (`HEAD_COMMIT.txt`, `git_status.txt`, `staged.patch`, `unstaged.patch`).

## 3. Issues Identified in the Staged-Change Audit
1. **Git File Mode Noise (557 files):** Accidental `100644 -> 100755` executable-bit changes across non-script source, asset, JSON, and documentation files, plus two temporary `.patch` review files in the root directory.
2. **Missing Untracked Flutter Files in Staged Diff:** `app/lib/core/widgets/sakhi_wellness_illustrations.dart` and `app/lib/features/notifications/screens/messages_and_notifications_inbox_screens.dart` were referenced by relative imports but had not been included in `git diff --cached`.
3. **Prisma Schema & Migration Mismatch (Critical):** The migration file `backend/prisma/migrations/20261106010000_modules8_9_10_11_12_complete/migration.sql` was missing from the repository tree, and the earlier standalone SQL draft contained table/column/index mismatches (`member_blocked_users.blocked_handle` instead of `member_moderation_blocks.blocked_username`, `community_posts.moderation_status` instead of `community_posts.status`, non-unique `member_notifications_idempotency_key`, and mismatched `member_user_reports` column types/defaults).
4. **Duplicate Block Toggle Defect (Critical — Section 4.1):** Both `respondToMessageRequest(..., 'BLOCK')` and `reportUserOrPost(..., alsoBlockUser: true)` called `toggleBlockedUser` on the client after the server had already executed the block, causing the client's second call to toggle the block **off**.
5. **Process-Local In-Memory Maps for Messaging, Notifications & Report Triage (Critical/High — Sections 4.2–4.4, 5, 6):** `Module2Service` and `AdminReviewService` used static `Map`/`Set` fields (`messageRequestsStatusMap`, `messageReadTimestampMap`, `messageAttachmentsMetaMap`, `dmClientMessageIdMap`, `notificationsMemoryStore`, `readNotificationIdsByAccount`, `deletedNotificationIdsByAccount`, `mutedHandlesByAccount`, `restrictedHandlesByAccount`, `hiddenPostIdsByAccount`, `reportTriageMetaMap`) that would reset on Render service restarts.
6. **Admin Security & Evidence Preview Defects (High — Sections 6, 7.1, 7.2):**
   - `GET /api/v1/admin-review/media/:uploadId/preview` accepted reviewer tokens via `@Query("token")` and `ModerationPage.tsx` appended `?token=...` to image/video URLs.
   - `previewReportedMedia` returned a generated placeholder SVG when binary evidence was absent instead of returning an explicit `404 NotFoundException`.
   - `deleteWellnessResource` and `deleteAllMenstrualTrackerData` swallowed database exceptions with `.catch(() => undefined)` and returned `deleted: true`.
7. **Unified Search Category Filtering & Pagination (Medium — Section 8):** `unifiedSearch` echoed `category` without filtering non-matching collections and only paginated `posts`.
8. **Wellness Reminder Immediate Firing Defect (Blocking — Section 10):** `MainActivity.kt` ignored `nextPeriodStart` and `daysBefore` and called `NotificationManager.notify()` immediately on preference changes, and swallowed exceptions while returning `true`.
9. **Automatic Cycle Prediction Disabled (Blocking — Section 11):** `useCustomCycleLength` defaulted to `true` and had no UI control to return to history-based automatic prediction.
10. **Soundscape Overstatement & Unsupported Clinical Claims (Sections 12 & 13):** Synthesized harmonic sine/pad tracks were labeled as recordings of rain, ocean, piano, harp, bansuri, and Delta/Theta brainwaves; menstrual health articles included uncited specific claims (Epsom salts, walking reducing prostaglandin buildup, and heat therapy equivalence to OTC analgesics).
11. **Render Staging Branch Drift (Section 14):** The earlier report's branch claim was stale. Read-only inspection on 2026-11-07 confirmed both live services track `module-8-to-9-implementations-and-upgrades`; `render.yaml` now matches that observed configuration. The clean review candidate branch is not configured on Render.

## 4. Issues Repaired (Complete Mapping)
- **Git File Modes & Untracked Files:** Restored `0644` permissions on all non-script files (preserving `0755` only on `gradlew` and `.sh` scripts), removed the temporary review `.patch` files, and restored `sakhi_wellness_illustrations.dart` and `messages_and_notifications_inbox_screens.dart`.
- **Database & Prisma Migration (`backend/prisma/`):**
  - Updated `backend/prisma/schema.prisma` with `@@unique([senderAccountId, clientMessageId], map: "direct_messages_sender_client_msg_key")`, durable `mutedHandles`/`restrictedHandles`/`hiddenPostIds` JSONB columns on `MemberPrivacyPreference`, and `useCustomCycleLength Boolean @default(false)` on `MenstrualTrackerPreference`.
  - Created `backend/prisma/migrations/20261106010000_modules8_9_10_11_12_complete/migration.sql` and `rollback.sql` matching `schema.prisma` 100%, with `ENABLE ROW LEVEL SECURITY` on `member_notifications` and least-privilege grants in `backend/prisma/staging/runtime-grants.sql`.
- **Idempotent Blocking (`module2.service.ts` & `mock_data.dart`):** Added `ensureBlockedUser` on the backend and `ensureBlockedUserLocally` in Flutter so `BLOCK` actions in message requests and `alsoBlockUser` in reports never toggle off an existing block.
- **Durable PostgreSQL Persistence (`module2.service.ts` & `admin-review.service.ts`):** Removed all 13 process-local persistence maps. Direct message attachments (with ownership, MIME, and 15 MB size validation), `clientMessageId` deduplication, `requestStatus`, `readAt`, `MemberNotification` CRUD, mute/restrict/hide-post lists, and `MemberUserReport` triage (`priority`, `severity`, `assignedReviewerId`, `assignedReviewerName`, `internalNotes`, `appealStatus`, `appealReason`) now read and write directly to PostgreSQL via Prisma.
- **Admin Security & Real Evidence Retrieval (`admin-review.controller.ts`, `admin-review.service.ts`, `ModerationPage.tsx`):** Removed `@Query("token")`, added `<AuthorizedMediaPreview />` using `Authorization` / `x-sakhi-admin-token` headers + `Blob` object URLs, removed the fake placeholder SVG in `previewReportedMedia` (throwing `NotFoundException` when evidence is unavailable), and fixed `deleteWellnessResource` and `deleteAllMenstrualTrackerData` to propagate real database errors.
- **Unified Search & Pagination (`module2.service.ts`):** Enforced `requestedCategory` filtering and `(page, limit)` pagination across all 7 collections (`members`, `businesses`, `products`, `posts`, `topics`, `wellness`, `nearbyPoliceStations`).
- **Date-Based Android Reminder Scheduling (`MainActivity.kt`, `AndroidManifest.xml`, `menstrual_cycle_models.dart`):** Implemented `DiscreetWellnessReminderReceiver` + `AlarmManager.setWindow` for the target `nextPeriodStart - daysBefore` date at 09:00 local time, with `BOOT_COMPLETED` restoration, `POST_NOTIFICATIONS` permission checks, and automatic reschedule on cycle log updates.
- **Automatic vs. Custom Cycle Length Mode (`menstrual_cycle_models.dart`, `menstrual_cycle_tracker_screen.dart`):** Defaulted `useCustomCycleLength` to `false` (Automatic rolling-average mode) and added an explicit **Automatic (History)** vs. **Custom Cycle Length** segmented choice in `MenstrualCycleTrackerScreen`.
- **Honest Synthesized Soundscape Labels & Non-Diagnostic Wellness Copy (`guided_meditation_card.dart`, `MainActivity.kt`, `module2.service.ts`, `menstrual_cycle_models.dart`):** Renamed the 5 synthesized tracks to accurate harmonic descriptions (`432 Hz Warm Harmonic Drone`, `Soft Major-7th Ambient Pad`, `Open-Fifth Gentle Swell Drone`, `Pentatonic Harmonic Fifths`, `Low-Frequency Restorative Hum`) and revised all menstrual health articles to use general wellness comfort phrasing with ACOG/WHO references and medical disclaimers.
- **Render Configuration (`render.yaml`):** Reconciled both service branch declarations with the read-only observed live Render branch `module-8-to-9-implementations-and-upgrades`. Auto-deploy build execution is now schema-neutral; reviewed database migration execution is isolated behind `backend/scripts/staging-migrate-reviewed.sh` and a strict pending-migration preflight.

## 5. Important Architectural Decisions
- **Column-Level Least-Privilege Grant on `direct_messages`:** Rather than granting broad `UPDATE` or `DELETE` on `direct_messages`, runtime database roles receive `GRANT UPDATE ("read_at", "request_status") ON TABLE public.direct_messages`, preserving immutability of message bodies and sender/recipient identities.
- **Header-Authenticated Blob Media Preview in Super-Admin:** Using `fetch` with `x-sakhi-admin-token` and `URL.createObjectURL(blob)` in `ModerationPage.tsx` keeps `<img>` and `<video>` previews working smoothly while ensuring reviewer tokens never appear in URLs, browser history, or server logs.

## 6. Database Schema Modifications
- **`DirectMessage` (`direct_messages`):** `attachment_url`, `attachment_type`, `media_upload_id`, `request_status`, `read_at`, `client_message_id`, unique constraint `direct_messages_sender_client_msg_key` on `(sender_account_id, client_message_id)`, and indexes `direct_messages_recipient_read_idx`, `direct_messages_sender_client_msg_idx`.
- **`MemberNotification` (`member_notifications`):** Full table with unique `member_notifications_idempotency_key` on `idempotency_key`, composite indexes on `(account_id, is_read, created_at)` and `(account_id, category, created_at)`, and `ENABLE ROW LEVEL SECURITY`.
- **`MemberUserReport` (`member_user_reports`):** `reported_account_id`, `updated_at`, `business_id`, `message_id`, `evidence_urls`, `target_snapshot`, `priority` (`DEFAULT 'P2_NORMAL'`), `severity` (`DEFAULT 'S2_MEDIUM'`), `assigned_reviewer_id` (`VARCHAR(64)`), `assigned_reviewer_name` (`VARCHAR(120)`), `internal_notes` (`JSONB DEFAULT '[]'`), `appeal_status` (`VARCHAR(32)`), `appeal_reason` (`VARCHAR(500)`).
- **`MemberPrivacyPreference` (`member_privacy_preferences`):** `muted_handles`, `restricted_handles`, `hidden_post_ids` (`JSONB DEFAULT '[]'`).
- **`MenstrualTrackerPreference` (`menstrual_tracker_preferences`):** `use_custom_cycle_length` (`BOOLEAN NOT NULL DEFAULT false`).

## 7. Migration Files Created or Changed
- `backend/prisma/migrations/20261106010000_modules8_9_10_11_12_complete/migration.sql`
- `backend/prisma/migrations/20261106010000_modules8_9_10_11_12_complete/rollback.sql`
- `backend/prisma/staging/runtime-grants.sql`

## 8. API Changes
- `GET /api/v1/module2/notifications/inbox` now supports `page` and `limit` pagination parameters and returns `{ items, notifications, unreadCount, totalCount, page, limit, hasMore, discreetModeEnabled }`.
- `GET /api/v1/module2/search` filters all 7 collections by `category` and applies `(page, limit)` pagination consistently across every collection, returning both `counts` (page slice) and `totalCounts`.
- `GET /api/v1/admin-review/media/:uploadId/preview` requires header authentication (`x-sakhi-admin-token` / `Authorization: Bearer`) and returns `404 NotFoundException` when evidence is missing.

## 9. Flutter & Android Changes
- Created `app/lib/core/widgets/sakhi_wellness_illustrations.dart` and `app/lib/features/notifications/screens/messages_and_notifications_inbox_screens.dart`.
- Updated `app/lib/core/constants/mock_data.dart` (`ensureBlockedUserLocally` in `respondToMessageRequest` and `reportUserOrPost`).
- Updated `app/lib/features/wellness/models/menstrual_cycle_models.dart` and `app/lib/features/wellness/screens/menstrual_cycle_tracker_screen.dart` (Automatic vs. Custom mode toggle, date-based reminder scheduling hooks, non-diagnostic wellness copy).
- Updated `app/lib/features/wellness/widgets/guided_meditation_card.dart`, `app/android/app/src/main/kotlin/com/example/women_safety_app/MainActivity.kt`, and `app/android/app/src/main/AndroidManifest.xml` (`DiscreetWellnessReminderReceiver`, `AlarmManager` scheduling, honest harmonic drone titles).

## 10. Security Improvements
- Eliminated reviewer bearer tokens from URL query strings.
- Added strict ownership, MIME-type (`image/jpeg`, `image/png`, `image/webp`, `video/mp4`), and 15 MB size validation on direct-message attachments.
- Enabled RLS on `public.member_notifications` and restricted `direct_messages` updates to `("read_at", "request_status")`.

## 11–13. Tests Executed, Results & Skipped Tests
- **Static & Contract Verification Suite (`python3`):** Exit code `0` — Verified zero missing relative imports across `app/lib` and `super-admin/src`, 100% Prisma-to-SQL alignment, removal of all 13 in-memory maps, removal of URL query tokens, and `render.yaml` branch restoration.
- **Runtime Behavioral Test Suite (`node`):** Exit code `0` — 4/4 passed (Idempotent `BLOCK`, Automatic/Custom cycle calculation, Unified search pagination & category filtering, Date-based reminder trigger calculation).
- **Tests Not Executed in Sandbox VM (and Reason):** Full `npm test` (`vitest run`), `npx prisma validate`, and `flutter test` / `flutter build apk` require Node 24.15+ `node_modules` and the Flutter SDK, which are not pre-installed in this offline sandbox VM (`node` is `v18.20.4` with no outbound internet access). Those commands are ready to run directly in your GitHub Codespace where `node_modules` and Flutter are installed.

## 14. Remaining Limitations
- Physical-device audio playback (`FlutterTts` voice synthesis and `AudioTrack` PCM output) and Android `AlarmManager` notification delivery must be verified on a real Android device after building the APK, as unit tests mock the platform channel.

## 15. Actions Deliberately Not Performed
- Did **not** switch to or modify `main`.
- Did **not** execute migrations against your live Supabase database (`sakhi-friend-testing`).
- Did **not** deploy or synchronize `render.yaml` on Render.
- Did **not** commit or push to GitHub.

## 16. Current validation handoff (supersedes the historical manual extraction instructions)

Do not extract an older Gemini ZIP over an existing Codespace checkout or replay the previous manual overlay commands. The reviewed source candidate is already published on the isolated branch `review/sakhi-modules8-12-clean-candidate-20261107`. Run the validation workflows against that branch first. Do not merge into `main`, change Render service branches, or apply the Supabase migration without separate approval.

## 17. Clean review candidate follow-up (2026-11-07)

- The original draft PR #35 and its source branch remain untouched.
- The isolated clean candidate is published as `review/sakhi-modules8-12-clean-candidate-20261107`.
- The candidate cleanup removed line-ending-only churn while preserving genuine source changes; the latest diff is 55 files, 13,059 additions and 2,310 deletions at the time of this report revision.
- Render service branches were inspected read-only; no live service settings were changed.
- Render auto-deploy builds are schema-neutral. `backend/prisma.config.ts` blocks staging schema mutations unless an explicitly approved bootstrap or reviewed migration operation is supplied.
- The reviewed migration wrapper requires the exact Modules 8–12 migration target, a typed approval phrase, a dedicated staging migrator URL, and a preflight proving the full Module 1–7 predecessor chain and pending-migration allowlist.
- Fresh staging bootstrap has a separate explicit approval phrase and records the complete Module 1–7 baseline only.
- No Supabase migration or Render deployment was performed. Full CI for the cleaned candidate is pending the draft validation PR.
