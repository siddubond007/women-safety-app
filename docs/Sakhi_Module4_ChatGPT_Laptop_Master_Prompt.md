# Copy-Paste Master Prompt for ChatGPT / Gemini Laptop Agent (Token-Safe, Step-by-Step Execution with Module 3 Checkpoint, UTF-8 Symbol Repair & Module 4 Live Deployment)

Copy everything inside the section below and paste it as your **first message** to ChatGPT / Gemini / Codex on your laptop (along with having `Sakhi_Gemini_Module4_Updated_Source.zip` in your `Downloads` folder or project folder).

---

## Master Prompt to Copy & Paste into ChatGPT / Gemini on Your Laptop

You are an autonomous Principal Full-Stack, Flutter, NestJS, Prisma/Supabase, and React/TypeScript Engineer operating directly on my Windows laptop via terminal / remote desktop commands.

Your mission is to:
1. **First save and commit a clean Git Checkpoint of my current working Modules 1–3 directory** so none of my existing work is ever lost.
2. **Create a new Git branch (`feat/sakhi-module4-safety-sos`)** and extract/apply the complete **Module 4 (Emergency SOS & Personal Safety)** update from `Sakhi_Gemini_Module4_Updated_Source.zip` so my app matches the **9 Module 4 Reference UI Screens** 1:1 (including all reusable icons/illustrations and the **Discord-style 168 Animated Women Quotations Loader** that replaces plain circular loading spinners).
3. **Fix all corrupted / garbled / Chinese / special alphabet characters (UTF-8 mojibake)** across my local codebase (such as `Next â€º`, `â€¹ Back`, `â€¹ Discard`, `Continue`, post timestamp bullets `Â·` / `â€¢`, `1 active device(s) Â· Bangalore`, `Couldnâ€™t`, `Sharingâ€¦`, or any UTF-16/Windows-1252 garbled CJK characters).
4. **Verify, test, migrate Supabase, and create a final Module 4 Git Checkpoint & Android APK**.

### CRITICAL TOKEN-LIMIT & STEP-BY-STEP EXECUTION RULES (MANDATORY)

1. **EXECUTE ONLY ONE STEP PER TURN**: Because of strict token limits, you MUST NEVER try to run multiple steps in a single turn. Execute **only the current Step**, run its **Mandatory Bug & Error Check**, and **STOP IMMEDIATELY**.
2. **ALWAYS USE STRICT UTF-8 ENCODING ON WINDOWS**: Never use plain PowerShell `Get-Content` or `Set-Content` without UTF-8 encoding (which corrupts bullets `•`, arrows `›`, em-dashes `—`, and quotes into `Â·`, `â€º`, or Chinese symbols). Whenever reading or writing files in PowerShell or Node, ALWAYS use `[System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)` and `[System.IO.File]::WriteAllText($path, $content, [System.Text.UTF8Encoding]::new($false))`.
3. **MANDATORY BUG CHECK & STOP SIGNAL AFTER EVERY STEP**: At the end of each Step, run the verification check listed in that Step, fix any issue found right away, and end your message with the exact line:
   `STEP [X] COMPLETED & VERIFIED (0 BUGS). Reply "continue" to proceed to Step [X+1].`
4. **WAIT FOR MY PERMISSION**: Do NOT start the next Step until I reply `continue`.

---

### STEP-BY-STEP EXECUTION PLAN (DO ONLY STEP 1 NOW, THEN WAIT FOR "continue")

#### STEP 1 — Locate Local Repo, Create Full Folder Backup & Save Module 3 Git Checkpoint
In this first turn, do ONLY the following:
1. Search my laptop (`Desktop`, `Documents`, `Downloads`, `C:\Users\*`) to locate:
   - My active local **Sakhi** Git repository directory (containing `app/`, `backend/`, `super-admin/`, and `.git`).
   - The downloaded `Sakhi_Gemini_Module4_Updated_Source.zip` archive (and optionally `Sakhi_Module_4_All_UI_Reference_Images.zip`).
2. Create a full timestamped folder backup of my current working repo (`app`, `backend`, `super-admin`, `scripts`, `docs`) in the parent directory named `Sakhi_Checkpoint_Module3_Backup_<timestamp>`.
3. Inside my local Sakhi Git repository, save a permanent **Module 3 Git Checkpoint** before making any Module 4 changes:
   - Ensure `.env`, `.env.local`, and any credential files are ignored in `.gitignore`.
   - Run `git status`. If there are uncommitted Module 1–3 changes, run:
     ```powershell
     git add -A
     git commit -m "checkpoint(module3): save working Modules 1 to 3 state before Module 4"
     ```
   - Create a Git checkpoint tag:
     ```powershell
     git tag -f checkpoint-module-3-complete
     ```
4. Now create and switch to the new Module 4 feature branch:
   ```powershell
   git checkout -B feat/sakhi-module4-safety-sos
   ```
5. **Bug Check for Step 1**: Confirm `git branch --show-current` outputs `feat/sakhi-module4-safety-sos`, `git tag -l "checkpoint-module-3-complete"` exists, and the backup folder exists.
6. **STOP** and reply: `STEP 1 COMPLETED & VERIFIED (0 BUGS). Reply "continue" to proceed to Step 2.`

---

#### STEP 2 — Extract `Sakhi_Gemini_Module4_Updated_Source.zip` & Copy Module 4 Assets + Source Files Safely
When I reply `continue` after Step 1, do ONLY the following:
1. Extract `Sakhi_Gemini_Module4_Updated_Source.zip` into a clean temporary folder `$env:TEMP\Sakhi_Module4_Extracted` using `Expand-Archive -Force`.
2. Copy the updated folders from `$env:TEMP\Sakhi_Module4_Extracted` into my local Sakhi repository (`app/`, `backend/`, `super-admin/`, `scripts/`, `docs/`, `render.yaml`, and `Deploy-Sakhi-Module4-Branch.ps1`), **strictly preserving** my existing `backend/.env`, `super-admin/.env.local`, and `%LOCALAPPDATA%\Sakhi\credentials\*`.
3. Verify that all Module 4 reusable asset folders are present in my repo:
   - `app/assets/module4/illustrations/` (7 standalone high-res & transparent cutout assets: `emblem_sakhi_safety_shield_lotus_transparent.png`, `button_sos_pulsing_shield_pin_hero_transparent.png`, `emblem_112_emergency_shield_phone_transparent.png`, `avatar_trusted_contact_female_transparent.png`, `bg_reusable_pastel_safety_map_canvas.jpg`, `illustration_commute_and_cab_safety.jpg`, `illustration_using_discreet_sos_safely.jpg`)
   - `app/assets/module4/icons_png/` (`ic_01` through `ic_12` `@3x` PNGs)
   - `app/assets/module4/icons_svg/` (`ic_01` through `ic_22` SVGs)
   - `app/assets/module4/components_png/` & `app/assets/module4/components_svg/`
   - `app/assets/module4/sakhi_women_quotes.json` (168 curated women quotations)
4. **Bug Check for Step 2**: Verify all asset files exist on disk and match `app/pubspec.yaml` and `app/lib/core/assets/app_assets.dart`.
5. **STOP** and reply: `STEP 2 COMPLETED & VERIFIED (0 BUGS). Reply "continue" to proceed to Step 3.`

---

#### STEP 3 — Scan & Fix All Chinese Symbols, Special Alphabet Glitches & Mojibake (`Next ›`, `Continue`, Post Time `•`, etc.) Across All Screens
When I reply `continue` after Step 2, do ONLY the following:
1. Run a Node.js UTF-8 sanitizer across the entire `app/lib/`, `app/test/`, `backend/src/`, and `super-admin/src/` directories to detect and fix any corrupted encoding / mojibake characters (caused when UTF-8 bytes were previously saved as Windows-1252 or UTF-16LE, producing garbled symbols or Chinese characters on buttons like `"Next"`, `"Continue"`, `"Back"`, `"Discard"`, post timestamps `"•"`, and `"1 active device(s) • Bangalore"`):
   ```powershell
   node -e '
   const fs = require("fs");
   const path = require("path");
   const map = [
     ["\u00e2\u20ac\u201d", "\u2014"], // â€” -> —
     ["\u00e2\u20ac\u201c", "\u2013"], // â€“ -> –
     ["\u00e2\u20ac\u00a2", "\u2022"], // â€¢ -> •
     ["\u00c2\u00b7", "\u2022"],       // Â·  -> •
     ["\u00e2\u20ac\u2122", "\x27"],   // â€™ -> '\''
     ["\u00e2\u20ac\u02dc", "\x27"],   // â€˜ -> '\''
     ["\u00e2\u20ac\u0153", "\""],     // â€œ -> "
     ["\u00e2\u20ac\u009d", "\""],     // â€  -> "
     ["\u00e2\u20ac\u00a6", "..."],    // â€¦ -> ...
     ["\u00e2\u20ac\u00b9", "\u2039"], // â€¹ -> ‹
     ["\u00e2\u20ac\u00ba", "\u203a"], // â€º -> ›
     ["\u00c3\u2014", "\u00d7"],       // Ã—  -> ×
     ["\ufffd", ""]
   ];
   function walk(dir) {
     for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
       const full = path.join(dir, entry.name);
       if (entry.isDirectory()) walk(full);
       else if (/\.(dart|ts|tsx|css|html)$/.test(entry.name)) {
         let txt = fs.readFileSync(full, "utf8");
         let orig = txt;
         for (const [bad, good] of map) txt = txt.split(bad).join(good);
         // Strip any accidental CJK mojibake characters in UI strings
         txt = txt.replace(/[\u3000-\u9fff\uf900-\ufaff]+/g, "");
         if (txt !== orig) {
           fs.writeFileSync(full, txt, "utf8");
           console.log("Sanitized UTF-8 in:", full);
         }
       }
     }
   }
   ["app/lib", "app/test", "backend/src", "super-admin/src"].forEach(walk);
   '
   ```
2. Also inspect `app/lib/features/community/screens/sakhi_post_creation_flow.dart`, `app/lib/features/community/widgets/feed_post_card.dart`, `app/lib/features/settings/screens/privacy_settings_screen.dart`, `app/lib/features/explore/screens/explore_discovery_screens.dart`, and `app/lib/features/auth/` to confirm:
   - Top-right `"Next ›"`, `"‹ Back"`, `"‹ Discard"`, and `"Continue"` buttons render clean text with zero garbled symbols.
   - Post timestamps (`6 hours ago • Community`) and Active Login Sessions (`1 active device(s) • Bangalore (Current)`) render clean bullets (`•`).
3. **Bug Check for Step 3**: Run a check confirming `0` mojibake or CJK characters remain anywhere in `app/lib/`, `backend/src/`, or `super-admin/src/`.
4. **STOP** and reply: `STEP 3 COMPLETED & VERIFIED (0 BUGS). Reply "continue" to proceed to Step 4.`

---

#### STEP 4 — Verify Backend Prisma Schema, Staging Baseline Audit & Backend Build/Tests
When I reply `continue` after Step 3, do ONLY the following:
1. Open a terminal in `backend/` and run:
   ```powershell
   node .\scripts\audit-staging-baseline.cjs
   npx prisma generate
   npm run build
   npm test -- --runInBand
   ```
2. Verify that:
   - `audit-staging-baseline.cjs` prints `Baseline audit passed`.
   - All Module 4 endpoints (`/api/v1/module2/quotes`, `/safety/overview`, `/safety/police-stations`, `/safety/sos/activate`, `/safety/sos/:id/cancel`, `/safety/sos/:id/resolve`, `/safety/contacts`, `/safety/location-shares`, `/safety/track/:token`, and `/api/v1/admin-review/safety-console`) compile cleanly.
3. **Bug Check for Step 4**: If any TypeScript or test issue appears on my local Node setup, fix it immediately and re-run until 100% green.
4. **STOP** and reply: `STEP 4 COMPLETED & VERIFIED (0 BUGS). Reply "continue" to proceed to Step 5.`

---

#### STEP 5 — Verify Super-Admin SOS Console (Screen 8) & Animated Women Quotations Loader Build
When I reply `continue` after Step 4, do ONLY the following:
1. Open a terminal in `super-admin/` and run:
   ```powershell
   npm run build
   ```
2. Confirm that `SafetyConsolePage.tsx` (Reference Screen 8 on `/emergency`) and `SakhiQuoteLoader.tsx` compile cleanly with zero TypeScript or Vite bundling errors.
3. **Bug Check for Step 5**: Confirm `super-admin/dist/` was generated with 0 errors.
4. **STOP** and reply: `STEP 5 COMPLETED & VERIFIED (0 BUGS). Reply "continue" to proceed to Step 6.`

---

#### STEP 6 — Verify All 9 Module 4 Flutter UI Screens, 168 Animated Women Quotations Loader & Run `flutter analyze` + `flutter test`
When I reply `continue` after Step 5, do ONLY the following:
1. Open a terminal in `app/` and run:
   ```powershell
   flutter pub get
   flutter analyze
   flutter test
   ```
2. Confirm that:
   - **All 9 Module 4 Reference UI Screens** (`SafetyScreen`, `SosWorkflowScreen`, `NearestPoliceStationsScreen`, `EmergencyContactsScreen`, `ShareLiveLocationScreen`, `AddTrustedContactSheet`, `SafetyHistoryAndSettingsScreen`, `HelplinesAndSafetyTipsScreen`, and `sakhi_module4_theme.dart`) and the **Discord-style 168 Animated Women Quotations Loader (`SakhiQuoteLoader`)** pass analysis and widget tests (`module4_safety_and_quotes_test.dart`, `module2_screens_test.dart`, `auth_flow_test.dart`, `sakhi_create_hub_test.dart`, `backend_api_client_test.dart`).
3. **Bug Check for Step 6**: If my local Flutter SDK flags any lint or deprecation warning, fix it cleanly without altering the UI design and re-run `flutter analyze` and `flutter test` until 0 issues remain.
4. **STOP** and reply: `STEP 6 COMPLETED & VERIFIED (0 BUGS). Reply "continue" to proceed to Step 7.`

---

#### STEP 7 — Apply Additive Module 4 Database Migration & Save Module 4 Git Checkpoint Commit
When I reply `continue` after Step 6, do ONLY the following:
1. Apply the additive Module 4 database schema changes (`safety_location_shares`, `verified_police_stations`, `safety_helpline_configs`, and new columns on `safety_emergency_contacts` and `safety_sos_events`) to my configured database (or print the idempotent SQL block from `docs/Sakhi_Gemini_Module4_Integration_Runbook.md` if I need to paste it into Supabase SQL Editor).
2. Inside my Sakhi Git repository, verify no `.env` or secret files are staged, then create the **Module 4 Git Checkpoint Commit**:
   ```powershell
   git add -A
   git commit -m "feat(module4): implement Emergency SOS & Personal Safety UI, live endpoints, Super-Admin console, UTF-8 fixes, and 168 animated women quotations loader"
   git tag -f checkpoint-module-4-complete
   ```
3. Push the branch to GitHub if remote `origin` is configured:
   ```powershell
   git push -u origin feat/sakhi-module4-safety-sos
   ```
4. **Bug Check for Step 7**: Verify `git status` is clean and both `checkpoint-module-3-complete` and `checkpoint-module-4-complete` tags exist.
5. **STOP** and reply: `STEP 7 COMPLETED & VERIFIED (0 BUGS). Reply "continue" to proceed to Step 8.`

---

#### STEP 8 — Build Final Android APK & Run Live End-to-End Smoke Verification
When I reply `continue` after Step 7, do ONLY the following:
1. Build my updated Android APK in `app/`:
   ```powershell
   cd app
   flutter build apk --release --dart-define=SAKHI_API_BASE_URL=https://sakhi-staging-api.onrender.com/api/v1
   ```
   (If I am testing against my local backend on port 3001, also let me know or build with the configured API URL.)
2. Print the exact file path to the generated `.apk` (`app\build\app\outputs\flutter-apk\app-release.apk`) and a final verification summary confirming:
   - Module 3 checkpoint (`checkpoint-module-3-complete`) is saved.
   - Module 4 checkpoint (`checkpoint-module-4-complete`) is saved on branch `feat/sakhi-module4-safety-sos`.
   - All Chinese/mojibake character glitches (`Next ›`, `Continue`, post timestamps `•`, active sessions `•`) are fixed.
   - All 9 Module 4 UI screens + the 168 Discord-style animated women quotations loader are live in the APK.
3. Output: `STEP 8 COMPLETED. ALL MODULE 4 TASKS & APK BUILD FINISHED!`
