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
