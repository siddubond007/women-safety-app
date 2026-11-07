# Sakhi — Women's Safety, Community & Wellness Application

A full-stack Flutter + NestJS + PostgreSQL application for women's safety, community connection, and everyday wellbeing.

## Repository Layout

- `app/` — Flutter client targeting Android, iOS, and Web (`Stage 1` Onboarding, Mobile-first OTP Auth & Eligibility Verification + `Module 2` 12-screen main application shell).
- `backend/` — NestJS + Prisma 7 + PostgreSQL API (`AuthModule`, `EligibilityModule`, `AdminReviewModule`, and `Module2Module`).
- `super-admin/` — React + TypeScript + Vite administrative portal for reviewing eligibility submissions and member states.

## Module 2 Integrated Screens (12 Screens)

1. **Home Dashboard (`HomeScreen`)** — Personalized greeting banner, search bar, 4 quick actions (`Explore`, `Community`, `Wellness`, `SOS`), and "For You Today" cards.
2. **Explore & Community (`ExploreScreen`)** — Expandable search, 5 filter chips, trending hashtag chips, 2x2 category grid, and recommended posts.
3. **Community Feed (`CommunityScreen`)** — Feed filter selector, post creation (`+` button), interactive Like, Comment, Save, Share, and Report actions backed by PostgreSQL.
4. **Wellness Hub (`WellnessScreen`)** — "Your Wellbeing Matters" hero card, 4 wellness category tiles, interactive "Guided Meditation" audio card, and daily affirmation quote.
5. **Safety & SOS (`SafetyScreen`)** — Shield emblem header, SOS trigger dialog & database event logging, radar map card, 4 circular safety categories, and quick safety actions (Live Location Share, Safety Checklist, Helpline Directory).
6. **Profile Overview (`ProfileScreen`)** — Botanical header banner, avatar with camera badge, verified badge, `Posts` / `Followers` / `Following` counters, bio, location, interests, and `Posts` / `Saved` / `Groups` tabs.
7. **Edit Profile (`EditProfileScreen`)** — Botanical sprigs flanking avatar, validated Display Name, Bio, Location, and Interest chip editor persisted to PostgreSQL (`PUT /api/v1/module2/profile`).
8. **Privacy Settings (`PrivacySettingsScreen`)** — 6 privacy controls persisted to `member_privacy_preferences` (`PUT /api/v1/module2/privacy`).
9. **Notification Preferences (`NotificationPreferencesScreen`)** — 7 independent switches persisted to `member_notification_preferences` (`PUT /api/v1/module2/notifications`).
10. **Followers & Following (`FollowersFollowingScreen`)** — Searchable follower directory and interactive `Follow` / `Following` toggle persisted to `member_follows` (`POST /api/v1/module2/followers/:id/toggle`).
11. **Account & Security (`AccountSecurityScreen`)** — Verified phone number, email address, active login sessions count, PIN update, 2FA toggle, account deactivation, and deletion dialogs.
12. **More Options / Menu (`MoreOptionsMenuScreen`)** — My Groups, My Saved Posts, Business Profile link, Help & Support, Report a User, Blocked Users, Terms & Conditions, Privacy Policy, and About Sakhi (v1.0.0).

## Quick Start (Live Local Testing on Windows)

### 1. Apply Database Migrations & Seed (`backend/`)

```powershell
cd "D:\Development\Projects\GEMINI WORKING ON MODULE 2\backend"
npm install
.\scripts\db-migrate.ps1 -Environment dev
.\scripts\seed.ps1 -Environment dev
```

*(Note: `seed.ps1` seeds a ready-to-test verified account for **Siddhu** with mobile number `+91 9999992222`, along with all reference Community posts, Groups, Followers, and Wellness resources).*

### 2. Start the Local Backend API (`backend/`)

```powershell
cd "D:\Development\Projects\GEMINI WORKING ON MODULE 2\backend"
.\scripts\start-dev.ps1 -Environment dev
```

### 3. Run the Flutter App (`app/`)

- **With Live Local Backend (`sakhi_dev` PostgreSQL)**:
  ```powershell
  cd "D:\Development\Projects\GEMINI WORKING ON MODULE 2\app"
  flutter pub get
  flutter run --dart-define=SAKHI_BACKEND_ENABLED=true --dart-define=SAKHI_API_BASE_URL=http://127.0.0.1:3000/api/v1
  ```
  Sign in with `+91` and mobile number `9999992222` (enter the 6-digit development OTP displayed on screen), then tap **Continue to Sakhi home** to enter the 12-screen Module 2 experience backed by PostgreSQL.

- **Standalone UI / Demo Mode (No Backend Required)**:
  ```powershell
  cd "D:\Development\Projects\GEMINI WORKING ON MODULE 2\app"
  flutter pub get
  flutter run
  ```
  After completing the demo OTP step, tap **Open Sakhi Module 2 UI (12 Screens)** on the status screen (or navigate directly via the `+` button quick switcher).
