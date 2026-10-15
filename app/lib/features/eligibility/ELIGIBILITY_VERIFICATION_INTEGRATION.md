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
- `SakhiConsentScreen` offers a clearly labelled demo-only entry point.
  Existing registration, mobile OTP and account-creation logic are unchanged.

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

The UI model deliberately separates:

- `notStarted`, `consentRequired`, `consentNotGiven`
- `inProgress`, `pendingManualReview`
- `verified`, `rejected`, `reverificationRequired`
- `verificationFailed`, `cancelled`, `providerUnavailable`

Only the trusted backend may establish a real final decision. Manual review is
displayed as a possible status, not an implemented workflow. The app must not
request documents or offer a working upload/review submission until its process,
lawful basis, access controls and retention policy are approved.

## Demo boundary

The current preview has no identity provider, sends no identity data, records no
valid production consent, creates no provider session, and does not persist
eligibility status. Its `DEMO RESULT — no real identity verification occurred.`
notice is mandatory on preview outcomes. App restart does not restore a real
eligibility state because none exists in this stage.

## Later work requires separate approval

Real provider integration, backend persistence, database migrations, production
eligibility decisions, Super Admin review tools and sensitive-evidence handling
are out of scope for this UI stage and require an approved implementation plan.
