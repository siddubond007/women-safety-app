# Sakhi eligibility-verification integration contract

**Status:** provider-neutral UI and planned service boundary only. No identity
provider, legal method, eligibility policy, or production backend is configured.

## Current Flutter boundary

The eligibility feature is isolated under `features/eligibility/`:

- `eligibility_verification_models.dart` holds typed status, configuration,
  consent and result models.
- `eligibility_verification_service.dart` defines the future service boundary.
- The current `DemoEligibilityVerificationService` reports provider
  unavailability and does not create sessions or persist consent.
- Screens show information, preview consent interaction and separate result
  states. A preview status never grants protected access.
- `SakhiAuthStatusScreen` exposes a `Preview eligibility verification` entry
  for `existingAccount` and `pendingVerification`. It is hidden before profile
  completion and for restricted accounts. The entry routes to the current
  Flutter-native introduction using `DemoEligibilityVerificationService`.
- This is UI navigation only: it does not create an account session, invoke an
  identity provider, persist consent or grant protected community access.
  Existing registration, mobile OTP and account-creation behavior is unchanged.

This contract defines candidates, not implemented HTTP endpoints.

## Decisions required before a real integration

Do not choose or infer these values in code:

1. Authorised identity provider and supported verification method.
2. Legal basis, eligibility criteria and the exact permitted identity attributes.
3. Whether selfie matching or liveness checks are lawful, supported and approved.
4. Final consent wording, notice/version and privacy disclosures.
5. Data controller/processor roles, provider sharing, storage and retention.
6. Deletion process, access/audit controls, incident handling and user rights.
7. Approved alternative/manual-review workflow and its evidence requirements.
8. Approved production age policy and relevant safeguards.
9. Backend ownership, endpoint contracts, authentication and deployment readiness.

Before requesting production consent, the service must supply complete, approved
disclosures for the provider, method, checked attributes, selfie/liveness use,
data handling, retention/deletion, decline/failure outcome, and approved
alternative/manual review. Missing fields mean the real start action stays
disabled.

## Future service operations

The Dart interface names three design operations:

- `loadConfiguration()`: return only approved, current verification
  configuration and disclosure text.
- `readStatus()`: return status from the trusted backend for the authenticated
  account; do not infer status from local UI state.
- `startVerification(consent)`: after backend-authenticated consent and
  approved configuration, request creation of a provider transaction and return
  a status confirmed by the trusted service.

No live adapter or endpoint is implemented here. A future adapter must validate
the authenticated account on the server and associate consent with the exact
approved policy version and timestamp. Never trust a client-side redirect as
confirmation.

## Required server-side controls

- The backend is authoritative for verification status.
- Protected community APIs enforce eligibility on every relevant request;
  hidden tabs and client-side Booleans are not access control.
- Bind a provider transaction to the authenticated user and an unpredictable,
  single-use transaction/state value. Validate callback authenticity, state,
  nonce where applicable, transaction status, expiry and replay.
- Process trusted provider callbacks/webhooks server-side and retrieve
  authoritative status from the backend after handoff.
- Apply rate limits, expiry, idempotency and audit controls to applicable
  operations.
- Never store raw identity documents, selfie images, face templates or raw
  provider payloads by default. Collect the minimum approved result only.
- Restrict and audit access if a future, approved manual-review process needs
  sensitive evidence.
- Do not log OTPs, tokens, raw provider responses, identity evidence or
  unnecessary personal data.
- A technical failure, cancellation, timeout or unavailable provider is not an
  eligibility rejection.
- Demo/test statuses must never create an authenticated session or grant
  protected access.

## Status semantics

The UI exposes the same seven canonical eligibility statuses used by the
backend, with readable labels:

- `notVerified` — Not Verified
- `inProgress` — Verification In Progress
- `pendingManualReview` — Pending Manual Review
- `verified` — Verified
- `verificationFailed` — Verification Failed
- `temporarilyRestricted` — Temporarily Restricted
- `reverificationRequired` — Reverification Required

Additional screen/service states (`notStarted`, `consentRequired`,
`consentNotGiven`, `cancelled`, and `providerUnavailable`) describe the
flow rather than new persisted eligibility decisions. A technical error,
cancellation, timeout or unavailable provider is not an eligibility rejection.

Only the trusted backend may establish a real final decision. Manual review is
displayed as a possible status, not an implemented workflow. The app must not
request documents or offer a working upload/review submission until its process,
lawful basis, access controls and retention policy are approved.

## UI presentation checkpoint

The introduction, information, consent and status screens use Flutter-native
layout, text, Material icons, gradients and vector-like geometric shapes. They
do not crop or reuse images from reference screenshots. Existing standalone
Sakhi branding/illustration assets remain separate source files and are only
displayed as their original assets. The progress indicator, privacy cards,
consent panel and status badge are responsive components built from code.

The interface communicates each of the seven canonical states, makes the
provider-unavailable preview explicit, and never presents a simulated result as
a real eligibility decision. Maintainer validation completed against the
formatted source represented by UI branch head
`bb1f1151a6b521b56d6ab32622ec7c9e8ffbe08f`: Dart formatting was applied;
`flutter analyze` reported no issues; all 9 eligibility widget tests passed;
and the full Flutter suite passed all 37 tests. The only changes made in the
isolated worktree after checkout were the six formatter-produced source/test
diffs now committed to this branch.

## Demo boundary

The current preview has no identity provider, sends no identity data, records no
valid production consent, creates no provider session, and does not persist
eligibility status. Its `DEMO RESULT — no real identity verification occurred.`
notice is mandatory on preview outcomes. App restart does not restore a real
eligibility state because none exists in this stage.

## Post-authentication UI and device-test checkpoint

The current eligibility preview is reachable from `SakhiAuthStatusScreen`
through `Preview eligibility verification` for existing/pending account states.
The widget flow now covers introduction, disclosure, demo consent and the
provider-unavailable status, and verifies that `Start verification` remains
disabled when no approved provider/policy is configured. This preview route is
built on the current `feat/eligibility-verification` UI branch so device tests
exercise the latest consent-panel fix.

**Maintainer validation completed on 16 October 2026** at source commit
`07317a3c0a1893139bb6a035163f35f19d3b56c5`:

- Dart format check reported no changes required (the first check ran before
  `flutter pub get`; the dependencies were subsequently resolved).
- `flutter analyze` passed with no issues.
- The full `flutter test` suite passed all 39 tests.
- The app built and installed on the physical I2214 Android 16 device.
- Screenshot review covered introduction, information disclosures, consent and
  provider-unavailable status. No obvious layout overflow or clipped action was
  visible. The Start verification action remained disabled when the provider
  and policy were unavailable, the demo-only warning was visible, and the
  final status screen explicitly stated that protected features remain
  protected.

The device build exercised the demo preview, not live backend integration or a
real provider. The Git worktree was clean at the tested commit.

## Later work requires separate approval

Real provider integration, backend persistence, database migrations, production
eligibility decisions, Super Admin review tools and sensitive-evidence handling
require an approved provider/method, legal policy and review process. Until then,
the mobile preview must remain explicitly unavailable and fail closed.
