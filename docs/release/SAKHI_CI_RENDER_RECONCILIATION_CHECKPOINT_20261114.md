# Sakhi CI and Render Alignment Checkpoint — 2026-11-14

## Checkpoint purpose
Record the verified source heads and successful GitHub Actions validation for stacked PRs #39 and #40. This checkpoint is a separate branch; it does not merge either pull request.

## Source commits
- PR #39 head: `8e4d18440bbe10826d0d674dc21f4a5be28c5442` (`fix/staging-p0-managed-role-preflight-20261113`)
- PR #40 head: `76f2350bee639911c2eb0d7449161f18a04142a9` (`fix/sakhi-runtime-db-isolation-20261113`)
- PR #40 is stacked on PR #39.
- Both PRs were verified open, unmerged, and mergeable at checkpoint creation.

## CI verification
All jobs passed on the latest retry attempt (attempt 2):

| Workflow run | Event/source | Head SHA | Backend | Super Admin | Flutter + APK |
|---|---|---|---|---|---|
| 43567487314 | PR #39 push | 8e4d18440bbe10826d0d674dc21f4a5be28c5442 | success | success | success |
| 43567506690 | PR #40 push | 76f2350bee639911c2eb0d7449161f18a04142a9 | success | success | success |
| 43567510454 | PR #40 pull_request | 76f2350bee639911c2eb0d7449161f18a04142a9 | success | success | success |

### Uploaded APK artifacts
- Run 43567487314: `Sakhi_Staging_Connected_Debug_APK`, artifact ID `14103935367`, 98,099,960 bytes.
- Run 43567506690: `Sakhi_Staging_Connected_Debug_APK`, artifact ID `14102784005`, 98,100,017 bytes.
- Run 43567510454: `Sakhi_Staging_Connected_Debug_APK`, artifact ID `14103386949`, 98,100,015 bytes.
- All three artifacts were reported unexpired at verification time.

## Included CI/source remediation
- Added the stacked PR base branches to the validation workflow branch filters and included `render.yaml` in relevant path filters.
- Corrected the Render blueprint API branch declaration to `release/staging-apk-hosted-20261112`; Admin branch declaration remains `module-8-to-9-implementations-and-upgrades`.
- Fixed the compact onboarding viewport spacing regression in `app/lib/features/onboarding/sakhi_onboarding_screen.dart`; the narrow-screen regression test remains enabled.
- PR #39 addresses managed Supabase role migration preflight.
- PR #40 addresses runtime RLS identity, MFA audit binding, retention/deletion lifecycle, and related integration coverage.

## Safety and scope
- No PR was merged.
- No Render deployment was triggered and no live Render service settings were changed during this checkpoint operation.
- No live Supabase database mutation or live Google Drive object operation was performed as part of this checkpoint.
- No infrastructure spend or paid-tier change was initiated.
- This checkpoint records CI and source alignment only; it is not a declaration that the application is production-ready.

## Remaining release gates
- Review and explicitly merge the stacked PRs in the intended order (#39, then #40) only after approval.
- Complete staging Super Admin/staff MFA provisioning and verify the live MFA flow.
- Execute the real staging retention worker and verify retention/deletion lifecycle behavior end to end.
- Complete Admin and member end-to-end testing against staging.
- Verify a final staging APK's runtime configuration, package identity, signing certificate, and install/launch behavior on a device.
- Produce the consolidated release handoff only after these gates pass.
