# Sakhi Modules 1–5 — Source Package Manifest

**Package branch:** `sakhi-module1-5-complete-package-20261027`  
**Checkpoint branch:** `checkpoint/module1-5-complete-20261027`  
**Checkpoint commit:** `a14f0a141766a575f1960a9d44f09125d448fd49`  
**Repository:** https://github.com/siddubond007/women-safety-app  
**Package date:** 2026-10-27

## Contents
This distribution archive is based on the committed Module 1–5 checkpoint. It retains the application source, backend, super-admin, Flutter app, assets, tests, configuration templates, migrations, tracked workflows, and ordinary project documentation from that checkpoint.

## Intentionally excluded from this distribution archive
The following internal prompt / handoff material was excluded from this packaging branch only, as requested:
- `GEMINI_MODULE4_REPAIR_PROMPT_20261025.txt`
- `docs/Sakhi_Module4_ChatGPT_Laptop_Master_Prompt.md`
- `docs/GEMINI_HANDOFF_MODULE4_V2_CHECKPOINT_20261025.md`
- `docs/Sakhi_Gemini_Module4_Implementation_Report.md`
- `docs/Sakhi_Gemini_Module4_Integration_Runbook.md`
- `docs/reports/CHECKPOINT_HANDOFF_GEMINI_MODULE4_V2_20261025.md`
- `docs/reports/GEMINI_MODULE4_REPAIR_HANDOFF_20261025.md`

Those exclusions affect only this distribution-package branch. The source checkpoint branch `checkpoint/module1-5-complete-20261027` preserves the files as they existed at the checkpoint, together with their commit history.

## Not embedded in source archive
- Git's internal `.git` history directory is not included in a GitHub source ZIP. Use `git clone --branch checkpoint/module1-5-complete-20261027 https://github.com/siddubond007/women-safety-app.git` when local Git history is required.
- The generated Android staging friend-test APK is a local binary and is not stored in the repository's tracked source tree. Its recorded filename and SHA-256 are in `CHECKPOINT_MODULE1-5_20261027.md`; retrieve the APK separately from the development machine if needed.
- Local-only/untracked files on the Windows workstation could not be inspected because it was offline during this packaging operation.

## Recorded validation status
Prior validation results are recorded in `CHECKPOINT_MODULE1-5_20261027.md`. They are historical results, not a claim that tests were rerun against this packaging-only branch. No code files were changed in making this package branch; only the listed internal prompt/handoff files were excluded and this manifest was added.
