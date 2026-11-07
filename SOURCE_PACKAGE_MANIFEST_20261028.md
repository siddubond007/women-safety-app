# Sakhi Modules 1–5 — Complete Source Package

**Package branch:** `sakhi-module1-5-complete-package-20261028`

**Source branch tested on staging:** `feat/module5-and-rbac-admin-panels-20261027`

**Source commit:** `67eb8b3f063f3b52de2f30acf7b37d7db5dd909d`

**Source commit message:** `fix(admin): accept generated staff tokens in staging login`

**Repository:** https://github.com/siddubond007/women-safety-app

**Package date:** 2026-10-28

## Included

The tracked project source from the stated source commit, including the Flutter app, assets and tests; NestJS backend, Prisma schema/migrations and tests; Super Admin frontend; iOS and Android project files; configuration templates; project scripts; deployment configuration; GitHub workflows; and normal project documentation.

## Excluded from this distribution package

These internal prompt/handoff/runbook/AI-process files were removed from this package branch only:

- `GEMINI_MODULE4_REPAIR_PROMPT_20261025.txt`
- `docs/Sakhi_Module4_ChatGPT_Laptop_Master_Prompt.md`
- `docs/GEMINI_HANDOFF_MODULE4_V2_CHECKPOINT_20261025.md`
- `docs/Sakhi_Gemini_Module4_Implementation_Report.md`
- `docs/Sakhi_Gemini_Module4_Integration_Runbook.md`
- `docs/reports/CHECKPOINT_HANDOFF_GEMINI_MODULE4_V2_20261025.md`
- `docs/reports/GEMINI_MODULE4_REPAIR_HANDOFF_20261025.md`
- `docs/reports/GEMINI_ACCEPTANCE_MATRIX_20261027.md`

This packaging operation does not delete those files from the source branch or alter the tested staging branch, `main`, or any checkpoint branch.

## Excluded by design

- Git history metadata (`.git`) is not part of a GitHub-generated branch ZIP.
- Local secrets and untracked files (including local `.env.local` files) are not included in this committed source snapshot.
- Installed dependencies, generated build/cache directories, local diagnostic files, and generated APK binaries are not included. Install dependencies using the package lockfiles before building.

## Verification note

This is a source distribution based on the exact committed staging branch snapshot where the staff-token login fix was tested successfully by the project owner. No application source code was edited for packaging; only the internal files listed above were excluded and this manifest was added. Tests were not rerun as a part of the packaging-only operation.
