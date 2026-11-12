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

---

## Read-only hosted readiness audit — 2026-11-11 (Render + Supabase)

This checkpoint records a read-only inspection authorized by the user. No Render settings, environment variables, deployments, database schema, rows, or Git branches were changed.

### Render workspace and service deployment state — VERIFIED

Workspace: CHAKRAVARTHI CHANDRA SIDDHARTH's workspace (tea-dbc5ku0n74is73ffj1n0).

- sakhi-staging-api (srv-dbc5s4dg1s2s7395oed0): active, not suspended, Render Free plan, Singapore, one instance, automatic deploy enabled with checks-pass trigger. Live branch is feat/stage3e-account-deletion-complaint-evidence-20261110. Latest live deployment is dep-dbptt4p5efls73921jg0, commit a104946b8a57189e421e0f4211cb269f87f7063a (ci(stage3e): test backend and gate staging deploy), succeeded 2026-11-11 03:20 UTC.
- sakhi-staging-admin (srv-dbc8upqfngtc739e8u0g): active static site, automatic deploy enabled with checks-pass trigger. Live branch is module-8-to-9-implementations-and-upgrades. Latest live deployment is dep-dbn9983rjlhs73841pmg, commit 72270e0d37a096ee3e3fbdb843c600cfc6afb3ae (chore(render): target reviewed staging branch after CI checks), succeeded 2026-11-07 03:03 UTC.
- Neither live service deploys the current integration branch integration/sakhi-complete-gemini-stage3e-stage4-20261111. API and Admin are on different source branches/commits.
- API health endpoint /api/v1/health/ready and liveness endpoint returned HTTP 200. Readiness response reported database ok.
- Admin root and /login returned HTTP 200, but hosted HTML metadata describes the product as Private Sakhi administration console — demo UI only. Static site returned a page; this is not proof of full live Admin/backend integration.
- Recent API logs primarily show successful Render health-check requests. No recent Admin logs were returned in the inspected window.
- Render service detail responses did not expose protected environment-variable values or a complete variable-presence inventory. Secret/configuration readiness therefore remains NOT VERIFIED. No secret values were requested or displayed.
- Repository render.yaml in this integration worktree declares the older Modules 8–9 branch for both services, while live Render currently has API on Stage 3E and Admin on Modules 8–9. This source-vs-live configuration drift must be reconciled deliberately before a deployment change.

### Supabase live database — VERIFIED

Project: sakhi-friend-testing (wmlpokholjfadyohdlgo), region ap-south-1, PostgreSQL 17.11, status ACTIVE_HEALTHY.

- Live database accepts queries; API readiness endpoint also confirms its database dependency is reachable.
- Public schema has 50 ordinary tables. Only 4 have RLS enabled; 46 do not.
- RLS-enabled tables are member_notifications and the three menstrual tracker tables (menstrual_cycle_logs, menstrual_daily_logs, menstrual_tracker_preferences). The three menstrual tracker tables have forced RLS. Most other member-owned/sensitive tables remain without RLS, including member_accounts, member_profiles, direct_messages, discreet_complaints, emergency/safety tables, eligibility tables, admin accounts and audit events.
- The live migration ledger contains six entries: Stage 3D member-level menstrual RLS, Stage 3E account deletion, Stage 3E runtime grants/migration reconciliation, transfer of deletion-request table to migrator, synthetic evidence-retention test fixture, and enabling pg_cron/HTTP for Stage 3E. It does not show the current integration worktree's later broad member-owned-data RLS migration as applied.
- Supabase Storage currently has no buckets and no storage policies. This does not rule out external Google Drive storage, but Supabase Storage is not configured for Sakhi media in this project.
- Security advisor had returned no lints in the earlier inspection, but this does not override direct table-level RLS findings.

### Scheduler and retention — VERIFIED

- One active pg_cron job exists, scheduled every five minutes. Its command calls only https://sakhi-staging-api.onrender.com/api/v1/health/ready.
- The latest recorded cron runs succeeded. This is a health-check/keep-warm job, not the complaint-evidence retention worker.
- No live database cron job for complaint retention was found. Actual GitHub Actions retention execution and required secret configuration remain NOT VERIFIED.
- The current source contains a retention workflow and protected endpoint, but source presence is not proof of hosted scheduling or actual evidence deletion.

### Release-readiness decision

NOT PRODUCTION READY / NOT READY FOR REAL MEMBER DATA. The backend and database are reachable, but these are service-availability checks, not end-to-end acceptance.

Confirmed blockers/gaps:
1. Member-data RLS is absent from 46 of 50 public tables. Do not apply the pending broad RLS migration blindly: prior Stage B audit found that it conflicts with cross-member discovery/profile reads and must be redesigned and integration-tested first.
2. The Admin Panel deployment is stale (Nov 7) and runs from a different branch than the API. Its hosted HTML identifies itself as demo UI only. Full admin login, MFA session, RBAC, page data and API integration are NOT VERIFIED.
3. Current integration branch is not deployed to either Render service.
4. Durable evidence-retention scheduling is not configured in the observed Supabase cron; the existing job only checks API health.
5. Google Drive credentials/configuration and real upload/retrieve/checksum/delete lifecycle are NOT VERIFIED from protected host configuration or a live synthetic end-to-end test.
6. Render protected environment-variable presence/values could not be verified via the read-only service metadata response. Do not infer missing secrets solely from this limitation.
7. Supabase Storage has no configured buckets; external Google Drive may be the intended storage path and needs separate live verification.

### Safety and execution

- Inspection was read-only. No database mutation, migration, deployment, environment update, secret disclosure, Git checkout, commit, push, or merge was performed.
- Existing dirty/staged/untracked integration work remains preserved.
- Next work must be separately approved and staged: (1) source-level security/feature remediation; (2) integration and PostgreSQL RLS tests; (3) reconcile deployment branch/configuration; (4) verify protected environment configuration without exposing secrets; (5) synthetic hosted end-to-end Admin, member, Drive and retention tests; (6) only then request deployment/migration approval.


## Stage C — micro-step 1: discovery and member-data RLS design review (2026-11-11)

### Execution checkpoint

- Codespace `codespaces-4322a2` reconnected and the original integration worktree was verified at `/workspaces/sakhi-complete-integration-20261111`.
- Branch: `integration/sakhi-complete-gemini-stage3e-stage4-20261111`.
- HEAD at review: `0dd89748da1f6b9762520ed07f12228238a3c324`.
- The earlier status-file update commit is already present at this HEAD; the previous attempted commit was correctly stopped because its expected HEAD was stale. No duplicate commit was made.
- Worktree inventory at this checkpoint: 67 staged paths, 27 unstaged paths, and 7 untracked paths. These are pre-existing integration/reconciliation changes and are intentionally preserved. Do not reset, clean, stash, checkout, rebase, or overwrite them.
- No source code, migration, database, deployment, secret, or signing-key change was made during this micro-step. This was a read-only design review plus this handoff update.

### Confirmed source findings

1. `backend/src/module2/module2.service.ts:getDiscover()` currently queries `memberAccount.findMany()` and returns `{ items }` directly. It does not use an explicit safe projection. The current `MemberAccount` model contains phone number and verification/account metadata, so returning raw account rows is not an acceptable public discovery contract.
2. The same discovery method refers to legacy `privacySettings`, `appearInSearch`, `profileVisibility`, `locationSharing`, and `profile.locationCity` fields. These names are not present in the current `backend/prisma/schema.prisma` models inspected in this review. Current `MemberPrivacyPreference` instead defines `viewProfile`, `searchResults`, `showLocation`, and related preferences; `MemberProfile` has `location`, not `locationCity`. This is source/schema drift, not a proven live database defect.
3. The existing discovery unit tests in `backend/test/module2.service.spec.ts` assert the legacy privacy-field query shape. They need to be replaced with tests for the actual schema and intended privacy semantics; simply changing production code without updating these tests would leave misleading coverage.
4. Member search in `module2.service.ts` reads `memberProfile` and includes related account fields. The request identity context is bound automatically by the Prisma delegate wrapper only when the query passes through that wrapper. Raw SQL paths do not inherit the Prisma delegate identity automatically and require explicit transaction-local identity handling.
5. The pending migration `backend/prisma/migrations/20261111190000_member_owned_data_rls/migration.sql` enables and forces RLS on `member_profiles` with an owner/admin-only policy plus a username-availability exception. That policy prevents ordinary cross-member discovery/profile reads. Its `member_accounts` policy also allows only self, explicit auth lookup, or designated admin reads; broad account relation reads for other members would be filtered.
6. RLS policies filter rows, not columns. A blanket cross-member SELECT policy on `member_profiles` or `member_accounts` would risk exposing private profile/account fields because the models include sensitive values (including date of birth, email, and phone number). Do not solve discovery by broadly allowing cross-member row access.
7. `getMemberProfileOverview()` currently reads a target profile with `include: { account: true }`, then applies some visibility/block logic in application code. Under the proposed account RLS this relation read will not be available for other members. Privacy checks must happen before sensitive related data is fetched or returned.

### Design decision / safe direction

- Do not apply the broad member-owned-data RLS migration to Supabase or any shared database.
- Do not add a permissive cross-member policy to `member_accounts` or `member_profiles` as a shortcut.
- First define a minimal public-profile projection containing only explicitly approved fields, with privacy/search/follower/block rules evaluated before returning a result.
- Evaluate an isolated public-directory projection or a tightly controlled database function as the cross-member read boundary. Any database function must have a fixed safe `search_path`, narrowly scoped execute grants, explicit return columns, and tests under the actual non-owner runtime role. A public projection must not expose phone, email, DOB, account status internals, security flags, or other private attributes.
- Align discovery, member search, profile overview, follow checks, and their tests to the current Prisma schema and one documented privacy model before revising RLS policies.
- Add real PostgreSQL integration tests using the dedicated non-owner runtime role. Prove self access, authorized public-profile projection, hidden/search-opt-out behavior, follower-only behavior, blocked-member behavior, cross-account denial for private tables, and absence of connection-pool identity leakage.

### Validation and status

- Read-only source inspection completed for the migration, Prisma schema, request identity context, Prisma identity wrapper, discovery/search methods, profile overview, and existing discovery tests.
- No code patch or migration edit has been made. No PostgreSQL integration test was run in this micro-step.
- Stage C is IN PROGRESS; this micro-step is DESIGN REVIEW COMPLETE, IMPLEMENTATION NOT STARTED.
- Live hosted readiness remains NOT PRODUCTION READY / NOT READY FOR REAL MEMBER DATA for the blockers recorded in the preceding hosted audit.

### Next micro-step (not yet executed)

Prepare the public-profile data contract and query-boundary design, inventory every cross-member consumer of `member_profiles`, `member_accounts`, `member_privacy_preferences`, and `community_directory_profiles`, then propose the smallest compatible source change and tests. Stop for review before any migration application, shared-database mutation, deployment, or credential operation.


## Stage C and Stage D remediation checkpoint — 2026-11-11 (latest; supersedes the earlier “implementation not started” note above)

### Execution boundary and repository preservation

- Worktree: `/workspaces/sakhi-complete-integration-20261111`.
- Branch: `integration/sakhi-complete-gemini-stage3e-stage4-20261111`.
- HEAD remains `0dd89748da1f6b9762520ed07f12228238a3c324`; no commit, push, merge, checkout, reset, rebase, or main-branch change was performed.
- Final Git status inventory: 67 staged entries, 31 unstaged entries (19 paths have both staged and unstaged changes), and 12 untracked entries. Existing work was preserved; no attempt was made to stage, clean, stash, or overwrite unrelated paths.
- Only the canonical `SAKHI_FINAL_REVIEW_HANDOFF.md` was updated for this status record. The handoff remains uncommitted and unpushed.
- No Supabase/shared database migration, Render deployment, environment change, secret operation, APK build, or signing-key operation was performed.
- A temporary Docker PostgreSQL 17 container named `sakhi-cd-rls-postgres` was used only for synthetic integration testing and was stopped after verification. It was not a Supabase or Render database.

### Stage C — public-profile and discovery boundary

Implemented in the integration worktree:

1. Extended `CommunityDirectoryProfile` into an explicit public projection with `accountId`, `searchable`, `profileVisibility`, `postsVisibility`, and `messageVisibility`. The projection contains display name, username, avatar reference and short bio; it deliberately excludes phone, email, date of birth, account/security metadata and precise location.
2. Added `syncCommunityDirectoryProjection()` and wired it to member bootstrap, profile update, and privacy-preference update paths. It synchronizes search opt-out, profile visibility, post visibility, message visibility, active status and verified status into the projection.
3. Replaced `getDiscover()` and `searchMembers()` cross-member reads of `member_accounts`/`member_profiles` with the RLS-filtered public directory projection and explicit safe selects.
4. Reworked `getMemberProfileOverview()` and the legacy `getMemberProfile()` compatibility method to resolve cross-member profile data through the public projection rather than unrestricted account/profile relation includes. The overview does not expose location for other members; connection counts and reverse-follow state are returned as unavailable (`null`/`connectionCountsAvailable=false`) rather than fabricated.
5. Added `blockedAccountId` to `MemberModerationBlock`, a narrow incoming-block read policy, backfill for block handles that match a linked directory profile, and a directory RLS predicate to hide a profile from a member it has blocked. New block records resolve the target account ID when a visible directory entry exists.
6. Changed follower-list and other-member connection-list behavior to fail closed under owner-scoped `member_follows` RLS. `listFollowers(mode="followers")` returns an empty result with `connectionsAvailable=false`; `listMemberConnections()` no longer falls back to the viewer's own list when another member's list cannot be read. The viewer's own following list is served from safe directory projections.
7. Discovery/search tests were rewritten to assert the projection contract and absence of private-field queries. Tests also assert that follower/connection APIs fail closed rather than reading another member's account/profile rows.

Stage C status: **CORE PUBLIC-PROFILE SECURITY BOUNDARY IMPLEMENTED; FULL FEATURE ACCEPTANCE STILL OPEN.** The following consumer limitations are deliberate and must not be described as fully implemented features:

- Cross-member follower lists and other-member connection lists remain unavailable until a dedicated privacy-aware relationship projection is designed and tested.
- `listNearbyCircles()` still uses an owner-scoped cross-member profile query; RLS filters those rows, so nearby-member suggestions fail closed rather than revealing member data. No location field was added to the public projection.
- Profile overview connection counts and reverse-follow state are unavailable rather than guessed.
- Legacy moderation-block records that cannot be linked to a directory account ID cannot be evaluated by the incoming-block RLS predicate until a safe account-resolution path is added.
- Flutter/UI compatibility for these changed response shapes was not tested in this Codespace.

### Stage D — member-data and confidential-table RLS

Added/updated migrations in this worktree:

- `20261111190000_member_owned_data_rls`
- `20261111200000_public_directory_profile_rls`
- `20261111210000_member_block_target_visibility`
- `20261111220000_member_auxiliary_rls`
- `20261111230000_confidential_backend_only_rls`

The Stage D migration work:

1. Enables and forces RLS on the 32 member-owned tables covered by the broad migration, retaining owner/admin policies and transaction-local request identity checks.
2. Enables and forces RLS on the public directory projection, with verified-member, search opt-out, follower-only and incoming-block rules.
3. Enables and forces RLS on eligibility consent, eligibility support request, eligibility verification session, audit event and moderation decision records.
4. Forces RLS on admin staff/session/MFA/backup-code/recovery tables and the legacy admin auth session table.
5. Enables and forces backend-role-only RLS on `discreet_complaints` and `eligibility_provider_callback_events`. This is intentionally a backend-only boundary, not per-member row isolation: complaint passkey verification and provider callback signature verification remain application/service authorization requirements.
6. Aligns the existing `sakhi_dev_app` table/sequence grants to `sakhi_test_app` and `sakhi_staging_app` so the three non-owner runtime roles can execute the intended queries while RLS independently filters rows. This was discovered as a real issue during the fresh-database test: before the grant correction, test/staging roles had RLS policies but lacked table privileges.

Fresh isolated PostgreSQL 17 verification:

- All **31** Prisma migrations applied successfully to a newly created isolated database with the three runtime roles provisioned before migration execution.
- Catalog verification: **49 public tables have RLS enabled and forced**; 9 remaining public tables are configuration/reference/catalogue tables without RLS: `complaint_category_configs`, `complaint_retention_policies`, `feed_category_configs`, `platform_config_settings`, `platform_registration_policies`, `policy_document_versions`, `safety_helpline_configs`, `verified_police_stations`, and `wellness_resources`. These tables still require ordinary grant/API authorization review; their exclusion is not a blanket claim that they are harmless.
- `sakhi_dev_app`, `sakhi_test_app`, and `sakhi_staging_app` all verified as `NOSUPERUSER` and `NOBYPASSRLS`; all three had the required `member_accounts` SELECT privilege after the grant migration.
- New integration suite: `backend/test/integration/stage5-member-rls.integration.spec.ts`. It uses separate migrator/admin and non-owner app connections, synthetic account A/B records, and tests cross-account row isolation for member roots and eligibility records, public/follower-only/hidden/incoming-block directory visibility, forced-RLS catalog coverage, transaction-local identity reset, and member audit insert without member audit read.
- Stage 5 PostgreSQL integration tests: **4/4 passed** using `sakhi_test_app` as the non-owner runtime role.
- The temporary PostgreSQL container was stopped after the tests; no synthetic fixture data was written to Supabase or another shared database.

### Final code validation

- `npx prisma validate`: PASS.
- `npx prisma generate`: PASS (Prisma Client 7.10.1).
- Backend production build (`npm run build`): PASS.
- Full backend Vitest suite, with the Stage 5 PostgreSQL integration connection variables set: **41 test files passed, 5 skipped; 239 tests passed, 7 skipped**.
- `git diff --check`: PASS.
- Flutter analyze/tests and UI contract tests were not run in this Codespace.

### Acceptance decision and stop point

- Stage C: core discovery/search/profile reads now use a safe RLS-filtered public projection. Social relationship and nearby-member consumers remain deliberately fail-closed; therefore Stage C is **not fully feature-accepted**.
- Stage D: the source migrations and isolated PostgreSQL RLS behavior are validated locally. Hosted Supabase migration application and actual hosted runtime-role verification were not authorized and were not performed; therefore Stage D is **source/local verification complete, hosted acceptance pending**.
- Overall Sakhi verdict remains **NOT PRODUCTION READY / NOT READY FOR REAL MEMBER DATA**. Do not point the real app at a database until the C consumer limitations are resolved, the migration set receives review, and the migrations are applied/tested on a protected staging database under the actual Render runtime role.
- The user requested that work stop after Stages C and D. No Stage E or later work was started. Resume only from this exact worktree/branch/HEAD and the current dirty state; do not commit or push without a new explicit instruction.


## Stage E — synthetic evidence lifecycle and account-erasure verification (2026-11-12; IN PROGRESS / BLOCKED AT HOSTED WRITE GATE)

### Scope and preservation

- User explicitly resumed work after the Stage C/D stop and authorized proceeding with Stage E only. Do not begin Stage F or later without a new approval.
- Worktree remains `/workspaces/sakhi-complete-integration-20261111`, branch `integration/sakhi-complete-gemini-stage3e-stage4-20261111`, HEAD `0dd89748da1f6b9762520ed07f12228238a3c324`.
- No commit, push, merge, checkout, reset, rebase, cleanup, stash, deployment, migration application, secret operation, or signing-key operation was performed. Existing dirty/staged/untracked work remains preserved.
- Canonical handoff only; this update is uncommitted and unpushed.

### Hosted staging preflight — VERIFIED (read-only except the isolated Drive test upload noted below)

- Render service `sakhi-staging-api` remains on branch `feat/stage3e-account-deletion-complaint-evidence-20261110`, not the current C/D integration branch; API health returned HTTP 200 with database `ok`.
- Staging Google Drive status reports configured and connected. `?verify=true` completed successfully and verified the Sakhi Staging Media root folder. No OAuth token or secret value was retrieved or displayed.
- Supabase project `sakhi-friend-testing` is ACTIVE_HEALTHY, PostgreSQL 17.11. Read-only schema inspection confirmed `account_deletion_requests`, `media_assets`, `discreet_complaints`, and `audit_events` include the fields expected by the deployed Stage 3E service.
- Read-only query found 0 account-deletion requests (0 pending, 0 total) before any Stage E account test.
- Supabase `cron.job` contains only one active `*/5 * * * *` health-check request to `/api/v1/health/ready`; it does not invoke retention. Render request logs contained no `/internal/retention/run` calls in the inspected 2026-11-05 through 2026-11-12 window. The GitHub Actions workflow file exists and schedules a daily run, but actual workflow run history/secret presence is not verified.

### Local Stage E test validation — PASS

- `backend/test/google-drive-storage.integrity.spec.ts`: 3/3 passed.
- `backend/test/module2.account-deletion.spec.ts`: 1/1 passed.
- `backend/test/complaint-evidence-retention.worker.spec.ts`: 4/4 passed.
- Combined: 3 test files passed; 8 tests passed. These are mocked/unit tests, not proof of live staging account erasure or worker execution.

### Live synthetic Google Drive upload — VERIFIED; cleanup pending

- A 68-byte synthetic 1x1 PNG was uploaded through the staging evidence-upload endpoint. The API returned a synthetic evidence ID, Drive file ID, byte size, and SHA-256 receipt. The object is in the staging Drive folder; no real-person file/data was used.
- The subsequent hosted synthetic anonymous complaint submission (needed to exercise server-side Drive byte retrieval/checksum verification and obtain the complaint passkey for purge) was stopped by the Desktop Commander client safety gate twice. The exact unchanged request is now shown to the user in the review panel and awaits the user's Run action. No complaint POST has been confirmed, and the uploaded Drive object is not yet linked to a complaint; it must be purged as part of resuming this test.
- Do not retry the blocked request or create a duplicate upload. If the user approves the displayed Run action, inspect its result, then continue with retrieval/checksum validation, immediate synthetic complaint evidence purge, and independent verification that the Drive object is gone and DB metadata is marked purged.

### Account deletion and worker execution — NOT YET VERIFIED

- No synthetic member account has been created or deleted in staging. No account-deletion request row was inserted.
- No hosted retention endpoint was invoked. No GitHub Actions workflow dispatch was available through the connected GitHub toolset; existing schedule presence is not proof of execution.
- Durable scheduling remains unproven: the observed Supabase cron is health-only, and the GitHub Actions workflow's actual successful run and secret configuration remain unverified.
- No shared DB writes beyond the pending safety-gated request (none executed), no staging migration, and no Render configuration/deployment changes were made.

### Current Stage E decision / next action

Stage E is **IN PROGRESS — NOT ACCEPTED**. Local mocked tests pass and staging Drive connectivity is verified, but live evidence retrieval/checksum/deletion, synthetic account deletion, retention-worker execution, and durable scheduling have not been proven. Resume from the existing safety review panel for the one pending synthetic complaint request; do not relaunch it or create a second upload. After completing cleanup and evidence verification, proceed only within Stage E and stop for approval before Stage F.


### Stage E continuation — hosted retrieval/checksum verified; purge awaiting review (2026-11-12)

- The previously approved synthetic anonymous complaint submission succeeded: `#SKH-ANON-2026-1430`, status `SUBMITTED`, priority `P1_URGENT`. Passkey retained only in the Codespace temporary test file; never copy it into this handoff or logs.
- The complaint tracking endpoint was called with the saved synthetic passkey. It returned the exact evidence metadata from the persisted complaint (68 bytes, Drive file ID, evidence ID, SHA-256 `9f458d23ceec6aba799461a7190a2b51c5c3cf62aeee1ce0800c77e076401fca`). This confirms the server-side submission accepted the file only after `verifyComplaintEvidenceFile()` completed its Drive metadata check, actual content download and SHA-256/byte-length comparison. Evidence retrieval/checksum path: VERIFIED.
- Reporter-requested purge was prepared using the complaint's saved passkey, but the Desktop Commander safety gate stopped execution and displayed the exact call in the review panel. No purge request has yet been confirmed. Do not duplicate or retry; user must click Run on the displayed review call.
- After approved purge, verify `mediaPurgedAt`, `isPurged=true`, byteSize=0, and the purge audit event via tracking endpoint; then independently query Google Drive metadata to verify the exact Drive file is trashed/deleted. Only then continue to isolated synthetic account deletion and retention-worker/durable scheduler proof.


### Stage E continuation — reporter purge completed; hosted persistence verified (2026-11-12)

- User approved and ran the exact pending Desktop Commander operation (PID 9350). The staging API returned `purged: true`; complaint `#SKH-ANON-2026-1430` now has `mediaPurgedAt=2026-11-12T05:55:47.228Z`, `evidenceFiles[0].isPurged=true`, and `byteSize=0`. The filename is marked `[PURGED_BY_REPORTER_…]`; audit history contains `complaint.media.purged_by_reporter`. The complaint itself remains SUBMITTED.
- Independent read-only Supabase query confirmed the persisted `discreet_complaints` row has the same purge timestamp and evidence metadata. `audit_events` contains the corresponding `module5.complaint.snapshot` row with outcome `purge_media:PURGED` and the submission snapshot. No matching row exists in `media_assets`; complaint evidence is represented in the complaint's JSONB `evidence_files` field.
- Drive deletion is **API-confirmed, not independently re-read after deletion**: the reporter purge returned success, and source inspection shows `deleteComplaintEvidence()` first GETs and validates the exact Drive object/appProperties/size/digest, then issues Drive API DELETE and throws on a non-404 failure. The successful purge response therefore indicates that the server-side delete method completed without error. No separate post-delete Google Drive metadata GET was available through the exposed tools, so do not describe this as an independently verified Drive 404.
- Residual metadata note: the purged JSONB evidence entry still retains the Drive file ID, folder ID and SHA-256 digest while setting `isPurged=true` and `byteSize=0`. This is not file-content retention, but it is a retained storage reference/integrity identifier and should receive a privacy/data-minimization review before production acceptance.
- Current read-only Supabase counts: `account_deletion_requests` total=0, pending=0; due complaint-retention rows=0. These are point-in-time counts only.

### Stage E continuation — account deletion, retention worker and scheduler remain blocked

- No synthetic member account was created, no account-deletion request was submitted, and no member/account data was erased. The member-facing deletion operation requires an authenticated member session and immediately performs broad relational scrubbing/deactivation before the external-media worker completes. A valid isolated synthetic member/session is not presently available; do not fabricate a token or write directly into shared member tables to bypass the flow.
- The worker source confirms `runOnce()` selects all staging complaints in terminal states with expired retention deadlines and `runAccountDeletionOnce()` selects all REQUESTED/PROCESSING account-deletion rows. The protected `POST /internal/retention/run` invokes both global sweeps. Although the read-only snapshot currently showed zero due complaint rows and zero deletion requests, invoking the global endpoint could race with or process other staging records; it was not invoked without a safe per-synthetic-record scope and verified scheduler credential.
- The source workflow `.github/workflows/sakhi-staging-retention.yml` schedules daily at `37 2 * * *` UTC and requires GitHub secrets `SAKHI_STAGING_API_BASE_URL` and `SAKHI_EVIDENCE_RETENTION_CRON_TOKEN`. The endpoint additionally requires staging/production flags and a bearer token of at least 32 characters. The workflow file's existence is verified; actual successful workflow run history and secret configuration remain unverified. GitHub workflow-run retrieval was unavailable through the connected read-only GitHub action.
- The worker deliberately does not start its 15-minute in-process timer when `NODE_ENV=production`; production/staging expects the external scheduler. Supabase cron remains health-check-only. Durable scheduler execution is therefore **NOT VERIFIED**.
- No account deletion was attempted; no retention endpoint was called; no GitHub workflow was dispatched; no deployment, migration, secret read/change, or database write was performed beyond the approved synthetic complaint lifecycle operation.

### Stage E final acceptance decision / stop point

- **Evidence upload + server-side retrieval/checksum verification:** VERIFIED.
- **Reporter-requested purge + persisted complaint metadata/audit snapshot:** VERIFIED.
- **Google Drive physical deletion:** API-confirmed by successful validated delete path; independent post-delete metadata read NOT AVAILABLE.
- **Synthetic account deletion end-to-end:** BLOCKED — no isolated synthetic authenticated member/session.
- **Retention worker live execution:** BLOCKED — global worker has no synthetic-only scope; no execution attempted.
- **Durable scheduler actual run:** NOT VERIFIED — workflow and schedule definition exist, but run history/secrets were not confirmed.
- Stage E remains **NOT ACCEPTED / INCOMPLETE**. Stop here and request explicit approval before any Stage F work. Overall Sakhi remains **NOT PRODUCTION READY / NOT READY FOR REAL MEMBER DATA**.
- Worktree, branch and HEAD remain unchanged: `/workspaces/sakhi-complete-integration-20261111`, `integration/sakhi-complete-gemini-stage3e-stage4-20261111`, `0dd89748da1f6b9762520ed07f12228238a3c324`. This canonical handoff update is uncommitted and unpushed. No other worktree or branch was modified.


### Stage E continuation — staging synthetic-account bootstrap review (2026-11-12)

- Inspected the deployed-source staging test-admin controller/service and auth registration flow. Staging test-admin exposes account listing and privileged test-access approve/revoke for existing registered members; it has no synthetic-member creation or member-session issuance endpoint.
- The standard member registration path is `POST /auth/otp/request` → `POST /auth/otp/verify` → `POST /auth/profile`. Staging test mode requires a configured phone allowlist, fixed shared six-digit OTP, staging flags and configured minimum age. The shared OTP intentionally does not prove phone ownership; no OTP value or allowlist entry was read or exposed.
- A random or guessed phone number is not a safe synthetic identifier because it may belong to a real person. The 15 existing active member accounts were not inspected individually, selected, approved, or modified. No OTP challenge, account, profile, session, or deletion request was created.
- Current read-only Supabase counts at this inspection: 15 member accounts, 15 ACTIVE, 0 deletion-scrubbed accounts, 0 deletion requests, and 0 unconsumed/unexpired OTP challenges. Counts only; no individual member fields were queried.
- Decision: **synthetic account deletion remains BLOCKED** until a dedicated staging-only synthetic account fixture/bootstrap mechanism exists, or the operator supplies an explicitly designated test identity/phone number that is known to be controlled and disposable. Do not use an arbitrary phone, any of the 15 existing accounts, or direct SQL inserts to bypass authentication.
- Retention worker remains unsafe to invoke globally for the same reason established above: `POST /internal/retention/run` invokes both global due-complaint and pending-account-deletion sweeps, with no per-record allowlist/target parameter. Current zero counts are only a point-in-time snapshot and do not eliminate a race with new staging records.
- No source code, staging configuration, Render service, Supabase data, GitHub workflow or secrets were changed in this continuation.


### Stage E continuation — isolated synthetic fixture and targeted retention path implemented (source-only; 2026-11-12)

#### Synthetic member fixture bootstrap

- Added `POST /api/v1/staging-test-admin/synthetic-fixtures/member` under the existing MFA-protected staging test-admin controller.
- Creation requires an authenticated individual staff session, `SUPER_ADMIN` role, `approve` permission, explicit `acknowledgedTestOnly=true`, a non-sensitive reason, staging/production environment checks, and `SAKHI_SYNTHETIC_FIXTURE_ENABLED=true`.
- The feature flag is documented as `false` by default in `backend/.env.example`; no Render setting was changed.
- The fixture uses a generated `+999` synthetic-only phone namespace, an `example.invalid` email, a clearly synthetic display name, no phone verification, and `UNVERIFIED` eligibility. No SMS or OTP is requested.
- A random bearer session is generated and only its SHA-256 digest is persisted. The returned bearer credential is intended only for the controlled deletion test; session lifetime is one hour. The fixture audit marker records `testOnly=true`, `syntheticFixture=true`, fixture/account IDs and a 24-hour fixture expiry. No credential value is written to the handoff or logs.
- The fixture creation and member/profile/session/audit rows are written in one transaction. No hosted invocation was made.

#### Targeted synthetic account-retention path

- Extended `runAccountDeletionOnce(syntheticFixtureId?)`. When a fixture ID is supplied, the worker requires a matching `staging.synthetic_member.created` audit marker, verifies its test-only/synthetic flags, exact fixture ID and unexpired timestamp, then verifies that the marked member account is already `DELETED`.
- Only after those checks does the worker query pending deletion requests with the exact marked `accountId`; it cannot broaden the query to other member accounts in targeted mode.
- Added `POST /api/v1/internal/retention/synthetic/:fixtureId/run`. It requires the same staging production gate and timing-safe bearer cron credential as the scheduled worker, plus `SAKHI_SYNTHETIC_FIXTURE_ENABLED=true`. It calls only the targeted account-deletion worker and deliberately does not invoke the global complaint evidence sweep.
- The existing global `POST /api/v1/internal/retention/run` remains unchanged in behavior for the scheduled global sweep. No global endpoint was called during this source implementation.
- This targeted path is for account-deletion media completion. It does not yet provide a targeted synthetic complaint-evidence retention fixture or change the global complaint retention query.

#### Validation — VERIFIED locally

- Backend production build: PASS.
- Full backend Vitest suite: **40 files passed, 6 skipped; 239 tests passed, 11 skipped**.
- New/updated focused coverage includes synthetic fixture creation, Super Admin-only authorization, feature-flag default-off behavior, synthetic marker validation, exact account scoping, and rejection of an unregistered fixture ID.
- `npx prisma validate`: PASS.
- `git diff --check`: PASS.
- The skipped tests include database integration suites requiring external PostgreSQL credentials; the new flow has not been exercised against a live PostgreSQL or hosted staging service.

#### Remaining Stage E blockers / deployment boundary

- This is source-only implementation. The synthetic fixture feature remains disabled by default. No Render deploy, branch switch, environment variable change, Supabase write, migration, or GitHub Actions dispatch occurred.
- End-to-end hosted account deletion still needs a separately approved staging deployment/configuration step, an MFA-verified Super Admin session, explicit feature-flag enablement, fixture creation, member-facing `DELETE` request, targeted retention invocation, and read-only DB/Drive verification.
- The scheduled global retention workflow's actual successful run and secrets remain unverified. The targeted endpoint is a controlled test hook, not proof that durable scheduling is working.
- Independent post-delete Drive metadata read for the earlier anonymous complaint remains unavailable. Complaint-evidence global retention has not been exercised in this targeted account-only implementation.
- Stage E remains **NOT ACCEPTED / INCOMPLETE** until hosted account deletion, external-media purge, database state, and scheduler execution are verified. Overall Sakhi remains **NOT PRODUCTION READY / NOT READY FOR REAL MEMBER DATA**.
- Worktree remains `/workspaces/sakhi-complete-integration-20261111`, branch `integration/sakhi-complete-gemini-stage3e-stage4-20261111`, HEAD `0dd89748da1f6b9762520ed07f12228238a3c324`. Canonical handoff and source changes are uncommitted/unpushed. Existing staged/unstaged/untracked changes were preserved; no other worktree was modified.


## 2026-11-12 — Hosted staging APK release preparation (isolated branch)

- Created isolated worktree `/workspaces/sakhi-staging-release-20261112` on branch `release/staging-apk-hosted-20261112`, based on integration HEAD `0dd89748da1f6b9762520ed07f12228238a3c324`. The original integration worktree and its staged/unstaged/untracked state remain untouched.
- Imported the complete current integration diff and untracked implementation files into the isolated release worktree. Added the release branch to the staging APK workflow push trigger so a push to this branch can run backend, Super Admin, Flutter tests, and staging release/debug APK builds.
- Backend validation on Node 24.22.2: Prisma validate PASS; TypeScript typecheck PASS; Vitest PASS (40 files passed, 6 skipped; 239 tests passed, 11 skipped); backend build PASS. The skipped cases are database integration tests requiring configured external PostgreSQL credentials.
- Super Admin validation: npm ci PASS; typecheck PASS; lint PASS; production build PASS. Runtime dependency audit (`npm audit --omit=dev`) reports 0 vulnerabilities. Full dependency install reported 7 moderate vulnerabilities (development/transitive dependency tree); no forced dependency upgrades were applied. Vite emitted a bundle-size advisory only.
- Secret-pattern scan of tracked and untracked release files found no high-confidence private-key/AWS/GitHub-token/Stripe-live/Google-API-key patterns. This is not a substitute for GitHub secret scanning.
- App release configuration explicitly defaults to `https://sakhi-staging-api.onrender.com/api/v1`; the release workflow passes `SAKHI_BACKEND_ENABLED=true`, `SAKHI_STAGING_TEST_MODE=true`, and the hosted HTTPS API URL. Localhost remains only the debug/development fallback. Flutter/Dart SDK is not installed in the Codespace, so Flutter analysis/tests/APK build must run in GitHub Actions.
- Current Render staging API remains Free plan, root directory `backend`, auto-deploy enabled on checks passing, and still points to older branch `feat/stage3e-account-deletion-complaint-evidence-20261110`. No Render setting or deployment has been changed.
- Supabase Prisma migration history currently ends at `20261110180000_stage3e_account_deletion`. The isolated release source contains additional Stage 4/admin-security and Stage D RLS migrations that are not yet applied to hosted staging. Do not run `prisma migrate deploy` until the migration order/dependencies and hosted runtime role/grant effects have been reviewed against the live staging schema. No hosted DB mutation has been performed.
- Release branch changes are not yet committed or pushed. No hosted deployment, environment-variable change, synthetic account creation, or APK artifact has occurred in this stage.
- Release status remains staging-only / not production-ready / not approved for real member data. The target APK must use the hosted HTTPS staging API and must not depend on localhost.
