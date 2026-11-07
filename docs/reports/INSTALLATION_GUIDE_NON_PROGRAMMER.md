# Sakhi Module 3 — Step-by-Step Installation & Verification Guide (For Non-Programmers)

You do **not** need to edit any code files manually. Follow these numbered steps in Windows PowerShell to install, migrate, and run your upgraded Sakhi application.

## Step 1: Extract the Deliverable Archive
1. Download `SAKHI_MODULE3_COMPLETE_READY_TO_INSTALL.zip` and `Install-Sakhi-Module3.ps1`.
2. Right-click `SAKHI_MODULE3_COMPLETE_READY_TO_INSTALL.zip` and extract it to a folder such as:
   `C:\Users\<YourUsername>\Desktop\Sakhi_Module3_Ready`

## Step 2: Run the Automated Installer (Over Your Existing Repo or Standalone)
Open **Windows PowerShell** and run one of the following commands:

- **Option A — Install into your existing repository (`women-safety-app`) with automatic backup**:
  ```powershell
  cd C:\Users\<YourUsername>\Desktop\Sakhi_Module3_Ready
  powershell -ExecutionPolicy Bypass -File .\Install-Sakhi-Module3.ps1 -TargetRepoPath "C:\path\to\women-safety-app" -ApplyDatabaseMigration
  ```
- **Option B — Run directly inside the extracted folder**:
  ```powershell
  cd C:\Users\<YourUsername>\Desktop\Sakhi_Module3_Ready
  powershell -ExecutionPolicy Bypass -File .\Install-Sakhi-Module3.ps1 -ApplyDatabaseMigration
  ```

### What `Install-Sakhi-Module3.ps1` Does Automatically:
1. Creates a timestamped backup of your existing folders before changing anything.
2. Preserves your local `super-admin/.env.local` and Windows DPAPI database/Google Drive credentials.
3. Switches to (or creates) the Git branch `feature/module3-social-wall` without pushing or force-resetting.
4. Installs backend and Super Admin dependencies and generates the Prisma client.
5. Safely applies the additive Module 3 database migration (`20261019120000_module3_social_wall_and_drive_media`) and idempotent seed on `sakhi_dev` (never touching `marketplacedb`).
6. Runs the automated verification checks.

## Step 3: Verify Database & Google Drive Environment (Optional Standalone Check)
At any time, you can verify that `sakhi_dev` is healthy, `marketplacedb` is untouched, and Google Drive credentials are loaded by running:
```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verification\Verify-Sakhi-DatabaseAndEnvironment.ps1 -Environment dev
```

## Step 4: Start the Backend Server (Port 3001)
In **PowerShell Window 1**, start the NestJS backend:
```powershell
cd C:\path\to\women-safety-app
powershell -ExecutionPolicy Bypass -File .\backend\scripts\start-dev.ps1
```
Wait until you see:
- `Sakhi DEV/TEST ONLY mode: OTP codes are echoed to the local app; no SMS is sent.`
- `Super Admin Reviewer Token (dev): sakhi-local-dev-super-admin-token-2026`

## Step 5: Start the Super Admin Portal (Port 5173)
In **PowerShell Window 2**, start the Super Admin web portal:
```powershell
cd C:\path\to\women-safety-app\super-admin
npm.cmd run dev
```
1. Open `http://127.0.0.1:5173` in your browser.
2. Enter Reviewer Token: `sakhi-local-dev-super-admin-token-2026` (or `ADMIN2026TEST`).
3. Visit:
   - **Community & Feed (`/community`)**: Toggle, reorder, or inspect the 6 SRS 5.3 categories (`Following`, `Community`, `Trending`, `Business Updates`, `Safety Awareness`, `Wellness and Lifestyle`), moderate posts/comments, and inspect Google Drive `MediaAsset` paths.
   - **Moderation Queue (`/moderation`)**: Review reported posts/comments and record moderation decisions (`Remove Post`, `Remove Comment`, `Restrict Member`, `Dismiss`).
   - **Integrations & Health (`/integrations`)**: Click **Verify Remote Google Drive** to confirm live OAuth connectivity and folder hierarchy (`Sakhi Media/users/{opaqueUserId}/profile` and `Sakhi Media/feeds/{categorySlug}/{opaqueUserId}/{postId}`).

## Step 6: Build & Install the Android Debug APK Over USB
In **PowerShell Window 3**, connect your Android phone via USB with USB Debugging enabled:
```powershell
cd C:\path\to\women-safety-app\app
adb reverse tcp:3001 tcp:3001
flutter pub get
flutter build apk --debug --dart-define=SAKHI_BACKEND_ENABLED=true --dart-define=SAKHI_API_BASE_URL=http://127.0.0.1:3001/api/v1
adb install -r build\app\outputs\flutter-apk\app-debug.apk
```

## Step 7: End-to-End Manual Walkthrough Checklist
1. **Sign In**: Enter `+91 9000012345` (pre-seeded verified test identity `Siddhu`) or register a new number and approve it in Super Admin (`/verifications`).
2. **Profile Photo & Default Women Avatars (`Profile` -> `Edit Profile`)**:
   - Tap the camera badge on your avatar.
   - Notice there is **no URL paste box**: you can choose from **12 distinct illustrated women avatars** OR pick a real photo from your device gallery/camera to upload to `Sakhi Media/users/{opaqueUserId}/profile/`.
3. **Social Wall Categories (`Social Wall` tab)**:
   - Switch between **Following**, **Community**, **Trending**, **Business Updates**, **Safety Awareness**, and **Wellness and Lifestyle**.
4. **Instagram-Style Post Composer**:
   - Tap the composer bar or photo icon -> select a photo from your device gallery -> switch between **`1:1`**, **`4:5`**, and **`16:9`** aspect-ratio crops with live pan/zoom preview -> add a caption, hashtags, category, and visibility -> tap **Publish to Social Wall**.
5. **Reactions, Comments, Edit/Delete & Confidential Reporting**:
   - Tap **React +** on any post to test the 8 reactions (`Like`, `Love`, `Support`, `Inspired`, `Happy`, `Grateful`, `Strong`, `Care`).
   - Open comments to post, edit, or delete your comment.
   - Tap `•••` on your own post to **Edit** or **Delete** it; tap `•••` on another member's post to **Report Post** or **Block** the author, then view the report in Super Admin (`/moderation`).
