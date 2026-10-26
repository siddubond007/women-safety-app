# Gemini / New Chat Prompt — Continue Sakhi Module 5 from the Exact Saved State

You are continuing the existing Sakhi women-safety application project. Do not start over or perform a broad rewrite. First read the attached source ZIP, this prompt, and `SAKHI_MODULE5_HANDOFF_20261026.md`. If the Git bundle is attached, use it to inspect branch history and checkpoints. If you cannot run Git or the project locally, say that plainly and perform the source review from the provided files without inventing test results.

## Exact resume context

- Repository: https://github.com/siddubond007/women-safety-app
- Windows source root: `D:\Development\Projects\women_safety_app`
- Flutter app: `D:\Development\Projects\women_safety_app\app`
- Active work branch: `feat/sakhi-module5-discreet-complaints-complete`
- Module 5 implementation/deployed baseline: `162c050c20013c35eb2ebcb536b7bf7bf4e7d89c`
- Latest code-release checkpoint: `checkpoint/sakhi-module5-friend-test-release-2026-10-26`
- Staging branch: `feat/sakhi-ui-modules-1-to-3`
- Staging API: `https://sakhi-staging-api.onrender.com/api/v1`
- The handoff files may be added in a docs-only follow-up commit. Therefore, verify the exact final HEAD with `git rev-parse HEAD`; do not assume the docs-only HEAD is the code deployed on staging.
- Project stack: Flutter/Dart mobile app; NestJS/TypeScript backend; PostgreSQL; Prisma; Super Admin frontend.

## Your mission

Continue finishing and validating Module 5's discreet complaints feature with precise, minimal changes. Preserve the working implementation of Modules 1–4 and avoid regressions. The current baseline is ready for *controlled staging friend testing*, but not public production release. Your first job is to audit exactly what remains, then implement only justified gaps with tests and evidence.

### Step 1 — Confirm the real baseline before editing

Inspect Git status, current branch, HEAD, the latest commits, checkpoint refs, working trees, and the relevant Module 5 code/tests/docs. If operating on the Windows development machine, inspect the existing files and branch state before changing anything. Preserve `.sakhi_module3_agent_state.txt` exactly; it is a historical, untracked Module 3 agent-state note, not Module 5 implementation code. Do not blindly stage it.

Use live GitHub refs when possible; local remote-tracking refs can be stale. Never run `git reset --hard`, `git clean -fd`, or destructive cleanup to make the tree look clean. Preserve dirty or untracked user work.

### Step 2 — Audit remaining Module 5 requirements

Review the full flow across Flutter, backend API/service/validation, persistence, and Super Admin complaint management. Verify complaint categories, discreet/privacy-sensitive behavior, API authorization, status handling, and user-facing error/loading/success states against the actual project requirements. Do not infer a requirement that is not in the repo/docs; state uncertainty.

Known gaps that need explicit attention:
1. Full in-app OTP verification/login tap-through has not been completed because emulator input/IME became unstable. The independent OTP endpoint smoke test did pass. Reproduce safely using a reliable emulator/physical device, and distinguish a genuine app/backend defect from emulator failure.
2. Backend DB integration suites were skipped in the prior validation. Investigate an isolated test DB/test runner; never touch the marketplace DB and never run migrations or destructive DB operations without explicit authorization.
3. Public-production readiness is separate: package ID is still `com.example.women_safety_app`, current APK is debug-signed, Terms/Privacy version values are draft, and the current APK is compiled with `SAKHI_STAGING_TEST_MODE=true`. Do not claim production readiness and do not silently make a production build.

### Step 3 — Implement carefully

- Work on `feat/sakhi-module5-discreet-complaints-complete` or make a new, explicitly named feature branch if the audit warrants isolation.
- Preserve the existing friend-test release checkpoint and all previous checkpoints.
- Do not reimplement already-working features. Make the smallest focused changes supported by requirements/tests.
- Maintain the project architecture, theme/design system, assets, navigation, API conventions, and module boundaries.
- Keep staging-only testing switches restricted to staging. Never hardcode secrets or an OTP value in code, logs, documents, examples, or ZIPs.
- Do not change database permissions, modify the marketplace DB, or run Prisma migrations/destructive commands without asking.
- Do not merge into `main` or deploy to production. A safe staging deployment may be considered only after tests pass and its effect on current friend testers is understood.

### Step 4 — Verify and report truthfully

Run the checks that are relevant and possible:
- Backend tests and build; `npx prisma validate` only (no migration).
- Flutter `analyze` and full test suite.
- Super Admin `npm run lint` and `npm run build`.
- `git diff --check`.
- Read-only staging API smoke tests; protect secrets and do not create persisted fake complaint records without approval.

Prior baseline results on 2026-10-26 were: backend 99 passed / 3 skipped; backend build passed; Prisma validation passed; Flutter analyze passed; full Flutter tests passed; Super Admin lint/build passed; staging health and complaints categories returned HTTP 200; protected complaints admin endpoint returned HTTP 401 without a session (expected). DB integration cases were skipped. Verify again rather than assuming these results still hold.

For every skipped or blocked check, state why. Do not claim that the OTP UI path or full end-to-end flow passed unless it was actually completed. Record modified files, test commands and results, current HEAD, checkpoint name, and staging deployment commit.

### Step 5 — Save and checkpoint the work

When changes are validated:
- Review `git diff` and status carefully.
- Commit only intentional, relevant files; do not include secrets or unrelated state files.
- Create a descriptive dated checkpoint branch and push the feature/checkpoint branches where authorized and fast-forward-safe.
- Preserve the friend-test checkpoint as an immutable reference; never force-push it.
- Provide a concise handoff report so a new chat can resume without redoing completed work.

## Staging APK reference

The Windows Downloads folder contains:
- `Sakhi_Module5_Staging_Friend_Test_20261026.apk`
- `Sakhi_Module5_Friend_Test_Package_20261026.zip`
- `Sakhi_Module5_Friend_Test_Guide_20261026.txt`
- `Sakhi_Module5_Release_Verification_20261026.txt`
- `Sakhi_Module5_Staging_Friend_Test_20261026.sha256`

The APK SHA-256 is `B197F3BC7825C8BB42E989E1FCFC9C21FC0835358D6373E70DCEAD5C7EBD9A38`. It uses the staging API, package ID `com.example.women_safety_app`, version 1.0.0 (versionCode 1), minSdk 24, targetSdk 36, and Android Debug-certificate signing. It is a staging APK, not a production artifact.

The designated shared staging test phone is `+91 9999992222`. The OTP value is secret: an authorized maintainer must retrieve it privately from Render's `SAKHI_STAGING_TEST_OTP_CODE` variable. Do not ask me to paste it into this prompt and never reveal it.

## First response required

Before modifying code, give me:
1. The verified branch, HEAD, and status.
2. A short summary of what Module 5 already implements.
3. A prioritized list of remaining Module 5 gaps and risks, distinguishing verified defects from unverified behavior and production-only blockers.
4. The exact validation steps you will run.

Then proceed step by step within these guardrails. Do not ask me to repeat facts already stated here, and do not claim to have run tests or commands you could not run.
