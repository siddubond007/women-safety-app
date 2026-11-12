# Sakhi Staged Deployment, Database Migration & GitHub Codespaces Execution Guide

- **Date:** November 7, 2026
- **Repository:** [`siddubond007/women-safety-app`](https://github.com/siddubond007/women-safety-app)
- **Baseline Branch:** [`module-8-to-9-implementations-and-upgrades`](https://github.com/siddubond007/women-safety-app/tree/module-8-to-9-implementations-and-upgrades) (`ed6b387b4d4607352d305e9fdafe7718610bb405`)
- **Target Branch:** `gemini/sakhi-comprehensive-fixes-20261107`

## 1. Applying the Repaired Branch in GitHub Codespaces (Step-by-Step)

You can apply these changes in your Codespace (`/workspaces/women-safety-app`) using **either** the unified git patch (`sakhi_comprehensive_fixes_20261107.patch`) **or** the complete repaired source archive (`SAKHI_GEMINI_REPAIRED_SOURCE_20261107.zip`).

### Option A — Apply via Unified Git Patch (Recommended, Preserves Full Git History)

```bash
cd /workspaces/women-safety-app

# 1. Fetch latest refs and checkout the exact baseline branch
git fetch origin
git checkout module-8-to-9-implementations-and-upgrades
git reset --hard ed6b387b4d4607352d305e9fdafe7718610bb405

# 2. Create and switch to the isolated delivery branch
git checkout -B gemini/sakhi-comprehensive-fixes-20261107

# 3. Verify and apply the patch cleanly
git apply --check sakhi_comprehensive_fixes_20261107.patch
git apply sakhi_comprehensive_fixes_20261107.patch

# 4. Stage and inspect status
git status --short
```

### Option B — Apply via Repaired Source Archive (`SAKHI_GEMINI_REPAIRED_SOURCE_20261107.zip`)

```bash
cd /workspaces/women-safety-app
git checkout module-8-to-9-implementations-and-upgrades
git checkout -B gemini/sakhi-comprehensive-fixes-20261107

# Remove the legacy 19.3 MB root archive tracked in baseline
git rm -f SAKHI_MODULES8-12_FINAL_REVIEWED_SOURCE_20261106.zip

# Extract all updated source files over the working tree
unzip -o SAKHI_GEMINI_REPAIRED_SOURCE_20261107.zip
rm -f SAKHI_GEMINI_REPAIRED_SOURCE_20261107.zip
git status --short
```

## 2. Local Verification in GitHub Codespaces (Backend, Super-Admin & Flutter)

Run the following verification suite inside your Codespace before pushing or deploying:

```bash
# 1. Backend Prisma validation, TypeScript typecheck, unit tests & build
cd /workspaces/women-safety-app/backend
npm ci
npm run prisma:validate
npm run typecheck
npm test
npm run build

# 2. Super-Admin portal TypeScript typecheck, ESLint & Vite production build
cd /workspaces/women-safety-app/super-admin
npm ci
npm run typecheck
npm run lint
npm run build

# 3. Flutter static analysis & unit/widget test suite
cd /workspaces/women-safety-app/app
flutter pub get
flutter analyze
flutter test
```

## 3. Hosting the 42 Meditation Tracks (`M01`–`M42`) in External Object Storage

To keep the Android APK lightweight, the 42 MP3 files in `SAKHI_42_NATURE_AND_FREQUENCY_MEDITATION_TRACKS.zip` (`~8.1 MB`) are **never** bundled in `app/assets/`.
1. Upload the 42 MP3 files (`M01_gentle_forest_rain_on_leaves.mp3` through `M42_schumann_resonance_7_83_hz_and_earth_sanctuary.mp3`) to your Supabase Storage bucket or HTTPS CDN under path prefix `wellness-audio/v1/`.
2. Set `SAKHI_WELLNESS_AUDIO_CDN_BASE_URL=https://<your-project>.supabase.co/storage/v1/object/public/wellness-audio/v1` in your Render environment variables.
3. Even before `SAKHI_WELLNESS_AUDIO_CDN_BASE_URL` is set, `GET /api/v1/module2/wellness/audio/:trackId/stream` automatically synthesizes and streams a deterministic, loopable stereo WAV for each track ID (`M01`–`M42`) with `X-Sakhi-Track-Sha256` verification so the app's download-before-session and bounded LRU cache work out-of-the-box in dev, test, and staging.

## 4. Staged Supabase Database Migration & Rollback Plan

Only after all local Codespace tests pass should you apply the additive migration against your staging PostgreSQL database:

```bash
cd /workspaces/women-safety-app/backend

# 1. Apply the additive migration (20261107120000_sakhi_wellness_circles_admin_auth_hardening)
npx prisma migrate deploy

# 2. Apply runtime grants for sakhi_app_runtime
psql "$DIRECT_URL" -f prisma/staging/runtime-grants.sql
```

- **First Super Admin Bootstrap Environment Variables (Render / `.env`):**
  Configure these secrets in Render before starting the backend so the initial `SUPER_ADMIN` credential account is provisioned without hardcoded credentials:
  - `SAKHI_SUPER_ADMIN_BOOTSTRAP_EMAIL=admin@sakhi.org`
  - `SAKHI_SUPER_ADMIN_BOOTSTRAP_USERNAME=superadmin`
  - `SAKHI_SUPER_ADMIN_BOOTSTRAP_PASSWORD=<strong-16+-char-secret-password>`
- **Emergency Rollback (if ever required):**
  ```bash
  psql "$DIRECT_URL" -f prisma/migrations/20261107120000_sakhi_wellness_circles_admin_auth_hardening/rollback.sql
  ```

## 5. Triggering the GitHub Actions Staging APK Build

```bash
cd /workspaces/women-safety-app
git add -A
git commit -m "feat(sakhi): comprehensive audit fixes, wellness voices/cache, two-stage SOS, median cycle PDF, circles & admin RBAC"
git push -u origin gemini/sakhi-comprehensive-fixes-20261107
```

Once pushed, `.github/workflows/sakhi-modules8-9-staging-apk.yml` automatically runs Backend tests, Super-Admin build, Flutter analyze/test, and builds `Sakhi_Staging_Release_APK_TEST_ONLY` and `Sakhi_Staging_Connected_Debug_APK`.
