# Sakhi Super Admin

Standalone React + TypeScript + Vite administration UI for the Sakhi mobile platform. The admin application is isolated in this directory and does not replace or embed the Flutter app.

## Current scope

### Stage 1 — Admin foundation
- Responsive admin shell, branded demo sign-in, grouped navigation and module search.
- Browser-session-only demo session. This is not real authentication or authorization.
- Dashboard KPI cards, activity chart, operational examples and integration placeholders.
- Typed dashboard repository backed by fictional sample data.
- Planned-module states, shared status components and theme styles.

### Stage 2 — Members & Accounts
- Mock-backed member directory containing fictional records only.
- Search across display name, member reference and masked contact examples.
- Account status, verification status and registration-period filters.
- Registration/name/activity sorting and pagination.
- Member profile drawer with masked email/phone, registration/last-activity dates and status.
- Reason-required demo warning, temporary restriction, temporary suspension and reinstatement workflows.
- In-session demo action history showing the simulated action, actor, timestamp and reason.
- Loading, retry, empty-result, confirmation and success-notice states.
- No permanent-ban or deletion action is provided by this prototype.

## Important status and data safety

**This is a frontend-only prototype.** The backend is not implemented or connected. Dashboard and member records are fictional, all service integrations remain unconnected, and sample account actions update only an in-memory mock adapter. They do not alter production data, send notifications, or persist to a server. A full page refresh restores the original mock dataset.

All contact examples are masked and use the reserved `example.invalid` email domain. Do not add real member data, credentials, complaint evidence, identity documents, health data or live locations to the mock dataset.

Do not deploy this demo sign-in as an access-control mechanism. Production authentication/MFA, backend-enforced authorization on every request and record, durable audit logs, approved account policies, and security/privacy review remain future work.

## Requirements

Use a supported Node.js release for the installed Vite version and npm.

## Run locally

From the repository root:

```powershell
cd super-admin
npm install
npm run dev
```

Open the loopback URL printed by Vite (normally http://127.0.0.1:5173) and choose **Enter demo environment**. No real credential is required or collected.

## Checks

```powershell
npm run typecheck
npm run lint
npm run build
```

Stage 2 was also exercised in a local Chromium smoke test for search, filtering/reset, pagination, masked details, restriction confirmation, reason/duration validation flow, simulated restriction and reinstatement, action history, mobile layout, browser errors and horizontal overflow. This temporary smoke-test script was not committed as a project test suite.

## Architecture and next steps

- Dashboard and member records are loaded through typed repository interfaces. Mock adapters are the only configured implementations.
- Keep the central data-source selector on mock mode until approved backend routes and response contracts exist.
- Map member/verification operations to actual backend models and authorization rules before replacing the adapter.
- Values from `VITE_*` environment variables are public browser configuration, not secret storage.
- Eligibility criteria, minimum age, lawful identity-verification method/provider, manual fallback and related retention policies need explicit product/legal approval.
- Keep the Stage 2 changes isolated to this directory; `app/` and `backend/` are preserved.

## Manual eligibility review - local dev/test stage

The `Eligibility & verification` page uses the NestJS API. The dashboard and member-management pages remain mock-backed. Reviewer access uses a shared token only for the local dev/test prototype; it is not individual administrator authentication and must never be deployed to production.

The queue contains explicit `EligibilitySubmission` records, not every profile with Terms/Privacy consent. Manual submission is disabled unless the local backend receives all of these approved settings: `SAKHI_MANUAL_REVIEW_POLICY_APPROVED=true`, `SAKHI_MANUAL_REVIEW_EVIDENCE_PROCEDURE_APPROVED=true`, `SAKHI_MANUAL_REVIEW_CONSENT_VERSION`, `SAKHI_MANUAL_REVIEW_CONSENT_TEXT`, `SAKHI_MANUAL_REVIEW_DESCRIPTION`, `SAKHI_MANUAL_REVIEW_DATA_HANDLING_DESCRIPTION` and `SAKHI_MANUAL_REVIEW_RETENTION_DESCRIPTION`. These settings are configuration gates, not a substitute for product, privacy or legal approval.

This stage does not collect, upload, store or display selfie/identity evidence. Review decisions may be recorded only after a reviewer follows the separately approved evidence procedure configured for this deployment. Never infer eligibility from a face, name or profile fields alone. Selfie capture/upload, private evidence storage, retention/deletion enforcement and appeal/resubmission remain outside this stage and must be designed and approved before identity evidence is collected in Sakhi.

The shared `SAKHI_ADMIN_REVIEW_TOKEN` and configured `SAKHI_ADMIN_REVIEWER_LABEL` identify a local reviewer session only; the label is not a unique or independently authenticated person. Production authentication, MFA, identity-bound reviewer accounts and production deployment remain out of scope. Source changes do not execute database migrations.


## Hosted staging test-access portal

When deployed from the root Render Blueprint with `VITE_ADMIN_MODE=staging-test`, the static site provides a dedicated staging test-access page. It talks to the configured HTTPS staging API, not a localhost backend.

- Use the **separate** `SAKHI_STAGING_TEST_ADMIN_TOKEN` generated and stored in the Render API service's protected environment. Enter it once in the portal's password field after deployment. The API exchanges it for an eight-hour signed session token held in JavaScript memory only; a page refresh signs the reviewer out.
- Never put this token in `VITE_*` variables, source code, HTML, an APK, local/session storage, or a committed file. Browser configuration is public. Login and admin API requests are restricted to the configured exact HTTPS origin.
- The portal only grants/revokes staging test access. Each action adds an audit event; the member's real `status`, `verificationStatus`, and phone-verification fields are unchanged.
- The mobile API honors the latest test-access audit marker only when hosted staging test mode, the explicit feature flag, and the separate server-side token are configured. Revocation removes access on the next authenticated API request.
- Test access is not identity verification and does not establish phone ownership or eligibility. The app must continue to show the real eligibility status as unverified.
- The hosted reviewer token is separate from the local-only `ADMIN2026TEST` token; the latter is rejected by the hosted staging reviewer endpoints.

Deploy the root `render.yaml` Blueprint changes to create the static site `sakhi-staging-admin` and set the staging API CORS origin. After Blueprint sync, confirm both services are live, then open the static site's assigned HTTPS URL. Do not enable the local `/admin-review` routes in production.
