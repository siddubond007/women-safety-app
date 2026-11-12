# Sakhi Security, Privacy, Row-Level Security (RLS) & Android Signing Review

- **Date:** November 7, 2026
- **Repository:** [`siddubond007/women-safety-app`](https://github.com/siddubond007/women-safety-app)
- **Target Branch:** `gemini/sakhi-comprehensive-fixes-20261107`
- **SRS Reference:** [Sakhi Women-Centric App SRS (`Women Centric App.docx` — Modules 1–12)](https://docs.google.com/document/d/1DK0om8qAtYw3eEyye84iSb9cPZ7JJ-Vh/edit)

## 1. Super-Admin Authentication, Password Hashing & RBAC Hardening (Section 10)

| Security Control | Implementation Details | Code Location |
| :--- | :--- | :--- |
| **Password Hashing (`scrypt`)** | Admin passwords are hashed using Node.js native `crypto.scryptSync` (`N=16384, r=8, p=1, keylen=64`) with a 16-byte cryptographically random salt (`scrypt$16384$8$1$<saltHex>$<derivedHex>`) and verified via constant-time `crypto.timingSafeEqual`. Plaintext passwords are never logged or persisted. | `backend/src/admin-review/admin-rbac.helper.ts` (`hashAdminPassword`, `verifyAdminPassword`) |
| **Zero Hardcoded Admin Credentials** | The First Super Admin account is provisioned exclusively when `SAKHI_SUPER_ADMIN_BOOTSTRAP_EMAIL`, `SAKHI_SUPER_ADMIN_BOOTSTRAP_USERNAME`, and `SAKHI_SUPER_ADMIN_BOOTSTRAP_PASSWORD` environment variables are explicitly configured on the server (`ensureBootstrapSuperAdmin`). Zero default or hardcoded passwords exist in source code or migrations. | `backend/src/admin-review/admin-review.service.ts` |
| **Brute-Force & Account Lockout Protection** | Failed login attempts increment `AdminStaffAccount.failedLoginAttempts`. After 5 consecutive failures, `lockedUntil` is set to `+15 minutes` and an immutable `admin_review.auth.account_locked` audit event is recorded. | `backend/src/admin-review/admin-review.service.ts` (`loginWithCredentials`) |
| **Rotating Session Tokens & `HttpOnly` Cookie** | Successful login generates a 32-byte random session token whose SHA-256 hash (`tokenHash`) is stored in `admin_auth_sessions` with an 8-hour expiration (`expiresAt`). The controller sets `sakhi_admin_session` with `HttpOnly; SameSite=Strict; Path=/api/v1/admin-review` (plus `Secure` in production), and `super-admin/src/services/auth/adminAuthService.ts` stores zero long-lived reviewer secrets in `localStorage`. | `backend/src/admin-review/admin-review.controller.ts`, `super-admin/src/services/auth/adminAuthService.ts` |
| **6-Tier Least-Privilege RBAC** | Enforces granular permissions across `SUPER_ADMIN`, `ADMIN`, `MODERATOR`, `MEMBER_SUPPORT`, `BUSINESS_REVIEWER`, and `READ_ONLY_AUDITOR` (`roleHasPermission`). Only `SUPER_ADMIN` can create admin accounts, change roles, or reset staff passwords. | `backend/src/admin-review/admin-rbac.helper.ts` |

## 2. Menstrual Health & Wellness Data Isolation & Account Deletion Purge (Sections 6 & 12)

- **Strict Owner Isolation:** Menstrual cycle entries (`MenstrualCycleLog`), daily symptom logs (`MenstrualDailyLog`), tracker preferences (`MenstrualTrackerPreference`), and wellness voice/audio preferences (`MemberWellnessPreference`) are scoped strictly to the authenticated `accountId` and excluded from all public profiles, social feeds, search indexes, and Super-Admin inspection endpoints.
- **PostgreSQL Row-Level Security (RLS):**
  - Migration `backend/prisma/migrations/20261107120000_sakhi_wellness_circles_admin_auth_hardening/migration.sql` enables `ROW LEVEL SECURITY` and `FORCE ROW LEVEL SECURITY` on `member_wellness_preferences`, `member_push_tokens`, and `admin_auth_sessions`, restricting access to `sakhi_backend_runtime` (`backend/prisma/staging/runtime-grants.sql`).
- **Complete Account Deletion Purge:**
  - `Module2Service.requestAccountDeletion` (`backend/src/module2/module2.service.ts`) atomically purges `menstrualCycleLog`, `menstrualDailyLog`, `menstrualTrackerPreference`, `memberWellnessPreference`, `memberPushToken`, `communityCircleMembership`, and active sessions alongside account PII anonymization.

## 3. Media Upload Validation & EXIF Metadata Scrubbing (Section 8.1 & 12)

- **Client-Side + Server-Side EXIF Stripping:**
  - In `app/lib/features/profile/screens/profile_screen.dart` (`_stripJpegExifSegments`), JPEG `APP1` (`0xFFE1` EXIF/GPS/XMP) and `APP13` (`0xFFED` IPTC) segments are stripped before multipart upload.
  - On the backend (`Module2Service.uploadMedia`), magic-byte signature verification (`image/jpeg`, `image/png`, `image/webp`) and server-side EXIF stripping remain enforced before persisting or uploading to storage.

## 4. Android Release Signing & Secret Hygiene Audit (Section 13)

- **Alignment with [PR #33](https://github.com/siddubond007/women-safety-app/pull/33):**
  - Verified that no production `.jks` or `.keystore` files or plaintext `key.properties` are tracked in Git on `gemini/sakhi-comprehensive-fixes-20261107`.
  - `.gitignore` excludes `*.jks`, `*.keystore`, `key.properties`, and `.env*`.
  - `.github/workflows/sakhi-modules8-9-staging-apk.yml` generates an ephemeral, one-run staging key (`sakhi-staging-ci.jks`) during CI, masks the password (`::add-mask::`), verifies the APK signature via `apksigner`, and deletes `android/key.properties` and `android/app/sakhi-staging-ci.jks` in an `if: always()` cleanup step.
