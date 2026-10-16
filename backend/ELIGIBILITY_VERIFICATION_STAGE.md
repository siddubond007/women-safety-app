# Sakhi eligibility verification — backend foundation

**Research checked:** 16 October 2026  
**Implementation scope:** canonical eligibility state model and a fail-closed status boundary. This document is an engineering record, not legal advice.

## Repository audit

The feature builds on the existing provider-neutral Flutter preview and NestJS endpoint family in the eligibility workstream. Current backend behavior before this increment was:

- `GET /api/v1/eligibility/configuration` returns no configured provider or approved policy.
- `GET /api/v1/eligibility/status` requires the authenticated development session and reports provider unavailability.
- `POST /api/v1/eligibility/start` authenticates the caller but returns HTTP 409; it does not create a fake provider session.
- The existing database `verification_status` field only represents the earlier `UNVERIFIED/VERIFIED` flag. It must not be interpreted as the full community eligibility decision.

This increment adds a distinct persisted `eligibility_status`, exposes it separately from the unchanged `providerUnavailable` service result, and defines a transition policy for future trusted backend writers. It does not implement a status-setting endpoint, identity provider, verified outcome, manual-review console, or protected community routes. Those must not be claimed as complete.

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
