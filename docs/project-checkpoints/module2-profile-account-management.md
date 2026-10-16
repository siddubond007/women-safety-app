# Sakhi Module 2 — User Profile and Account Management

**Checkpoint updated:** 2026-10-16 12:24 IST (Asia/Kolkata)  
**Repository:** `siddubond007/women-safety-app`  
**Primary Module 2 branch:** `feat/user-profile-account-management`  
**Primary branch base:** `feat/auth-session-resume-logout` at `674afe4d8ed178d2b09a15af300184bb09739270`  
**Primary branch head:** `674afe4d8ed178d2b09a15af300184bb09739270` before this checkpoint commit  
**Primary PR:** Not created yet  
**Backend companion branch:** `feat/user-profile-account-management-backend`  
**Backend branch base/head at creation:** `fix/backend-pino-logger-injection` at `9347dc1e555672fd06510849e939d12c8e5aac54`  
**Backend PR:** Not created yet

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

## Changes made so far

- Created `feat/user-profile-account-management` at `674afe4d8ed178d2b09a15af300184bb09739270`.
- Created `feat/user-profile-account-management-backend` at `9347dc1e555672fd06510849e939d12c8e5aac54`.
- This checkpoint file is the first intended commit on the primary Module 2 branch. No feature code, migrations or PRs have been created yet.

## Exact next tasks

1. Commit this checkpoint on `feat/user-profile-account-management`.
2. Create a draft mobile PR targeting `feat/auth-session-resume-logout`; document the dependency on PR #11.
3. Implement Phase A mobile screens and a typed profile service on the primary branch, adding PATCH support to `BackendApiClient`; add widget/service tests.
4. Implement `ProfileModule`, DTO/controller/service, additive schema fields/migration, and backend tests on `feat/user-profile-account-management-backend`; target PR #10's branch and document dependency on PR #10/#8.
5. Update this checkpoint with exact resulting PR numbers/URLs, final head SHAs, file list, contracts, migration status and only the tests actually supported by evidence.
6. Provide complete PowerShell commands for the isolated mobile and backend worktrees. The user will run all tests locally and return output.
7. Do not apply migrations or merge any PR without explicit approval.

## Local recovery notes

- Main repository: `D:\Development\Projects\women_safety_app`
- Existing auth worktree: `D:\Development\Projects\women_safety_app-session-resume`
- Preferred new mobile worktree: `D:\Development\Projects\women_safety_app-profile-module`
- Backend worktree noted in handoff: `D:\Development\Projects\women_safety_app-backend-clean\backend`
- Confirm local `git worktree list` before creating a new worktree; never reset/reuse an existing dirty worktree. Local Git, Flutter, backend, migration and physical-device tests are user-run only.

## Definition of done for the first increment

- Profile can be read/updated only by an authenticated session owner.
- Unknown ownership identifiers cannot be used to modify another account.
- Name, biography, city and optional email validation/clearing behavior is tested.
- The server is authoritative; fields are persisted in the existing `MemberProfile` row.
- Precise device location remains unused and private by default.
- Existing auth/onboarding/session tests remain unchanged and pass when the user runs them.
- Mobile and backend PRs remain open/unmerged, and this checkpoint is updated with the exact current heads.
