# Sakhi eligibility verification — backend foundation

**Research checked:** 16 October 2026  
**Implementation scope:** canonical eligibility state model and a fail-closed status boundary. This document is an engineering record, not legal advice.

## Repository audit

The feature builds on the existing provider-neutral Flutter preview and NestJS endpoint family in the eligibility workstream. Current backend behavior before this increment was:

- `GET /api/v1/eligibility/configuration` returns no configured provider or approved policy.
- `GET /api/v1/eligibility/status` requires the authenticated development session and reports provider unavailability.
- `POST /api/v1/eligibility/start` authenticates the caller but returns HTTP 409; it does not create a fake provider session.
- The existing database `verification_status` field only represents the earlier `UNVERIFIED/VERIFIED` flag. It must not be interpreted as the full community eligibility decision.

The first increment added a distinct persisted `eligibility_status`, exposed it separately from the existing provider-unavailable contract, and defined the transition policy. The follow-up increment adds a disabled-by-default provider adapter boundary, explicit notice-version/biometric-consent validation for any enabled adapter, minimum consent and provider-session metadata, category-only support/appeal intake, audit events, and an exported eligibility guard. It still does not include a real provider, authenticated callback verification, authorized manual-review decision API, or any actual protected community controller with the guard applied. Those remain incomplete and must not be claimed as shipped.

## Canonical internal states

| Internal state | API value |
| --- | --- |
| `NOT_VERIFIED` | `notVerified` |
| `VERIFICATION_IN_PROGRESS` | `verificationInProgress` |
| `PENDING_MANUAL_REVIEW` | `pendingManualReview` |
| `VERIFIED` | `verified` |
| `VERIFICATION_FAILED` | `verificationFailed` |
| `TEMPORARILY_RESTRICTED` | `temporarilyRestricted` |
| `REVERIFICATION_REQUIRED` | `reverificationRequired` |

The separate column defaults existing and new accounts to `NOT_VERIFIED`. It does not change `AccountStatus` or the legacy authentication `VerificationStatus`. A client-supplied status is not accepted. Any future writer must validate provider authenticity or reviewer authorization, ownership, allowed transition, and audit requirements before writing the database state.

The transition helper is a domain check only, not a complete workflow. No public endpoint can invoke it to set a status. A transition to `VERIFIED` is restricted to the typed trusted-provider or authorized-reviewer authority; transitions out of manual review require reviewer authority. Tests use synthetic inputs.

## Legal and provider feasibility notes

The official source pages below were checked on 16 October 2026. Their presence in this engineering document does not replace review by Indian counsel.

1. **UIDAI offline verification / OVSE.** UIDAI's OVSE page lists social/community/matchmaking among prominent use cases. UIDAI says an entity may apply to be registered as an OVSE for a lawful purpose and that registration follows UIDAI review. The same page's FAQ states that offline verification cannot be performed on behalf of another entity. This makes it inappropriate to assume that Sakhi can simply consume an arbitrary third-party Aadhaar API. Sakhi has not been approved or registered as an OVSE in this project, and no provider is selected.  
   Sources: [UIDAI — Offline Verification Seeking Entity (OVSE), last updated 6 October 2026](https://www.uidai.gov.in/ta/ovse); [Aadhaar Authentication and Offline Verification Regulations, 2021, as amended](https://www.uidai.gov.in/images/The_Aadhaar_Authentication_and_Offline_Verifications_Regulations_2021-_Clean_copy-30122025.pdf).

2. **Consent and alternative means.** UIDAI's regulations require information about what is shared, the use made of it, and alternate/viable identification; the relevant provisions also address consent and not denying service for refusing or being unable to undergo authentication/offline verification where a viable alternative identification is provided. The exact application to Sakhi's membership eligibility policy requires specific legal advice. The product should not assume Aadhaar-only access is lawful or make a legal conclusion from an identity API's returned `gender` attribute. Counsel must approve the eligibility criterion, affected user groups, alternatives, appeals, and any exceptions before a provider is enabled.  
   Source: [UIDAI regulations PDF](https://www.uidai.gov.in/images/The_Aadhaar_Authentication_and_Offline_Verifications_Regulations_2021-_Clean_copy-30122025.pdf).

3. **DPDP Act commencement is staged.** The MeitY notification dated 13 November 2025 specifies phased commencement. On the date checked, sections 3–17 and other listed processing provisions are scheduled for commencement 18 months after publication (13 May 2027); section 6(9) and section 27(1)(d) are scheduled one year after publication (13 November 2026). Do not treat these future dates as already effective on 16 October 2026, or assume that the phased timing removes obligations under other applicable laws.  
   Source: [MeitY Gazette notification G.S.R. 843(E), 13 November 2025](https://www.meity.gov.in/static/uploads/2025/11/c56ceae6c383460ca69577428d36828b.pdf).

4. **DPDP Rules commencement is also staged.** The final Rules say Rules 1, 2 and 17–21 commenced on publication; Rule 4 commences one year later; Rules 3, 5–16, 22 and 23 commence 18 months later. These dates must be revisited before launch and before collecting personal/identity data.  
   Source: [MeitY Gazette notification G.S.R. 846(E), Digital Personal Data Protection Rules, 2025](https://www.meity.gov.in/static/uploads/2025/11/53450e6e5dc0bfa85ebd78686cadad39.pdf).

5. **Identity API capability is not legal authorization.** A provider documenting demographic or photo attributes in an API response would establish only technical capability. It does not establish that the vendor is authorized for Sakhi's use case, that Sakhi can lawfully require the attribute, or that the response proves the product's eligibility criterion.

## Decisions that remain blocked

Before enabling any real verification, obtain documented confirmation from qualified Indian counsel and the chosen provider/UIDAI (as applicable) on:

- the legal basis and exact criterion being verified, including inclusion/fairness policy;
- lawful provider authorization and whether Sakhi must register directly as an OVSE or satisfy other requirements;
- acceptable non-Aadhaar alternatives, refusal/inability handling, appeal and manual-review criteria;
- precise attributes needed and whether selfie/liveness or biometric processing is necessary and permitted;
- controller/processor roles, consent wording/version, purposes, sharing, security, retention, deletion and grievance handling;
- app-store disclosures and operational/support obligations.

No production credentials, real Aadhaar number, OTP, identity document, selfie, biometric sample, or real user fixture belongs in the development workflow.

## Current safety guarantees and limitations

- Provider configuration remains false; verification start continues to fail closed and no result is fabricated.
- The new database state starts as `NOT_VERIFIED`. It does not mark any account verified.
- The existing phone OTP, account status, session restoration, logout, onboarding, and UI flows are not changed by this backend-only increment.
- The current repository has no protected community API surface to guard yet. Before such endpoints are implemented, their backend authorization must explicitly require the trusted eligibility state `VERIFIED` and reject all other states; client-side UI state is never authorization.
- The transition helper is not wired to a writer yet; a later provider/manual-review increment must use it together with callback authenticity, idempotency/replay protection, authorization, and audit logging.
- The database change is additive and forward-only. Do not reset or recreate a database to apply it.


## Parallel workstream checkpoint — Module 2

**Checkpoint reviewed:** 16 October 2026. Module 2 (User Profile and Account Management) is being developed separately. Keep the two workstreams isolated until a deliberate, reviewed integration stage.

- Mobile profile PR: [#13 — authenticated My Profile editing](https://github.com/siddubond007/women-safety-app/pull/13), head branch `feat/user-profile-account-management`, based on the PR #11 mobile lineage.
- Backend profile PR: [#14 — secure self-service profile API](https://github.com/siddubond007/women-safety-app/pull/14), head branch `feat/user-profile-account-management-backend`, based on the PR #10 backend lineage.
- Both profile PRs were open and unmerged when checked. Their PR descriptions say the tests have not yet been run by the authoring session and the profile migration has not been applied.
- PR #14 does not include PR #12's eligibility-status migration. Its profile migration changes the profile schema independently. Reconcile both migrations, their Prisma schema definitions, and deployment order only during an explicit integration review.

### Isolation rules

- Eligibility work remains on `feat/eligibility-domain-status`; do not edit either Module 2 branch or its checkpoint.
- Module 2 must not modify the eligibility test database `sakhi_test` or the development database `sakhi_dev`.
- Do not independently duplicate the same schema changes in both branches or assume another workstream's commits exist here.
- Keep shared contracts explicit during later integration: authenticated account identity, the profile relation, canonical eligibility status, protected-feature authorization, account deletion/deactivation, audit logging, and retention.
- Preserve unrelated local worktrees and their uncommitted changes. No PR is to be merged without explicit owner approval.

### Eligibility database verification status

The successful migration/build/test output from the original `women_safety_app-backend-live-worktree` checkout was produced on `temp/sakhi-backend-checkpoint-20261016`, not on this eligibility branch. Its migration output reported no pending migrations across two discovered migrations and does not prove that the eligibility migration ran. The isolated eligibility worktree at `D:\Development\Projects\women_safety_app-eligibility-domain-status` was created at commit `3d9889fbc3bf34b833b4278014ed3e9037e6d3fe`; the first reported command was still running `npm ci`. The eligibility migration, build, and tests must be reported only after they are run from that isolated worktree.


## Local verification checkpoint — 16 October 2026

**Reported by the maintainer from the isolated worktree** `D:\Development\Projects\women_safety_app-eligibility-domain-status\backend`:

- Prisma CLI: 7.10.0 under Node.js 24.22.0 — passed.
- Test migration wrapper: targeted `sakhi_test`; Prisma found 4 migration directories and reported `No pending migrations to apply.`
- Build wrapper: Prisma Client generation and TypeScript build completed successfully.
- Automated tests: 7 test files passed; 31 tests passed, 0 skipped; runtime 14.89 seconds.
- Git checkpoint before this verification: `c2d384d0dbb015612eed56cd64ee79ba63dd0ea6`.

**Migration reconciliation still required:** the wrapper's `No pending migrations` output does not identify which migration records exist or prove the expected `member_accounts.eligibility_status` column is present. Run a read-only migration-history/schema check against `sakhi_test` before claiming database verification complete. Do not reset the database or apply the profile migration in this workstream.


## Implementation increment: consent/session boundary and support intake

**Source change checkpoint:** branch `feat/eligibility-domain-status`; current implementation commit is recorded by GitHub. Maintainer tests must be rerun after pulling this increment.

### Added backend components

- `EligibilityProviderAdapter` defines the boundary for an approved provider. The default `UnconfiguredEligibilityProviderAdapter` always reports `providerConfigured=false` and `policyApproved=false`; it cannot create an external session.
- `POST /api/v1/eligibility/start` preserves the current HTTP 409 provider-unavailable response while no approved provider/policy exists. If an adapter is ever enabled, the service requires an authenticated account with a completed profile, an allowed status transition, explicit consent matching the current notice version, separate biometric consent when required, an HTTPS provider redirect, a nonempty opaque provider reference, and a future session expiry.
- `eligibility_consents` records only notice version, server timestamp, biometric-consent boolean and source. `eligibility_verification_sessions` stores only local/provider references, session state and expiry/completion timestamps.
- Provider-start or session-persistence failure marks the local session failed and restores the prior eligibility status, rather than treating a transport failure as an adverse eligibility decision. If supported by a future adapter, cancellation is attempted when a provider session was created but could not be safely persisted.
- `POST /api/v1/eligibility/support-requests` and `GET /api/v1/eligibility/support-requests` are authenticated and scoped to the current session account. They accept only an enumerated category (verification help, manual-review request, accessibility alternative, appeal guidance), store no free-text identity claims/documents, and cap requests at five per account per rolling 24-hour window.
- A support/manual-review request does **not** set `PENDING_MANUAL_REVIEW`, does not change eligibility, and grants no protected access. It is intake metadata only: authorized reviewers and actual decision processing are not implemented.
- `VerifiedEligibilityGuard` checks the backend-loaded eligibility status and allows only `VERIFIED`; it is exported for future protected controllers. No protected community API exists in this increment, so there is not yet an endpoint demonstrating the guard wired end-to-end.
- New migration `20261016140000_eligibility_consent_sessions_support` creates consent/session/support tables and grants the matching local app role only the required select/insert/update operations. It is additive, has account-delete cascade for these newly introduced records, and never stores Aadhaar numbers, OTPs, images or biometric templates.

### API contracts

Support request categories are `verificationHelp`, `manualReviewRequest`, `accessibilityAlternative`, and `appealGuidance`. The start request DTO uses `consentAccepted`, `consentVersion`, and `biometricProcessingConsented`. The consent fields are optional at the transport DTO layer only to maintain the old disabled-provider client contract; when an approved provider is configured, the service requires explicit, matching consent before making the provider call.

### Provider redirect and input minimization

The adapter configuration must explicitly provide `redirectHosts`. Verification start is rejected when that allowlist is empty. When a provider is enabled, its returned URL must be HTTPS, have no embedded username/password, and have a hostname exactly matching one of the configured allowed hosts. The internal account ID is not passed to the provider adapter; only the local opaque session ID, notice version and biometric-consent boolean are supplied as adapter input.

### Remaining blockers and safety boundaries

- No provider is selected/authorized; no provider credentials are present; no real identity data is collected. Production provider activation is blocked by provider and legal approval.
- The provider-specific signature algorithm, freshness window and payload schema remain unimplemented because no provider has been selected or approved. The callback boundary now requires an adapter to authenticate raw bytes and normalize only an allowed result; the unconfigured adapter makes the endpoint unavailable. Event-level replay protection and atomic status processing are implemented for any future approved adapter.
- There is still no authenticated reviewer/RBAC decision flow, appeal decision workflow, retention/deletion job, scheduled session-expiry worker, or active protected community endpoint. These must be implemented before representing the full SRS workflow as complete.
- The adapter must not infer gender from a selfie, name, voice or facial appearance. Phone OTP or Aadhaar OTP success is not an eligibility result.
- Human review decisions remain disabled until reviewer authorization and approved, fair review criteria exist. A category-only request records a request, not an accepted eligibility appeal.
- Shared user/profile contract and schema/migration integration with PRs #13/#14 remains deferred. The profile workstream must not migrate `sakhi_test` while eligibility testing is underway.
- The earlier 31-test passing result predates these source changes and is not validation of this increment. The latest source checkpoint is on `feat/eligibility-domain-status`; maintainer must pull the latest head, run the new migration on `sakhi_test`, then run Prisma validation/build and the complete backend test suite. Database migration history/column existence must be verified separately; no status should be inferred from an older “No pending migrations” message.


## Latest maintainer test run and follow-up fixes — 16 October 2026

The maintainer pulled commit `264c5d0` into the isolated worktree and reported:

- Migration `20261016140000_eligibility_consent_sessions_support` applied successfully to `sakhi_test`.
- Prisma schema validation passed.
- Backend build passed.
- Full test run: 42 passed, 2 failed, 44 total. Both failures were in the new support-request tests: invalid category accepted in the controller test setup, and a stale fixed-ID expectation in the audit assertion.

Follow-up source fixes were committed to `feat/eligibility-domain-status` after that run:

- Controller performs explicit runtime category validation and rejects unexpected body keys even if a bootstrap/test harness omits the global validation pipe.
- The support audit test models the database-generated request ID consistently and checks that the request and audit event share the same ID.
- A newly created provider-start session receives a five-minute startup deadline; stale `CREATED` sessions stop blocking retry after that deadline.

**These follow-up commits have not been validated by the maintainer's local build/tests yet.** Pull the current branch head and rerun Prisma validation, build and the full test suite. The additive migration was reported applied to `sakhi_test` before these follow-up code/test fixes; because the follow-up changes do not alter the Prisma schema or migration, do not reset the database or reapply manually.


## Implementation increment: trusted callback boundary and idempotent result processing

**Source branch:** `feat/eligibility-domain-status`. This increment extends draft PR #12; no PR is merged.

### Implemented in source (local maintainer validation pending)

- Added `POST /api/v1/eligibility/provider-callback`. It is not a member-authenticated route; trust is delegated to the approved provider adapter, which must validate provider-specific signature/authentication and freshness rules over exact raw request bytes before returning a normalized event.
- The bootstrap preserves exact raw request bytes only for this callback route; the payload is not logged or persisted. The provider adapter is responsible for translating only trusted results to `VERIFIED`, `PENDING_MANUAL_REVIEW`, or `VERIFICATION_FAILED`. Ambiguous/unsupported results must map to manual review, not approval.
- The callback boundary stays disabled because the default `UnconfiguredEligibilityProviderAdapter` has no verifier and provider/policy configuration remains false. No generic guessed signature format, credentials, provider, legal approval or result is invented.
- Added an append-only callback event table with a unique provider/event key. Within one database transaction, a trusted callback claims its event, checks the matching non-expired `REDIRECT_READY` session, validates the canonical state transition, updates the account and session, and records a redacted audit event. Concurrent/duplicate deliveries are idempotent.
- Only the normalized outcome and opaque identifiers are persisted. Raw callback payload, raw identity attributes, documents, images and biometrics are not stored. The callback response exposes only accepted/duplicate acknowledgement, not member status.
- New migration: `20261016150000_eligibility_provider_callback_events`. It is additive and grants only matching local app-role SELECT/INSERT on the event table. Apply it only to `sakhi_test` for this check; do not reset databases, apply Module 2 migrations, or change `sakhi_dev`.

### Remaining gaps

- No real provider is selected/authorized. An approved adapter's actual signature algorithm, replay timestamp window, event schema and sandbox integration must be based on that provider's official contract before enabling the endpoint.
- Reviewer authentication/RBAC, manual-review decisions/appeals, scheduled session expiry, retention/deletion jobs and wiring the eligibility guard into actual protected community endpoints remain outstanding.
- This source change is not locally validated yet. The maintainer must pull, apply the new migration to `sakhi_test`, then run Prisma validation, build and the entire backend test suite. Test fixtures are synthetic and do not represent end-to-end verification with a real provider.
