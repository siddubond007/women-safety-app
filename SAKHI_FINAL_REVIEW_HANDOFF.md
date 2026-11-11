# Sakhi Modules 8–12 Reviewed Candidate — Handoff

Review date: 2026-11-07
Clean review branch: `review/sakhi-modules8-12-clean-candidate-20261107`
Parent source snapshot: `aeeb9bf6e3485ebf9b3a590e1fa7e0f33c6bbf52` (the reviewed PR #35 head; PR #35 remains untouched)
Repository: `siddubond007/women-safety-app` (private)
Original implementation branch: `module-8-to-9-implementations-and-upgrades`
Clean review candidate branch: `review/sakhi-modules8-12-clean-candidate-20261107`
Base source snapshot: `main` at `d304f119e62c4be1c7624873f7ce0c5e2a53f2d5`

## Important status

This is a reviewed source candidate and CI build configuration. It is **not an APK** and it is **not approved for production deployment**. No new APK was built inside the review container because it has no Flutter/Dart or Android SDK and the connected Codespace was offline. The cleaned candidate branch is now published on GitHub. Its first complete CI/APK evidence must come from the draft validation PR for this branch. The previously uploaded `Sakhi_Staging_Release_APK.apk` is an older artifact and must not be treated as the Modules 8–12 build.

The isolated clean candidate branch was published to GitHub. PR #35 and its source branch were left untouched. No Render service setting was changed, no Render deployment was started, and no Supabase migration was applied.

## Changes made to this candidate

### Flutter app
- Fixed API client base URL access to use the existing `BackendApiClient` instance.
- Fixed direct-conversation avatar constructor arguments and wired the screen to the existing authenticated `sendDirectMessage()` API.
- Added a distinct conversation load-failure state and retry action; a valid empty conversation remains an empty state rather than a network error.
- Added a gallery image attachment flow for JPG, PNG and WebP, client-side size checking at 15 MB, and a dedicated direct-message upload purpose.
- Fixed the shared API client so `direct_message` is preserved rather than silently converted to `community_post`.
- Ensured picker/upload exceptions restore the send state and display a retryable message.
- Added retry states for the notifications and message-conversation inboxes when API retrieval fails.
- Added shared route-path constants to avoid feature-screen imports of the central route registry and its screen-import cycle.
- Removed the unused Community method/import and fixed the four reported asynchronous `BuildContext` lint findings in Explore.

### Backend and database migration candidate
- Added a database-role-gated RLS policy for `member_notifications`; the policy is explicitly a backend-role boundary, not per-row user isolation. Authenticated account scoping remains the NestJS service's responsibility.
- Added a unique index/schema constraint for `direct_messages.media_upload_id` to enforce single-use message attachments.
- Validated direct-message upload purpose, owner, status, private visibility, MIME type, file size, and single-use semantics before attaching it to a message.
- Kept direct-message media private until linked to a message; media resolution checks the two conversation participants and blocks recipient access while a request is pending.
- Added first-contact Message Request behavior for senders the recipient does not follow and who have not previously had an accepted conversation.
- Added regression tests for message-request state, private attachment access, private upload metadata and single-use uploads.

### Android build and CI
- Removed the hard-coded Android release keystore password and debug-signing fallback. Release builds fail closed unless an explicit keystore and matching properties are provided.
- Kept cleartext traffic disabled in the main/release manifest and isolated the cleartext override to the debug manifest.
- Added `.github/workflows/sakhi-modules8-9-staging-apk.yml`, which validates backend/Admin/Flutter, creates a one-run temporary staging signing key, verifies its APK signature and checksum, uploads a staging-only release APK artifact and a staging-connected debug APK artifact, then deletes temporary signing material.
- The workflow targets `https://sakhi-staging-api.onrender.com/api/v1`; the cleaned candidate is validated through a draft pull request targeting `main`, which triggers the pull-request workflow path. Its CI/APK result is still pending.

## Validation performed here

Passed:
- Original candidate ZIP integrity test (`ZipFile.testzip() == None`).
- The overlay patch applies cleanly to a pristine extraction of the original candidate ZIP (`git apply --check`).
- `git diff --check` with CRLF-aware whitespace handling.
- YAML syntax parse for all YAML/YML files.
- XML parse of main/debug Android manifests.
- Static scan of Dart relative imports: no missing relative imports found.
- Static source-contract checks for the upload-purpose, authenticated message API, participant media checks, single-use schema constraint, fail-closed release signing and staging CI artifact flow.
- TypeScript syntax transpilation for the changed service and three changed test files: no syntax diagnostics.
- Checked the final source tree for `.jks`, `.keystore`, `key.properties` and `.env` files: none found.

Not performed / not claimed:
- `npm ci`, Prisma CLI validation, TypeScript project type-check, Vitest execution, Super Admin lint/build.
- Flutter `pub get`, `flutter analyze`, `flutter test`, Android Gradle build, APK install or signature verification.
- Database migration deployment, Render deployment, live API feature validation, physical-device TTS/AudioTrack/AlarmManager validation.

Reason: the connected Codespace is offline, and this review container lacks Flutter/Dart/Android SDK and project dependencies. The environment Node version is below the backend package's `>=24.15.0` requirement. The CI workflow must provide the first full build/test evidence after the candidate is pushed.

## Remaining product and release gaps

These must not be represented as completed merely because Gemini's repair report listed them:

1. **Quiet hours:** no persisted quiet-hours fields, API contract or time-window enforcement was found in the candidate.
2. **Push delivery:** the persistent in-app notification inbox and category preferences exist, but no Firebase Cloud Messaging/APNs delivery integration or device-token lifecycle was found.
3. **Message security policy:** there is no demonstrated end-to-end encryption. Message retention and moderator-access policy still need a product/security decision. Server-side authorization is not E2E encryption.
4. **Active conversation controls:** the Requests tab exposes Accept/Decline/Block, but the active conversation view does not expose a complete message-level Block/Report control set.
5. **Business enquiries:** the member-to-member flow is present; end-to-end business-owner enquiry inbox behavior requires separate verification.
6. **TTS:** the app uses the device's FlutterTts engine and heuristically selects a voice with English locale/name hints. It is not a hosted or generative AI speaker, and the voice will vary by Android TTS engine and installed voices.
7. **Soundscapes:** Android synthesizes five harmonic AudioTrack presets and rotates them by session. These are generated tones, not recorded music or an AI-generated audio service. Subjective sound quality and device audio-focus behavior need real-device checks.
8. **RLS on existing cycle tables:** the connected Supabase security advisor reported three existing tables with RLS enabled but no policies: `menstrual_cycle_logs`, `menstrual_daily_logs`, and `menstrual_tracker_preferences`. Review row-access policy for the staging runtime before relying on the Module 7 cycle-tracker upgrade.
9. **Message attachment access and message requests:** the code is statically reviewed and regression cases were added, but must pass full backend tests and staging API integration tests before enabling it for testers.

## Current hosted staging state observed read-only

- Supabase project `sakhi-friend-testing` (`wmlpokholjfadyohdlgo`) is `ACTIVE_HEALTHY` in `ap-south-1`.
- At review time, `direct_messages` and `member_notification_preferences` existed, but `member_notifications` did not. The Modules 8–12 migration is therefore not applied to this staging project.
- Supabase migration-list API returned an empty list; rely on schema inspection rather than assuming migration history is recorded there.
- Read-only Render service inspection on 2026-11-07 confirmed `sakhi-staging-api` and `sakhi-staging-admin` both track `module-8-to-9-implementations-and-upgrades`, with auto-deploy enabled and the `checksPass` trigger. The repository `render.yaml` now matches that observed live branch. No live Render setting was changed.
- The clean review candidate branch `review/sakhi-modules8-12-clean-candidate-20261107` is not configured on either live service and must not be deployed until separately approved.
- The Render auto-deploy build command is now schema-neutral: it compiles the backend but does not run Prisma migrations.
- A separate `backend/scripts/staging-migrate-reviewed.sh` command requires the exact explicit approval phrase, the expected migration target, the dedicated staging migrator URL, all predecessor migrations through Module 7, and an exact pending-migration allowlist before `prisma migrate deploy` can run. This command has not been executed.

## Clean candidate validation workflow

The cleaned source is already published on the isolated branch `review/sakhi-modules8-12-clean-candidate-20261107`. Do not extract the ZIP over an existing Codespace checkout or replay the old manual overlay instructions. Validation will be run from the draft PR associated with this exact branch. CI must pass before any staging deployment or migration is considered.

The current branch is not configured on either live Render service. Do not change the Render service branches or apply the Supabase migration without separate approval.


## Clean candidate deployment and migration controls (2026-11-07)

- Render's live API and Admin service branches were read-only verified as `module-8-to-9-implementations-and-upgrades`; `render.yaml` intentionally matches those existing settings. The new review branch is separate and is not configured for deployment.
- `backend/scripts/staging-build.sh` now runs only the application build. Render's automatic build path cannot apply pending Prisma migrations.
- Migration execution is separated into `backend/scripts/staging-migrate-reviewed.sh`. It requires `SAKHI_ENV=staging`, `SAKHI_MIGRATION_TARGET=20261106010000_modules8_9_10_11_12_complete`, `SAKHI_ALLOW_STAGING_MIGRATIONS=YES_APPLY_20261106010000_MODULES8_12`, and `SAKHI_MIGRATOR_DATABASE_URL`.
- Preflight now requires every migration from the original foundation through Modules 5, 6 and 7 (including the intervening RBAC, dedicated-message-storage, runtime-grants, session-metadata and demo-purge migrations) to be recorded as successfully applied. It rejects failed/incomplete ledger rows and any pending migration outside the reviewed Modules 8–12 migration.
- These are repository-side safeguards only. No live Render setting or Supabase schema was changed, and no migration was executed.


---

# Canonical Sakhi Finalization Status — 2026-11-11

> **This is the single canonical status and continuation record for Sakhi finalization.**
> Append future checkpoint updates to this file only. The newest dated section is authoritative; older sections above are historical context and may be superseded.
> Do not generate separate master prompts or duplicate handoff/status documents in ChatGPT. Continue work from this file and the live repository state.

## Current execution checkpoint

- **Stage A:** completed at source-integration and automated backend/admin validation level; not release-ready.
- **Stage B:** completed as a read-only source/security audit. No source, repository documentation, or Git state was changed during Stage B.
- **Stage C:** **NOT STARTED — awaiting explicit user approval.** The proposed scope is source-level remediation and regression testing for the blockers listed below, in the active integration worktree only.
- **Current worktree:** `/workspaces/sakhi-complete-integration-20261111`
- **Branch:** `integration/sakhi-complete-gemini-stage3e-stage4-20261111`
- **HEAD:** `5032e72e2be566013748f53d209310c2cfda4c72`
- **Codespace:** `codespaces-4322a2`, device ID `76acebfa-0e12-4cf5-b9c4-d5295bccb856`; last checked online on 2026-11-11.
- **Git state:** extensive pre-existing staged, unstaged, and untracked work is present. Preserve it exactly. No cleanup, reset, stash, rebase, force-push, or broad checkout operations.

## Stage A — verified results and limitations

Reported completed validations in this integration worktree:

- `git diff --check`: PASS.
- `npx prisma validate`: PASS.
- Prisma Client 7.10.1 generation and NestJS backend production build: PASS.
- Full backend Vitest: 40 files passed, 5 skipped; 234 tests passed, 7 skipped.
- Focused audio/social-wall/complaint suite: 23/23 passed.
- Targeted auth/identity and Modules 8–12 suite after fixture repairs: 15/15 passed.
- Super Admin production build: PASS; non-fatal Vite bundle-size warning (>500 kB).
- Flutter analysis/tests: BLOCKED because Flutter SDK is unavailable in the Codespace.

Stage A fixture repairs:
- Auth fixtures now model the separate member-account lookup after session validation.
- Modules 8–12 notification fixture now models the Prisma recipient-identity callback.

Reviewed Gemini archive `SAKHI_MODULES8-12_FINAL_REVIEWED_SOURCE_20261106.zip` was restored after it was found staged for deletion. Verified SHA-256: `da877c3256298427cd91a6eb51359a4cec4c7d4cc79295c790ebb424d19e33b1`.

### Wellness audio — actual implementation state

- Backend catalogue contains metadata for 42 tracks and five selectable voice-profile presets.
- Backend stream route: `GET /api/v1/module2/wellness/audio-tracks/:trackId/stream`.
- When `SAKHI_WELLNESS_AUDIO_CDN_BASE_URL` is configured, backend fetches the object and validates MIME type, byte size, and SHA-256 before serving.
- Backend in-memory cache: max 6 tracks / 15 MiB / 168 hours (7 days), LRU; process-local and lost on restart/sleep.
- Flutter device cache: max 6 tracks / 15 MiB / 7 days, secure-storage index and local files, restore-time existence/size/SHA checks, and clear-cache action.
- No actual MP3/WAV/M4A track assets were found in the inspected repository/app assets, and no CDN environment variable was configured in the inspected context.
- Without a configured CDN, the backend serves a deterministic 4-second procedural WAV fallback, not the 42 catalogue MP3s and not AI-generated audio.
- Voice previews use device-native Flutter TTS. No server-side Azure Neural TTS endpoint was found; metadata fields are not proof of cloud synthesis.
- No APK-size comparison was run. Exact APK-size savings are unmeasured; caching does not itself reduce APK size.

## Stage B — security and feature audit findings

Targeted audit suite: 11 test files passed, 56 tests passed. `git diff --check`: PASS. No Stage B source or documentation edits were made. Flutter remains unavailable in the Codespace.

### P0 — release blockers

1. The new member RLS migration restricts `member_accounts` to the current member, auth lookup, or admin, while `getDiscover()` queries other members using `memberAccount.findMany()`. Once applied, discovery will not return other members.
2. `member_profiles` has no general verified-member read policy, while application services perform cross-member profile reads. Those reads will be blocked by RLS.
3. **Do not apply this RLS migration** until a safe public/verified profile discovery model is designed and tested. Do not solve this by exposing private member phone/account fields.

### P1 — source-level remediation required

4. Raw SQL interest-search reads `member_profiles` without setting transaction-local member identity; under RLS it fails closed and interest-based discovery is incomplete.
5. Active Circles detail GET creates a circle when absent (read endpoint side effect).
6. Circle moderation checks moderator role for one circle but updates a post by `postId` without verifying that the post belongs to the authorized circle.
7. Circle-post RLS permits author or global content moderators, but does not clearly grant expected circle-owner/moderator access.
8. Flutter Quiet Hours controls update local state only. Backend `PUT notifications/quiet-hours` exists and persists preferences, but the UI does not call it.
9. Push-token field `encryptedToken` stores Base64 data; actual encryption is not demonstrated.
10. No actual FCM/APNs sender integration was found in the inspected backend source/package paths. Token registration does not prove push delivery.
11. Hosted Google Drive upload/retrieval/deletion and actual GitHub Actions retention execution remain unverified.
12. `memberCircleMembership` owner-only RLS may prevent moderator roster queries; align policy with service authorization before release.
13. No PostgreSQL RLS integration suite proves isolation across all member-owned tables. Existing Stage 3D RLS tests cover only three menstrual-tracker tables; database integration tests were skipped/unavailable.

## Additional verified feature facts / limitations

- Direct messages are explicitly not end-to-end encrypted and are stored on the Sakhi server.
- Persistent direct-message logic, attachment ownership checks, message requests, blocking, and reporting exist in source.
- Notifications inbox supports persistent records and read/delete operations.
- Menstrual tracker uses encrypted local storage and backend synchronization; its identity test passed.
- Admin source includes TOTP MFA, persisted signed sessions, rotation/revocation, idle timeout, CSRF, and server-side RBAC; targeted tests passed.
- Google Drive integrity code checks metadata and downloaded-content SHA-256, but current test evidence uses controlled test responses, not a live hosted Drive lifecycle.
- Account deletion deactivates a member, scrubs personal data, and queues external media deletion.
- A protected retention endpoint and GitHub Actions scheduled workflow exist in source; GitHub secrets and live scheduled execution are unverified.
- Codespace shell does not expose environment variables. This does not prove whether Render/GitHub secrets are configured.

## Required Stage C scope (not yet authorized / not started)

If the user approves Stage C, work only in the active integration worktree and first recheck device availability, branch, HEAD, Git status, and running processes. Inspect existing diffs before editing; do not overwrite pre-existing user changes.

Proposed source-level tasks:
1. Redesign safe verified-member/public-profile discovery so member RLS protects private account data while authorized discovery works.
2. Correct raw SQL request-identity context for interest search.
3. Make Circles detail GET read-only; enforce circle/post ownership consistency in moderation; align circle moderator RLS with service authorization.
4. Wire Quiet Hours UI to the existing backend persistence API, including load/error/retry behavior and regression tests.
5. Determine a real encryption design for push tokens and verify provider delivery capability; do not claim FCM/APNs delivery unless implemented and tested.
6. Add focused tests, then rerun targeted and full backend/admin validation where feasible.

Stop after Stage C and request approval before proceeding to another stage.

## Non-negotiable execution and safety controls

- Preserve every existing worktree, branch, dirty state, untracked file, checkpoint, recovery file, and archive. Do not reset, clean, stash, rebase, force-push, or overwrite.
- Keep work isolated in the named integration worktree. Leave `main` untouched unless separately authorized.
- No commits, pushes, merges, deployments, live database mutations, migration application, signing-key operations, or APK build/install unless the user explicitly authorizes that exact operation.
- Use synthetic test data only. Never use real member data for validation.
- Do not expose signing credentials or private keys. Historical tracked release-signing material remains a security concern and requires a separately approved remediation plan.
- Use hosted/cloud workspaces where possible and maintain the strict $0/₹0 constraint. Do not enable paid services, paid tiers, or usage that could incur charges.
- Do not install or launch an emulator. The user will manually test an APK on a physical device when an APK is explicitly authorized and ready.
- Report evidence precisely as **VERIFIED**, **REPORTED**, **INFERRED**, or **BLOCKED / NOT VERIFIED**. Never present source presence or mocked tests as live hosted proof.
- For long-running tasks: start once, record PID, exact command, working directory, start time, and log path; if still running, ask the user to reply `CHECK`. Never relaunch a task merely because a tool call timed out; inspect the original process first.
- After every major stage, stop and request explicit permission before beginning the next stage.
- This file is the only canonical status/continuation record. Update this file at each completed checkpoint; do not create duplicate status or master-prompt files. Keep user-facing chat updates concise and do not reproduce the full master prompt in chat.

## Next required decision

**Await explicit approval to begin Stage C.** Until approval is received, do not modify source code or begin Stage C remediation.
