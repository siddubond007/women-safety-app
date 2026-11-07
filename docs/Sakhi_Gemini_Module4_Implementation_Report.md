# Sakhi — Module 4 (Emergency SOS & Personal Safety) + Discord-Style Animated Women Quotations Loader Implementation Report

## 1. Executive Summary

This report documents the end-to-end engineering implementation of **Module 4: Emergency SOS & Personal Safety** (SRS Section 6.1–6.6) and the **Discord-Style Animated Women Quotations Loader (168 Curated Quotations)** across the **Sakhi** Flutter mobile application (`app/`), NestJS/Prisma backend (`backend/`), PostgreSQL/Supabase staging baseline (`backend/prisma/`), and React/TypeScript Super-Admin portal (`super-admin/`).

## 2. 9-Screen Module 4 Visual & Functional Exactness Checklist

| Screen # | Reference UI Image | Implemented Code File | Reusable Assets Wired | Status |
| :--- | :--- | :--- | :--- | :--- |
| **Screen 1** | `01_Safety_Hub_Main_Dashboard_UI.jpg` | `app/lib/features/safety/screens/safety_screen.dart` (`SafetyScreen`) | `emblem_sakhi_safety_shield_lotus_transparent.png`, `bg_reusable_pastel_safety_map_canvas.jpg`, `button_sos_pulsing_shield_pin_hero_transparent.png`, `ic_01`–`ic_08` `@3x` PNGs, `SakhiQuoteLoader.banner()` | Verified |
| **Screen 2** | `02_SOS_Confirmation_3s_and_Active_Workflow_UI.jpg` | `app/lib/features/safety/screens/safety_screen.dart` (`SosWorkflowScreen`) | 3-second countdown ring (`03s`), `Trigger SOS Now`, `Cancel (I'm Safe)`, verified workflow steps, amber police integration compliance notice, `Call 112`, `Call 100`, `Stop Location Sharing & End SOS` | Verified |
| **Screen 3** | `03_Nearest_Police_Stations_and_Verified_Directory_UI.jpg` | `app/lib/features/safety/screens/safety_screen.dart` (`NearestPoliceStationsScreen`) | Mandatory amber non-notification disclaimer banner, map with blue GPS dot & police pins (`0.8 km`, `1.4 km`, `2.1 km`), station cards with `Directions / Navigate` & `Call Station`, `SakhiQuoteLoader.inline()` | Verified |
| **Screen 4** | `04_Emergency_Contacts_and_Location_Link_UI.jpg` | `app/lib/features/safety/screens/safety_screen.dart` (`EmergencyContactsScreen`) | `avatar_trusted_contact_female_transparent.png`, `Primary Contact` plum badge, `Selected for SOS Alert` toggles, primary contact guardrail, live tracking link card, `Stop Location Sharing` | Verified |
| **Screen 5** | `05_Share_Live_Location_and_Add_Contact_Modal_UI.jpg` | `app/lib/features/safety/screens/safety_screen.dart` (`ShareLiveLocationScreen` & `AddTrustedContactSheet`) | Live map with avatar pin, `GPS High Accuracy` pill, `15 Mins / 1 Hour / Until I Stop` pills, consent checkboxes, `+91` 10-digit validated contact form | Verified |
| **Screen 6** | `06_Safety_History_Discreet_Shortcut_and_Checklist_UI.jpg` | `app/lib/features/safety/screens/safety_screen.dart` (`SafetyHistoryAndSettingsScreen`) | Power-button & shake shortcut toggles, `Run Safe Test Mode (Avoid False Triggers)`, chronological SOS history log cards, interactive Pre-Travel Safety Checklist | Verified |
| **Screen 7** | `07_Verified_Helplines_112_and_Safety_Tips_UI.jpg` | `app/lib/features/safety/screens/safety_screen.dart` (`HelplinesAndSafetyTipsScreen`) | `emblem_112_emergency_shield_phone_transparent.png`, `112` & `100` emergency call buttons, `1091` / `181` / `108` / `1930` cards (`ic_09`–`ic_11`), `illustration_commute_and_cab_safety.jpg`, `illustration_using_discreet_sos_safely.jpg` | Verified |
| **Screen 8** | `08_SOS_Administration_Console_UI.jpg` | `super-admin/src/pages/SafetyConsolePage.tsx` | Role-restricted Admin Console with audit-log security notice, 2x2 metrics, 6 Section 6.6 governance modules, live Police Station Directory sync form, and SOS false-trigger review queue | Verified |
| **Screen 9** | `09_Module_4_Design_System_and_Component_Sheet_UI.jpg` | `app/lib/features/safety/theme/sakhi_module4_theme.dart` | Complete color tokens (`#FDF8FB`, `#5A1868`, `#C92A49`, `#1E7E55`, `#8A5300`), radii, dimensions, and asset bindings | Verified |

## 3. Discord-Style Animated Women Quotations Loader (168 Curated Quotations)

- **Flutter Widget (`app/lib/core/widgets/sakhi_quote_loader.dart`) & JSON Dataset (`app/assets/module4/sakhi_women_quotes.json`)**:
  - Contains **168 curated quotations** about women's strength, sisterhood, leadership, safety, wellness, and Indian & global women trailblazers (Savitribai Phule, Sarojini Naidu, Kalpana Chawla, Rani Lakshmibai, Sudha Murty, Mary Kom, Kiran Bedi, Captain Lakshmi Sahgal, Tessy Thomas, Ritu Karidhal, P. V. Sindhu, Bachendri Pal, Arunima Sinha, Amrita Pritam, Maya Angelou, Malala Yousafzai, Marie Curie, Ruth Bader Ginsburg, Audre Lorde, Frida Kahlo, and Sakhi Safety Tips).
  - Replaces plain `CircularProgressIndicator` loading screens in `main.dart` (`SakhiStartupRouter`, `SakhiProtectedHomeGate`), `community_screen.dart`, `profile_screen.dart`, `followers_following_screen.dart`, `explore_discovery_screens.dart`, and `safety_screen.dart` with a Discord-style animated card featuring the Sakhi Shield-Lotus emblem, category badge (`#id/168`), smooth fade/slide transition (`AnimatedSwitcher`), progress bar, and tap-to-cycle `"Inspire me with another quote"` interaction.
  - Also implemented in the Super-Admin web portal (`super-admin/src/components/SakhiQuoteLoader.tsx`) and served from the backend via `GET /api/v1/module2/quotes`.

## 4. Backend API Endpoints & Database Schema Additions

### Backend Routes (`Module2Controller` & `AdminReviewController`)
- `GET /api/v1/module2/quotes?category=...` — Returns the 168 curated women's quotations.
- `GET /api/v1/module2/safety/overview` — Returns authenticated member's emergency contacts, SOS history, active live location share, and nearby verified police stations.
- `GET /api/v1/module2/safety/police-stations?lat=...&lng=...&radiusMeters=5000` — Queries live OpenStreetMap Overpass API (`amenity=police`) with a 3.5s timeout and merges with PostgreSQL `verified_police_stations` sorted by Haversine distance (`km`).
- `POST /api/v1/module2/safety/sos/activate` — Records an active or `TEST_MODE` SOS event, creates a live location tracking token, and writes an immutable `audit_events` record.
- `POST /api/v1/module2/safety/sos/:eventId/cancel` & `POST /api/v1/module2/safety/sos/:eventId/resolve` — Updates SOS event lifecycle status and logs to `audit_events`.
- `POST /api/v1/module2/safety/contacts`, `PATCH /api/v1/module2/safety/contacts/:contactId`, `DELETE /api/v1/module2/safety/contacts/:contactId` — Full CRUD for up to 5 trusted contacts with primary contact support.
- `POST /api/v1/module2/safety/location-shares`, `PATCH /api/v1/module2/safety/location-shares/:token/ping`, `POST /api/v1/module2/safety/location-shares/:token/stop` — Manages real-time location sharing sessions.
- `GET /api/v1/module2/safety/track/:token` — Renders a zero-cost, self-contained **Leaflet.js + OpenStreetMap** live tracking web page for family members in any browser.
- `GET /api/v1/admin-review/safety-console`, `POST /api/v1/admin-review/police-stations`, `POST /api/v1/admin-review/sos-events/:eventId/review` — Role-restricted Super-Admin SOS Console endpoints with mandatory audit logging.

### Database Migration (`20261023110000_module4_emergency_sos_and_safety`)
- Added `is_primary` and `alert_enabled` columns to `safety_emergency_contacts`.
- Added `latitude`, `longitude`, `is_test_mode`, `contacts_alerted_count`, `share_token`, and `resolved_at` columns to `safety_sos_events`.
- Created `safety_location_shares`, `verified_police_stations`, and `safety_helpline_configs` tables with indexes, foreign keys, static seeds, and `sakhi_staging_app` runtime grants.
- Verified `node backend/scripts/audit-staging-baseline.cjs` passes 100%.
