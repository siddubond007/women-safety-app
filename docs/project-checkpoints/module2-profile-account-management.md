# Sakhi Module 2 — User Profile and Account Management

**Checkpoint updated:** 2026-10-16 12:32 IST (Asia/Kolkata)  
**Repository:** `siddubond007/women-safety-app`  
**Primary Module 2 branch:** `feat/user-profile-account-management`  
**Primary branch base:** `feat/auth-session-resume-logout` at `674afe4d8ed178d2b09a15af300184bb09739270`  
**Primary feature-code head before this checkpoint refresh:** `d4fd6d584b2bd581ce31733c66082b55f062c966` (the checkpoint-refresh commit will advance the branch one commit further; verify the exact current head via GitHub before resuming)  
**Primary PR:** [#13 — feat(profile): add authenticated My Profile editing](https://github.com/siddubond007/women-safety-app/pull/13), open, draft, unmerged; base `feat/auth-session-resume-logout` at `674afe4d8ed178d2b09a15af300184bb09739270`; head `feat/user-profile-account-management` at `d4fd6d584b2bd581ce31733c66082b55f062c966` before checkpoint refresh  
**Backend companion branch:** `feat/user-profile-account-management-backend`  
**Backend branch base:** `fix/backend-pino-logger-injection` at `9347dc1e555672fd06510849e939d12c8e5aac54`; **backend feature-code head:** `d4fbb9408b4cfa61e0b2d35c90b0036d5920a0db`  
**Backend PR:** [#14 — feat(profile): add secure self-service profile API](https://github.com/siddubond007/women-safety-app/pull/14), open, draft, unmerged; base `fix/backend-pino-logger-injection` at `9347dc1e555672fd06510849e939d12c8e5aac54`; head `feat/user-profile-account-management-backend` at `d4fbb9408b4cfa61e0b2d35c90b0036d5920a0db`

## Scope and operating rules

This checkpoint records Module 2 only. Work independently of the Female Eligibility Verification workstream. Do not modify `feat/eligibility-verification`, `feat/eligibility-domain-status`, PR #7, or PR #12. Do not modify their checkpoint/reference files. Do not merge any PR. Do not use remote desktop, remote terminal, or the user's local terminal. All local tests, migrations, and device checks are run by the user from exact PowerShell commands.

The primary mobile branch is based on the exact current head of PR #11, not on the moving eligibility branch. The backend companion branch is based on the exact current head of PR #10, before the separate PR #12 eligibility-status increment. These are different Git lineages; do not assume their files are present on one another. Keep the related Module 2 client/server PRs distinct until their dependencies are deliberately integrated.

## Source requirements

The SRS `Women Centric App.docx` in `/Sakhi-Project/` defines Module 2 as: display name and profile photo; short biography; optional city/general location; interests/community preferences; personal social posts; optional business-profile link; optional followers/following; privacy settings; notification preferences; block/report; account deactivation/deletion; login-session management/account security. Users need controls for profile visibility, who may message them, post audiences, location sharing, business enquiries, and search visibility. Precise live location must never be publicly displayed by default.

The initial vertical slice is Phase A: authenticated read/update of existing profile information plus biography and optional city/general location. This does not implement photo upload, social posts, relationships, privacy controls, notifications, block/report, deactivation/deletion, or session listing; those remain later increments. Do not silently make unimplemented controls appear operational.

## Repository audit — 2026-10-16

### Latest verified pull requests

- PR #6 — `feat/auth-registration-flow`, open/unmerged, head `1db6d56a7e1ce3c1892682e9aeb26e5cc3cc54b6`, base `main`.
- PR #7 — `feat/eligibility-verification`, open/unmerged, head `d3a8b3b555bf3af87cc7f16ed6bcc1e027508560`, base PR #6 branch.
- PR #8 — `feature/backend-stage1-foundation`, open/unmerged, head `a06f7a934eda13084629f00b7ffe03c9555fa39a`, base PR #6 branch.
- PR #9 — `feat/dev-backend-integration`, open/unmerged, head `cf1746d132907f35592c8c9d4ce1ff42b14cd163`, base PR #7 branch.
- PR #10 — `fix/backend-pino-logger-injection`, open/unmerged, head `9347dc1e555672fd06510849e939d12c8e5aac54`, base PR #8 branch.
- PR #11 — `feat/auth-session-resume-logout`, open/unmerged, head `674afe4d8ed178d2b09a15af300184bb09739270`, base PR #9 branch.
- PR #12 — `feat/eligibility-domain-status`, open/draft/unmerged, head `3d9889fbc3bf34b833b4278014ed3e9037e6d3fe`, base PR #10 branch. It changes the eligibility status schema/migration and remains owned by the other workstream.

All PR #6–#12 states and refs were refreshed from GitHub during this audit. PR #6–#11 reported open/unmerged; PR #12 was open and draft. Commit status endpoints returned no status entries for heads #10, #11 or #12 at audit time. This does not mean tests passed.

### Mobile architecture on PR #11 head

- Flutter app root: `app/`; MaterialApp and startup/session restoration are routed from `app/lib/main.dart`.
- Auth abstractions live under `app/lib/features/auth/`.
- `sakhi_profile_screen.dart` is the registration details form (display name, DOB, optional email; photo upload is unavailable in preview), not a standalone account profile manager.
- `SakhiAuthStatusScreen` is the authenticated development account/status surface, currently with sign-out and sign-in navigation.
- `BackendApiClient` has authenticated GET and POST support but no PATCH helper yet.
- The app's backend integration is an opt-in debug development adapter; release auth remains unconfigured.
- Preserve onboarding screens, branding assets, authentication flow, startup session restoration, and logout behavior.

### Backend architecture on PR #10 head

- NestJS application modules are registered from `backend/src/app.module.ts`.
- `AuthModule` exports `AuthenticationService`; the service exposes `authenticateAuthorization()`, which validates the bearer token against the persisted session and rejects revoked/expired/restricted/deleted accounts.
- Prisma persistence is exposed through `PrismaService`.
- Existing `MemberProfile` fields: `accountId`, `displayName`, `dateOfBirth`, optional `email`, optional `profilePhotoRef`, timestamps. Do not create a duplicate profile table.
- Existing `AuditEvent` model supports redacted audit metadata.
- Existing `GET /api/v1/auth/me` and `POST /api/v1/auth/profile` are account/session and registration endpoints, not a general profile-edit contract.
- The PR #10 backend lineage includes committed migrations from PR #8 and the startup/logger fix. No database operation was run by this Module 2 workstream.

### Branch and shared-file boundaries

- Primary client branch: `feat/user-profile-account-management`, based on PR #11 head `674afe4d8ed178d2b09a15af300184bb09739270`.
- Backend companion branch: `feat/user-profile-account-management-backend`, based on PR #10 head `9347dc1e555672fd06510849e939d12c8e5aac54`.
- Do not branch from or update PR #12. Its schema work adds a canonical eligibility status to the account model and migration. Our profile-column changes should be additive and isolated to `MemberProfile`; coordinate migration ordering during later controlled integration.
- No database reset/drop/recreate is authorized. Do not apply Module 2 migrations to `sakhi_dev`, `sakhi_test`, or `marketplacedb`. If a database test is required, propose isolated database setup and ask before creating it or changing permissions.

## Actual prior verification evidence from upstream PR descriptions

- PR #11 reports `flutter analyze` passed, `flutter test --concurrency=1` passed 43 tests, and physical-device session restoration/logout passed on phone I2214. These are upstream-reported results, not tests run during this Module 2 session.
- PR #8 reports Prettier check, backend typecheck/build and 19 backend tests passed on its earlier revision.
- PR #10 has a later backend startup/logger fix; its current head has no commit status entries returned in this audit.
- PR #12 explicitly says the user has not run its tests locally.
- No Module 2 tests have run yet. No Module 2 physical-device checks have been performed. No Module 2 migration has been applied.

## Google Docs link limitation

The supplied Google Docs URL could not be opened through an available Google Drive connector because the Google Drive integration is disabled by administrator policy. The SRS and eligibility handoff were found in the persistent ChatGPT Library and used as the current project references. If the linked document contains requirements beyond those Library references, it still needs to be provided through an available route before relying on additional content.

## API and data design for Phase A

Proposed endpoint contract:

- `GET /api/v1/profile/me`: read only the authenticated session owner's profile.
- `PATCH /api/v1/profile/me`: update an explicit allowlist of profile fields; derive `accountId` only from the validated bearer session, never from request body/query/path ownership IDs.
- Initial mutable fields: `displayName` (required/non-null when supplied), `bio` (optional, max 500 characters), `city` (optional general location, max 100 characters), and `email` (optional and clearable).
- Do not expose DOB in the public/profile response by default. Do not use GPS or background location for city/general location.
- Add nullable `bio` and `city` columns to the existing `MemberProfile` model through a forward-only migration with no destructive operation. The exact migration will be created only on the backend companion branch.
- Record profile-change audit metadata without storing profile values in audit logs.
- Return safe errors for missing profiles and invalid input. Reject unknown DTO fields using existing global validation conventions.

## Current implementation state — Phase A initial increment

### Mobile PR #13

Committed to `feat/user-profile-account-management`:
- `app/lib/features/profile/profile_service.dart`: typed profile model and authenticated GET/PATCH adapter; never sends an owner/account ID.
- `app/lib/features/profile/sakhi_my_profile_screen.dart`: My Profile / edit screen with display name, optional email, bio, and city/general area, loading/retry/save/error states, and explicit not-yet-implemented photo/privacy messaging.
- `app/lib/features/auth/backend_api_client.dart`: authenticated PATCH method.
- `app/lib/features/auth/sakhi_auth_status_screen.dart`: link to My Profile only for development-backend sessions in eligible account states; existing logout/session logic unchanged.
- `app/test/profile_service_test.dart`: API adapter response/normalization tests.
- `app/test/profile_screen_test.dart`: profile load/save and retry tests.
- PR #13 is open, draft and unmerged, and currently reports GitHub mergeable=true. This is GitHub metadata, not a test result.

Relevant mobile commits before checkpoint refresh:
- Initial checkpoint: `89ab8f05b4b569bb0f0f2d330be42e38355c25b8`.
- Initial UI/API client increment: `e19d951853a615970058c2d3ba2f2c4abf617c87`.
- Existing design-token correction and load-retry test fix: `d4fd6d584b2bd581ce31733c66082b55f062c966`.

### Backend PR #14

Committed to `feat/user-profile-account-management-backend`:
- `backend/src/profile/profile.dto.ts`, `profile.controller.ts`, `profile.service.ts`, and `profile.module.ts`.
- `backend/src/app.module.ts` registers `ProfileModule`.
- `backend/prisma/schema.prisma` adds nullable `bio` (VARCHAR(500)) and `city` (VARCHAR(100)) to the existing `MemberProfile`.
- `backend/prisma/migrations/20261016130000_member_profile_bio_city/migration.sql` contains a forward-only, database-name-guarded additive migration. It has **not** been applied anywhere.
- `backend/test/profile.spec.ts` covers self-profile GET/PATCH, owner ID injection rejection, input validation, optional clearing, response minimization, and audit field redaction.
- Backend feature commit before checkpoint refresh: `d4fbb9408b4cfa61e0b2d35c90b0036d5920a0db`.
- PR #14 is open, draft and unmerged, and currently reports GitHub mergeable=true. This is GitHub metadata, not a test result.

### Phase A contract

- `GET /api/v1/profile/me`: derive owner from the validated bearer session and return only display name, email, bio, city, and update timestamp.
- `PATCH /api/v1/profile/me`: allow only display name, email, bio, and city; derive ownership from session, reject unknown fields, normalize cleared optional values to null, and audit changed field names only.
- Date of birth, account ID, precise location, eligibility status, and profile photo data are intentionally excluded from these profile endpoints.
- Client profile editing is shown only for development-backend authenticated accounts. Production authentication remains unconfigured as documented by the existing project.
- The client and backend PRs are based on different unmerged upstream lineages. Keep them separate; do not merge or rebase onto the eligibility branch now.

## Exact verification status

- **Module 2 Flutter analyze/test/build:** not run in this session.
- **Module 2 backend typecheck/build/test/format checks:** not run in this session.
- **Module 2 migration:** committed only; not applied to `sakhi_dev`, `sakhi_test`, or any other database.
- **Module 2 physical-device tests:** not run.
- Upstream-reported PR #11 Flutter results remain historical evidence only: analyze had no issues, 43 Flutter tests passed with concurrency 1, and session restore/logout was physically checked on device I2214. Do not attribute these results to Module 2.

## Known limitations / issues to test

1. No profile-photo upload/removal yet.
2. No interests/community preferences, privacy settings, notification preferences, block/report, relationships/posts, account deactivation/deletion, or active-session listing in Phase A.
3. Backend migration requires deliberate application to an isolated/test database; no database was created or changed by this workflow.
4. The linked Google Docs URL could not be opened through Drive because the Google Drive integration is disabled by administrator policy. The SRS and eligibility handoff were recovered from the persistent ChatGPT Library; request the doc contents if it contains additional requirements not covered there.
5. The exact branch HEAD will advance when this checkpoint is committed. Always refresh GitHub and verify the current PR head SHA on resume rather than assuming the pre-refresh SHA listed above is still tip.

## Exact next tasks

1. Review/fix any issues found by the maintainer's local validation.
2. Fetch and test mobile PR #13 in the isolated worktree; test only after backend API is present or expect backend connection errors.
3. Create/use a separate backend worktree for PR #14; run formatting, Prisma validation/generation, typecheck/build, and tests. Do not run the migration yet.
4. Send the full output back to ChatGPT; implement the smallest safe fixes on the corresponding Module 2 branch only.
5. Once API and mobile tests pass, consider local integration against a separately approved isolated database (propose setup first; do not create/use it without approval).
6. Extend Phase A to include a route/status screen widget test and explicit service unauthorized-error UI testing if the first run reveals gaps.
7. Begin photo upload/preferences only after Phase A passes and the upload/storage infrastructure has been audited.

## Exact local validation commands

Before creating any worktree, run `git worktree list` and inspect local branch state. Do not reuse/reset a worktree. User-only commands; no local commands have been executed by this conversation.

Mobile worktree path:
`D:\Development\Projects\women_safety_app-profile-module`

From an existing repository checkout, after confirming this path is not already used:
```powershell
Set-Location 'D:\Development\Projects\women_safety_app'
git worktree list
git fetch origin feat/user-profile-account-management
git worktree add -b feat/user-profile-account-management 'D:\Development\Projects\women_safety_app-profile-module' origin/feat/user-profile-account-management
Set-Location 'D:\Development\Projects\women_safety_app-profile-module\app'
& 'D:\Development\flutter\bin\flutter.bat' pub get
& 'D:\Development\flutter\bin\flutter.bat' analyze
& 'D:\Development\flutter\bin\flutter.bat' test --concurrency=1
```

Backend companion worktree path (keep separate from the existing backend-clean worktree):
`D:\Development\Projects\women_safety_app-profile-backend-module`

After checking `git worktree list` and confirming the path is unused:
```powershell
Set-Location 'D:\Development\Projects\women_safety_app'
git fetch origin feat/user-profile-account-management-backend
git worktree add -b feat/user-profile-account-management-backend 'D:\Development\Projects\women_safety_app-profile-backend-module' origin/feat/user-profile-account-management-backend
Set-Location 'D:\Development\Projects\women_safety_app-profile-backend-module\backend'
npm ci
npm run format:check
npm run prisma:validate
npm run typecheck
npm run build
npm test
```

Do not run `npm run db:migrate:deploy` or any migration command yet. These commands have not been executed by this chat. If a worktree/local branch already exists, stop and report the output instead of overwriting it.

## Recovery guardrails

- Do not modify PR #7, PR #12, `feat/eligibility-verification`, `feat/eligibility-domain-status`, or the eligibility checkpoint.
- Do not merge PRs #13/#14 or any upstream PR without explicit owner approval.
- Do not apply the migration to `sakhi_dev`, `sakhi_test`, or `marketplacedb`.
- No terminal/remote desktop interaction from ChatGPT; the user runs the PowerShell commands above.
