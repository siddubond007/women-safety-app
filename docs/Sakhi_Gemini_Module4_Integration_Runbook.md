# Sakhi — Module 4 Non-Programmer Integration & Deployment Runbook

This step-by-step guide walks you through applying the Module 4 (Emergency SOS & Personal Safety + 168 Animated Women Quotations Loader) update to your Supabase database, Render backend, Super-Admin portal, and Flutter Android APK.

## Step 1 — Apply the Idempotent Module 4 SQL in Supabase SQL Editor

Open your **Supabase Dashboard -> SQL Editor -> New Query**, paste the complete SQL block below, and click **Run**. It is 100% idempotent (`IF NOT EXISTS` / `ON CONFLICT DO NOTHING`) and never deletes any existing member accounts or posts:

```sql
BEGIN;

ALTER TABLE public.safety_emergency_contacts
  ADD COLUMN IF NOT EXISTS is_primary BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS alert_enabled BOOLEAN NOT NULL DEFAULT true;

ALTER TABLE public.safety_sos_events
  ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS is_test_mode BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS contacts_alerted_count INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS share_token VARCHAR(80),
  ADD COLUMN IF NOT EXISTS resolved_at TIMESTAMPTZ(6);

CREATE TABLE IF NOT EXISTS public.safety_location_shares (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  account_id UUID NOT NULL,
  share_token VARCHAR(80) NOT NULL,
  status VARCHAR(32) NOT NULL DEFAULT 'ACTIVE',
  duration_label VARCHAR(40) NOT NULL DEFAULT '1 Hour',
  include_profile BOOLEAN NOT NULL DEFAULT true,
  include_timestamp BOOLEAN NOT NULL DEFAULT true,
  latitude DOUBLE PRECISION NOT NULL DEFAULT 12.9716,
  longitude DOUBLE PRECISION NOT NULL DEFAULT 77.6412,
  accuracy_meters DOUBLE PRECISION NOT NULL DEFAULT 8.5,
  battery_percent INTEGER NOT NULL DEFAULT 81,
  location_label VARCHAR(160),
  stopped_at TIMESTAMPTZ(6),
  created_at TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT safety_location_shares_pkey PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.verified_police_stations (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  station_code VARCHAR(64) NOT NULL,
  name VARCHAR(160) NOT NULL,
  address VARCHAR(300) NOT NULL,
  city VARCHAR(80) NOT NULL DEFAULT 'Bengaluru',
  state VARCHAR(80) NOT NULL DEFAULT 'Karnataka',
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  phone_number VARCHAR(40) NOT NULL,
  emergency_number VARCHAR(20) NOT NULL DEFAULT '112',
  is_women_station BOOLEAN NOT NULL DEFAULT false,
  is_verified BOOLEAN NOT NULL DEFAULT true,
  updated_by VARCHAR(120),
  created_at TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT verified_police_stations_pkey PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.safety_helpline_configs (
  code VARCHAR(40) NOT NULL,
  number VARCHAR(32) NOT NULL,
  title VARCHAR(160) NOT NULL,
  subtitle VARCHAR(255) NOT NULL,
  category VARCHAR(64) NOT NULL DEFAULT 'EMERGENCY',
  is_enabled BOOLEAN NOT NULL DEFAULT true,
  display_order INTEGER NOT NULL DEFAULT 1,
  updated_by VARCHAR(120),
  created_at TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT safety_helpline_configs_pkey PRIMARY KEY (code)
);

CREATE UNIQUE INDEX IF NOT EXISTS safety_location_shares_share_token_key
  ON public.safety_location_shares(share_token);
CREATE INDEX IF NOT EXISTS safety_location_shares_account_status_idx
  ON public.safety_location_shares(account_id, status);
CREATE UNIQUE INDEX IF NOT EXISTS verified_police_stations_station_code_key
  ON public.verified_police_stations(station_code);
CREATE INDEX IF NOT EXISTS verified_police_stations_city_verified_idx
  ON public.verified_police_stations(city, is_verified);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'safety_location_shares_account_id_fkey'
  ) THEN
    ALTER TABLE public.safety_location_shares
      ADD CONSTRAINT safety_location_shares_account_id_fkey
      FOREIGN KEY (account_id) REFERENCES public.member_accounts(id)
      ON DELETE CASCADE ON UPDATE CASCADE;
  END IF;
END $$;

INSERT INTO public.verified_police_stations
  (id, station_code, name, address, city, state, latitude, longitude, phone_number, emergency_number, is_women_station, is_verified, updated_by)
VALUES
  (gen_random_uuid(), 'ps_indiranagar', 'Indiranagar Police Station', '12th Main Rd, HAL 2nd Stage, Bengaluru', 'Bengaluru', 'Karnataka', 12.9719, 77.6412, '+91 80-2294-2548', '112', FALSE, TRUE, 'staging-static-config'),
  (gen_random_uuid(), 'ps_ulsoor_women', 'Ulsoor All-Women Police Station', 'Old Madras Rd, Ulsoor, Bengaluru', 'Bengaluru', 'Karnataka', 12.9815, 77.6285, '+91 80-2294-2550', '112', TRUE, TRUE, 'staging-static-config'),
  (gen_random_uuid(), 'ps_cubbon_park', 'Cubbon Park Police Station', 'Kasturba Rd, Bengaluru', 'Bengaluru', 'Karnataka', 12.9763, 77.5993, '+91 80-2294-2570', '112', FALSE, TRUE, 'staging-static-config')
ON CONFLICT (station_code) DO NOTHING;

INSERT INTO public.safety_helpline_configs
  (code, number, title, subtitle, category, is_enabled, display_order, updated_by)
VALUES
  ('112', '112', '112 — India National Emergency Number', '24/7 Police, Fire & Medical Emergency Response (ERSS)', 'NATIONAL_EMERGENCY', TRUE, 1, 'staging-static-config'),
  ('100', '100', '100 — Direct Police Control Room', '24/7 Immediate Police Dispatch Across India', 'POLICE', TRUE, 2, 'staging-static-config'),
  ('1091', '1091', '1091 — Women in Distress Helpline', 'Police Women Safety Cell • Toll-Free', 'WOMEN_SAFETY', TRUE, 3, 'staging-static-config'),
  ('181', '181', '181 — Women Domestic & Safety Helpline', '24/7 Support & Counselling', 'WOMEN_SAFETY', TRUE, 4, 'staging-static-config'),
  ('108', '108', '108 / 1930 — Medical Ambulance (108) & Cyber Crime (1930)', 'Emergency medical & online fraud support', 'MEDICAL_CYBER', TRUE, 5, 'staging-static-config')
ON CONFLICT (code) DO NOTHING;

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE
  public.safety_emergency_contacts,
  public.safety_sos_events,
  public.safety_location_shares,
  public.verified_police_stations,
  public.safety_helpline_configs
TO sakhi_staging_app;

COMMIT;
```

## Step 2 — Run the One-Command PowerShell Branch Installer on Your Laptop

1. Extract `Sakhi_Gemini_Module4_Updated_Source.zip` into a folder on your laptop (for example `C:\Users\Siddhu\Downloads\Sakhi_Module4_Update`).
2. Open PowerShell in that folder and run:

```powershell
.\Deploy-Sakhi-Module4-Branch.ps1 -TargetRepoPath "C:\path\to\your\Sakhi" -BranchName "feat/sakhi-module4-safety-sos" -PushBranch
```

## Step 3 — Build Your Updated Android APK Pointed at Your Live Render Backend

```powershell
cd C:\path\to\your\Sakhi\app
flutter pub get
flutter build apk --release --dart-define=SAKHI_API_BASE_URL=https://sakhi-staging-api.onrender.com/api/v1
```

Your release APK will be generated at `app\build\app\outputs\flutter-apk\app-release.apk`.
