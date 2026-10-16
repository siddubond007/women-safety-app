# Sakhi eligibility-verification integration contract

**Current implementation:** the Flutter feature is connected to the existing development-backend API boundary. The identity provider and eligibility policy remain unconfigured. No real identity-verification session may start from the mobile app yet.

## Current mobile boundary

The feature remains isolated under `features/eligibility/`:

- `eligibility_verification_models.dart` holds typed provider configuration, consent and status/result models. The seven backend statuses remain distinct from UI-only states.
- `eligibility_verification_service.dart` defines the contract and safe demo implementation.
- `backend_eligibility_verification_service.dart` reads the backend configuration and authenticated status, and implements the server's explicit-consent request shape.
- `SakhiAuthStatusScreen` exposes the eligibility entry only for `existingAccount` and `pendingVerification`. It is hidden before profile completion and for restricted accounts.
- When the current auth service is the development backend, the eligibility feature reuses the same secure token-storage key and build-time API base URL as `BackendAuthService`. Demo builds use `DemoEligibilityVerificationService`.
- The user-visible UI remains provider-unavailable while the server reports no approved provider/policy. No identity evidence is collected or sent.

### Deliberate start-session gate

`EligibilityConfiguration.mobileHandoffSupported` remains false in this mobile implementation. Consequently, `Start verification` stays disabled even if a later server configuration reports an approved provider. Before enabling it, implement and test the secure hosted-provider handoff, return/deep-link handling, expiry/cancellation, and a fresh trusted status lookup after return. A provider redirect by itself is never proof of eligibility.

If biometric processing is required by a future approved provider, the API configuration exposes separate `biometricProcessingSupported` and `biometricProcessingRequired` flags. A separately worded consent control is available for that future flow; required biometric consent must be selected before the start action can be enabled. The server remains authoritative and must reject missing consent independently.

## Current API contract

The existing backend exposes these versioned endpoints:

- `GET /api/v1/eligibility/configuration` — returns provider/policy readiness and disclosure text. It does not collect identity evidence.
- `GET /api/v1/eligibility/status` — requires the authenticated bearer token. Its `status` field describes provider readiness; `eligibilityStatus` is the canonical persisted account status. The mobile adapter keeps those meanings separate.
- `POST /api/v1/eligibility/start` — requires authentication, `consentAccepted: true`, the current `consentVersion`, and `biometricProcessingConsented`. The mobile adapter sends only these DTO-supported fields; it does not send an `acceptedAt` client timestamp. The server records the consent timestamp. The current UI cannot invoke this request until the mobile handoff gate is deliberately enabled.

A 409/503 provider-unavailable response is a normal fail-closed outcome, not a verification failure or an eligibility rejection. An unknown or absent backend status must never become `Verified`.

## Decisions required before a real provider

Do not invent or infer these values in code:

1. An authorised identity provider and supported verification method.
2. Legal basis, eligibility criteria and exact permitted identity attributes.
3. Whether selfie matching or liveness checks are lawful, supported and approved.
4. Final consent wording, notice/version and privacy disclosures.
5. Data controller/processor roles, provider sharing, storage and retention.
6. Deletion process, access/audit controls, incident handling and user rights.
7. An approved alternative/manual-review workflow and its evidence requirements.
8. Approved production age policy and relevant safeguards.

Before production consent is requested, the service must provide complete approved disclosures for provider, method, attributes checked, selfie/liveness use, data handling, retention/deletion, decline/failure outcome and an approved alternative/manual review. Missing disclosure fields mean the real start action stays disabled.

## Required server-side controls

- The backend is authoritative for eligibility status.
- Every protected community API must enforce eligibility server-side; hidden tabs and client-side Boolean flags are not access control.
- Bind provider transactions to the authenticated user and an unpredictable, single-use transaction/state value. Validate callback authenticity, state, nonce where applicable, transaction status, expiry and replay.
- Process trusted provider callbacks/webhooks server-side and retrieve authoritative status from the backend after handoff.
- Apply rate limits, expiry, idempotency and audit controls to applicable operations.
- Never store raw identity documents, selfie images, face templates or raw provider payloads by default. Collect only the minimum approved result.
- Restrict and audit any future manual-review access.
- Never log OTPs, tokens, raw provider responses, identity evidence or unnecessary personal data.
- A technical failure, cancellation, timeout or unavailable provider is not an eligibility rejection.
- Demo/test results must never create an authenticated session or grant protected access.

## Status semantics

The UI maps the canonical backend statuses to these labels:

- `notVerified` — Not Verified
- `verificationInProgress` — Verification In Progress
- `pendingManualReview` — Pending Manual Review
- `verified` — Verified
- `verificationFailed` — Verification Failed
- `temporarilyRestricted` — Temporarily Restricted
- `reverificationRequired` — Reverification Required

Additional screen/service states (`notStarted`, `consentRequired`, `consentNotGiven`, `cancelled` and `providerUnavailable`) describe the flow, not new persisted eligibility decisions. A technical error, cancellation, timeout or unavailable provider is not an eligibility rejection.

Only a trusted backend provider result or authorized review can establish a real final decision. Manual review is displayed as a possible status but is not an implemented reviewer workflow. Do not request documents or offer a working upload/review submission until its policy, lawful basis, access controls and retention rules are approved.

## UI and physical-device checkpoint

The introduction, information, consent and status screens use Flutter-native layout, text, Material icons, gradients and vector-like geometric shapes. The screenshots were reviewed on the physical I2214 running Android 16. The screens were readable and showed no obvious clipping/overflow; the information screen scrolled through all disclosures, the consent action stayed disabled, and the final status explicitly stated that protected features remain protected.

At preview source commit `07317a3c0a1893139bb6a035163f35f19d3b56c5`, the maintainer reported:

- Dart formatting check reported no changes needed after dependency resolution.
- `flutter analyze` passed with no issues.
- The full Flutter suite passed all 39 tests.
- The debug APK built and installed on the physical device.
- Introduction, information, consent and provider-unavailable status screenshots were reviewed.

This validates the demo preview only. The new backend-mobile adapter changes and its additional unit tests still require a separate local Flutter validation run. Live API testing must use the test database, not `sakhi_dev`; do not reset any database.

## Remaining work

Still outstanding are local validation of the backend-mobile branch; integration testing against the local backend; secure provider handoff/return; actual provider and legal approval; protected community controller/route integration; authorized review/appeal workflows; and retention/deletion controls. The UI and server must remain fail-closed until the relevant external and security prerequisites are approved.
