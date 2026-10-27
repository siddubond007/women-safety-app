# Sakhi — Gemini Acceptance Matrix
**Date:** 2026-10-27 (Asia/Kolkata)
**Repository:** `siddubond007/women-safety-app`
**Working branch:** `feat/module5-and-rbac-admin-panels-20261027`
**Base HEAD before this local acceptance pass:** `6a2932422dcb14fa8d75fd23d9800fe70bf90542`
**Scope:** Super Admin validation, Module 5 complaint acceptance, backend regression and release-gate audit.

## Executive result

The automated checks run against the current local source tree pass: Super Admin lint/typecheck/build; Prisma schema validation; backend typecheck/build and unit tests; Flutter analysis, focused Module 5 widget tests, and full Flutter suite. Live staging API readiness, complaint-category retrieval, CORS preflight, and a clearly synthetic complaint submit/track cycle also passed after the staging-only runtime grants fix.

**This is not a release-readiness sign-off.** Commit `8d0d67170c6466f44495cababa7c586d275a81e5` is pushed to `feat/module5-and-rbac-admin-panels-20261027`. The staging Super Admin static-site deployment is live and its HTML/bundle return HTTP 200; the bundle includes the updated Registration policy label and planned-feature messaging. The staging API build succeeded and its new instance is serving health checks. Render subsequently reported the API deployment as `live`, and the deployment event finished with `succeeded` for commit `8d0d67170c6466f44495cababa7c586d275a81e5`. Authenticated Admin CRUD/roles/config screens, visual viewport review, camera capture on a real phone, iOS workflow completion, and the Module 4 real-device checks remain outstanding. The previously built APK is stale relative to these changes and must not be distributed as the current candidate.

## 1. Exact commands and results

| Area | Command / check | Result | Evidence / limitation |
|---|---|---|---|
| Flutter Module 5 | `flutter test --no-pub test/module5_discreet_complaints_test.dart` | **PASS — 11/11** | Includes Home safety concern entry, complaint hub, separate incident date/time labels, camera/gallery action presence, validation, PII redaction, EXIF scrubbing, server-backed lifecycle and empty admin-console behavior. |
| Flutter static analysis | `flutter analyze --no-pub` | **PASS** | No issues found on the final local tree. |
| Flutter full suite | `flutter test --no-pub` | **PASS — 98 passed** | The full run included the new Home-entry test. No real device was attached. |
| Super Admin lint | `npm run lint` in `super-admin` | **PASS** | React hooks lint errors in the admin roles/config and business management loading effects were corrected. |
| Super Admin typecheck | `npm run typecheck` | **PASS** | Exit code 0. |
| Super Admin production build | `npm run build` | **PASS** | Vite 8.3.4; 1,684 modules transformed. Render deployed the Admin static site for commit `8d0d671`; live HTML and JS bundle return HTTP 200, and the bundle contains the updated labels. |
| Prisma schema | `npm run prisma:validate` in `backend` | **PASS** | Schema valid; no database migration was run. |
| Backend typecheck | `npm run typecheck` | **PASS** | One test-only optional-index assertion was made type-safe at `backend/test/admin-review.spec.ts`. |
| Backend unit suite | `npm test -- --maxWorkers=1 --fileParallelism=false --testTimeout=15000` | **PASS — 102 passed, 3 skipped** | 19 test files passed; 2 database integration files were skipped. |
| Backend build | `npm run build` with `SAKHI_ENV=staging`, with no migrator URL | **PASS** | Build uses the repository's isolated offline Prisma generation step. |
| Targeted false-success regression | Filtered Vitest test: “does not report a complaint as submitted when durable persistence fails” | **PASS — 1 targeted test** | Other tests were skipped by the filter; failure path does not claim durable submission. |
| Staging readiness | `GET /api/v1/health/ready` | **PASS — HTTP 200** | Database dependency reported `ok`. |
| Staging categories | `GET /api/v1/complaints/categories` | **PASS — HTTP 200** | 10 categories returned. |
| Admin-origin CORS | OPTIONS preflight from `https://sakhi-staging-admin.onrender.com` | **PASS — HTTP 204** | This confirms preflight only, not the authenticated admin journey. |
| Unauthenticated complaint console API | `GET /api/v1/admin-review/complaints` without auth | **PASS — HTTP 401** | Protected endpoint denies anonymous access. |
| Synthetic persistence check | Submit and retrieve a synthetic anonymous complaint | **PASS — submit HTTP 201; tracking HTTP 200** | Server returned submitted/found state. No real incident data was used; reference/passkey were not exposed in output. The synthetic record remains in staging. |
| Working-tree hygiene | `git diff --check` | **PASS** | Current feature branch has local uncommitted edits. No push/deployment was triggered by this acceptance pass. |

## 2. Super Admin acceptance matrix

| Criterion | Status | Evidence / next gate |
|---|---|---|
| Lint, TypeScript typecheck and production build | **PASS** | All three commands pass after local fixes. |
| Complaint console uses API data | **SOURCE-REVIEWED** | `ComplaintsManagementPage.tsx` fetches `/admin-review/complaints` and exposes assign, status, messages, internal notes, evidence access, duplicate merge, malicious-abuse guard, retention and category configuration actions. |
| Complaint persistence reaches staging database | **PASS — API path** | Synthetic submit/track cycle passed after runtime grants were applied. |
| Complaint console authenticated UI and reviewer CRUD | **NOT VERIFIED** | No safe authenticated reviewer session was supplied for a browser journey. Do not paste tokens into chat or hardcode them. |
| Admin staff/RBAC screen | **SOURCE-REVIEWED; AUTHENTICATED CRUD PENDING** | Calls `/admin-review/staff` and `/admin-review/platform-config`; local typecheck/build pass. Create/update/disable flows still require authenticated staging validation. |
| Business directory screen | **SOURCE-REVIEWED; AUTHENTICATED CRUD PENDING** | Calls `/admin-review/businesses`; no authenticated create/review interaction was run. |
| KPI source | **SOURCE-REVIEWED** | Complaint KPIs are rendered from the complaint API payload; staff/config and business pages call API-backed sources. |
| Unauthorized access protection | **PASS — negative check** | Unauthenticated complaint queue API returns 401. This does not prove every role/permission combination is correct. |
| Navigation truthfulness | **LOCAL FIX APPLIED / BUILD PASS** | “Action center” no longer duplicates Dashboard; it is marked planned and opens the planned/unavailable page. “Wellness content” no longer duplicates Community; it is marked planned and opens the planned/unavailable page. “Platform settings” label now reads “Registration policy,” matching its page. |
| Planned routes clearly labeled | **SOURCE-REVIEWED** | Existing PlannedPage labels unsupported functionality as planned, instead of pretending it is implemented. |
| Spacing, card alignment, labels and responsive layout | **PARTIAL — SOURCE ONLY** | Layout uses responsive grid/flex patterns and labels were reviewed in source. Authenticated browser/viewport screenshot review, overlap checks and narrow/wide viewport interaction are still required. No visual pass is claimed. |
| Staging frontend contains these local UI fixes | **NOT YET** | Changes are currently local and uncommitted/unpushed; frontend staging deployment has not been approved or triggered. |

## 3. Flutter Module 5 acceptance matrix

| Criterion | Status | Evidence / next gate |
|---|---|---|
| Home “Report a Safety Concern” entry opens complaint hub | **PASS — WIDGET TEST** | New test taps the Home entry and asserts “Discreet Complaint Hub.” |
| End-user complaint hub does not expose admin console | **PASS — WIDGET TEST** | Hub test asserts the admin-console card is absent. |
| Anonymous/confidential mode, legal notice and quick exit | **PASS — WIDGET TEST** | Complaint hub widget checks remain green. |
| Separate incident date and time fields | **PASS — WIDGET TEST / SOURCE** | Test asserts separate “Approximate Incident Date” and “Approximate Time of Day” sections; model fields remain separate. |
| Camera and gallery evidence selection | **PASS — ACTION PRESENCE / SOURCE** | New “Take Photo” action calls `ImageSource.camera`; existing photo/screenshot action calls `ImageSource.gallery`. Both upload through the server-side evidence scrubber path. Actual camera permission/capture behavior remains a device test. |
| PII redaction and JPEG metadata scrubbing | **PASS — TEST** | Module 5 suite covers PII clues and JPEG APP1/EXIF marker removal. |
| Validation blocks empty and numeric-only descriptions | **PASS — WIDGET TEST** | Wizard cannot advance until description passes validation. |
| No false success or invented reference when backend fails | **PASS — FLUTTER + BACKEND REGRESSION** | Client test blocks fake reference; backend regression asserts persistence failure is not reported as submitted. |
| Successful server-backed submit/track/reply/appeal/purge lifecycle | **PASS — ISOLATED TEST CLIENT** | Widget/controller tests cover lifecycle with a test-only fake client; separate live staging synthetic submit/track verifies real persistence, but not every follow-up operation against staging. |
| Tracking lookup and 7-stage status timeline | **PASS — WIDGET TEST** | Timeline rendering checked. Live passkey-protected retrieval was separately tested against the synthetic staging record. |
| Complaint admin console empty queue/RBAC selector | **PASS — WIDGET TEST** | Test checks truthful empty-state wording and a role selector. This uses an isolated fake API client, not an authenticated production admin session. |
| Real-device camera, media permissions and upload | **PENDING** | No Android device was attached during this verification pass. |
| Real-device app crash, navigation and accessibility acceptance | **PENDING** | Flutter widget tests do not replace installation and journeys on a physical phone. |

## 4. Staging backend / security findings

- API service: `https://sakhi-staging-api.onrender.com`
- Super Admin service: `https://sakhi-staging-admin.onrender.com`
- The latest live API deploy at the start of this pass was commit `6a2932422dcb14fa8d75fd23d9800fe70bf90542`.
- The prior fix adds explicit least-privilege runtime grants for Module 5 complaint tables and admin RBAC/business/platform-config tables. The `_prisma_migrations` table remains revoked from the runtime role.
- Guarded `db-migrate.ps1 -Environment staging -GrantsOnly` passed baseline preflight and skipped migration deployment; Prisma reported the schema up to date. No schema migration, reset, marketplace database operation, role recreation, or broad grant was performed.
- Live health, categories, CORS preflight, anonymous-denial, synthetic submit and tracking checks passed.
- The three skipped backend tests include database integration coverage; those integration tests were not considered passed.
- Do not infer that the entire admin authorization matrix is validated from one negative HTTP 401 response.

## 5. iOS / APK / release gates

| Gate | Status |
|---|---|
| iOS workflow exists | **YES — SOURCE VERIFIED** |
| iOS workflow targets macOS and uses Flutter 3.47.7 | **YES — SOURCE VERIFIED** |
| Workflow runs `flutter pub get`, `flutter analyze`, `flutter test` and `flutter build ios --release --no-codesign` with staging defines | **YES — SOURCE VERIFIED** |
| Successful iOS workflow run for this exact commit | **NOT VERIFIED** — commit is pushed, but no matching GitHub Actions run result was inspected in this task. |
| iOS signing, installation and real-device tests | **PENDING** |
| Android device connected | **NO** — `adb devices` returned no devices. |
| Current-release APK | **PENDING** — existing candidate was built from an older commit and is stale relative to local camera/admin fixes. Do not distribute it as current. |
| New APK package/signature/SHA-256 verification | **PENDING** — build a separate candidate after all acceptance fixes are committed and validated; do not overwrite an older friend-testing APK. |
| Acceptance fixes deployed to staging Admin | **PASS — deployed bundle verified** | Render deployment `dep-dbgeon15efls73dn2qhg` is live for commit `8d0d671`; frontend HTML and bundle return HTTP 200. Authenticated journeys were not run. |
| Final source ZIP/checkpoint for final commit | **PENDING** — regenerate only after the final verified commit; keep secrets, local state and Gemini instruction/handoff prompts out of the ZIP. |

## 6. Original Module 4 prompt requirements not closed by this pass

The original `GEMINI_MODULE4_REPAIR_PROMPT_20261025.txt` remains a release acceptance source. This pass did not perform full Module 4 retesting. The following still require dedicated source-level and real-device confirmation before a global release claim:

1. All Safety/SOS actions have distinct, correct destinations; no fake tap targets; no SOS halo clipping/duplicate activation defects.
2. Emergency contacts persist across restart, never revert to hardcoded samples, and enforce account ownership/authorization.
3. Nearby police station/maps use a configured real provider or truthful unavailable state; attribution, permission, data freshness and distance behavior must be verified.
4. Power-button/shake shortcut support and device/OS restrictions are honest and tested.
5. GPS and live location sharing use a real device fix, consent, backend-confirmed state, expiry/stop controls, stale-data handling and safe logging.
6. Emergency call action opens the native dialer with user-controlled initiation; do not place real 112 calls during tests.
7. All sensitive admin endpoints have server-side RBAC, safe session lifecycle, auditability and least privilege; authenticated UI workflows and role boundaries still need verification.
8. Review full requirements sections **11 (Security, Privacy and Compliance), 12 (Non-Functional Requirements), and 15–20** including performance/recovery/accessibility, provider fallbacks, approved/out-of-scope integrations and client decisions. Legal/compliance review must not be inferred from technical tests.

## 7. Release blockers / next sequence

1. Finish the remaining browser/authenticated Super Admin acceptance using the authorised staging login flow without exposing tokens; capture wide and narrow viewport evidence.
2. The Module 5/Super Admin fixes were committed and pushed after explicit approval. Verify the API deploy status settles from `update_in_progress` before considering the staging rollout fully complete; no separate manual deploy was triggered.
3. Inspect the resulting GitHub Actions results, including the iOS workflow; no successful iOS build is claimed yet.
4. Build a new separate Android release candidate from the final verified commit, check application ID/version/signature and SHA-256, then install and test on a real Android device. Run iOS install tests where hardware/signing are available.
5. Complete the Module 4/SOS/GPS/map/contact/dialer acceptance rows above.
6. Create the final checkpoint and secret-free complete source ZIP from the final verified commit; exclude Gemini prompts/handoffs, local-only state, generated caches/build output, real secrets, and APKs inside the source archive. Deliver a separate verified APK.
7. Do not merge to main, deploy production, run migrations, change more database permissions, or touch the marketplace database without separate authorization.

## 8. Local change summary for this pass

- `super-admin/src/pages/AdminRolesAndConfigPage.tsx`: avoid synchronous loading-state writes through the mount effect; explicit refresh still turns on loading.
- `super-admin/src/pages/BusinessManagementPage.tsx`: same effect/loading correction; remove category-state callback dependency that could refetch unnecessarily.
- `super-admin/src/App.tsx`: prevent Action center and Wellness from silently masquerading as Dashboard/Community.
- `super-admin/src/layouts/AdminLayout.tsx`: planned navigation indicators and truthful Registration policy label.
- `app/lib/features/complaints/screens/complaint_submission_wizard_screen.dart`: explicit camera capture action in addition to gallery.
- `app/test/module5_discreet_complaints_test.dart`: Home-entry, separated date/time and camera/gallery assertions.
- `backend/test/admin-review.spec.ts`: make an optional array-index assertion type-safe.

The source changes above were committed as `8d0d67170c6466f44495cababa7c586d275a81e5` and pushed to `feat/module5-and-rbac-admin-panels-20261027` after explicit user approval. The remote branch was verified at that SHA and the working tree was clean after push. Render's Admin static-site deploy `dep-dbgeon15efls73dn2qhg` is live for that commit; API build `bld-dbgeon15efls73dn2q1g` succeeded, the new API instance started, health returned HTTP 200 with database `ok`, categories returned HTTP 200 with 10 entries, and CORS preflight returned HTTP 204 for the Admin origin. Render subsequently reported API deploy `dep-dbgeon15efls73dn2q10` as `live`; a `deploy_ended` event recorded `succeeded`. The later commit `bcc94439261c3bf95836f75d765373df8ccdb284` changes only this acceptance report, and no service deployment for that documentation-only change was listed at the last poll. No main merge or production deployment occurred.

## 9. Backend dependency security follow-up - 2026-10-28

The earlier build warning of 3 dependency vulnerabilities (1 moderate, 2 critical) has been remediated in the backend dependency manifest and lockfile.

- Updated `vitest` from 3.2.7 to the exact patched version 4.1.12.
- Added an exact `vite` 7.3.7 dev dependency because Vitest 4 declares Vite as a peer dependency. This preserves the existing Vite 7 line instead of letting a fresh install silently select Vite 8.
- The previous findings were in the test-only dependency chain (`vitest`, `@vitest/mocker`, and `tinypool`). The patched lock no longer installs the vulnerable `tinypool` dependency.

Verification on 2026-10-28, after pinning the final dependency versions:

- `npm audit`: PASS, 0 vulnerabilities.
- `npm audit --omit=dev`: PASS, 0 vulnerabilities.
- `npm run prisma:validate`: PASS.
- `npm run typecheck`: PASS.
- Backend tests: PASS, 102 passed and 3 skipped across 21 files. The three skipped database integration tests are not counted as passes.
- `npm run build`: PASS with the staging build environment set and no migrator database URL supplied.
- `git diff --check`: PASS before commit.

The local remote shell reported Node.js v22.20.0 while the backend package declares `node >=24.15.0`; npm therefore emitted an engine warning during installation. The validations and tests passed on that local runtime, but this is not a substitute for checking the staging deployment and the CI result under the project's supported Node runtime.

No schema migration, database permission change, marketplace database operation, main-branch merge, or production deployment was performed. This security remediation still requires commit/push and confirmation that the automatic staging API deployment succeeds.
