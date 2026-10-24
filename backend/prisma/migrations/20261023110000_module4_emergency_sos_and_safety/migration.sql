ALTER TABLE "safety_emergency_contacts" ADD COLUMN "is_primary" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "safety_emergency_contacts" ADD COLUMN "alert_enabled" BOOLEAN NOT NULL DEFAULT true;

ALTER TABLE "safety_sos_events" ADD COLUMN "latitude" DOUBLE PRECISION;
ALTER TABLE "safety_sos_events" ADD COLUMN "longitude" DOUBLE PRECISION;
ALTER TABLE "safety_sos_events" ADD COLUMN "is_test_mode" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "safety_sos_events" ADD COLUMN "contacts_alerted_count" INTEGER NOT NULL DEFAULT 0;
ALTER TABLE "safety_sos_events" ADD COLUMN "share_token" VARCHAR(80);
ALTER TABLE "safety_sos_events" ADD COLUMN "resolved_at" TIMESTAMPTZ(6);

CREATE TABLE "safety_location_shares" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "account_id" UUID NOT NULL,
  "share_token" VARCHAR(80) NOT NULL,
  "status" VARCHAR(32) NOT NULL DEFAULT 'ACTIVE',
  "duration_label" VARCHAR(40) NOT NULL DEFAULT '1 Hour',
  "include_profile" BOOLEAN NOT NULL DEFAULT true,
  "include_timestamp" BOOLEAN NOT NULL DEFAULT true,
  "latitude" DOUBLE PRECISION NOT NULL,
  "longitude" DOUBLE PRECISION NOT NULL,
  "accuracy_meters" DOUBLE PRECISION,
  "battery_percent" INTEGER,
  "location_label" VARCHAR(160),
  "stopped_at" TIMESTAMPTZ(6),
  "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "safety_location_shares_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "verified_police_stations" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "station_code" VARCHAR(64) NOT NULL,
  "name" VARCHAR(160) NOT NULL,
  "address" VARCHAR(300) NOT NULL,
  "city" VARCHAR(80) NOT NULL DEFAULT 'Bengaluru',
  "state" VARCHAR(80) NOT NULL DEFAULT 'Karnataka',
  "latitude" DOUBLE PRECISION NOT NULL,
  "longitude" DOUBLE PRECISION NOT NULL,
  "phone_number" VARCHAR(40) NOT NULL,
  "emergency_number" VARCHAR(20) NOT NULL DEFAULT '112',
  "is_women_station" BOOLEAN NOT NULL DEFAULT false,
  "is_verified" BOOLEAN NOT NULL DEFAULT true,
  "updated_by" VARCHAR(120),
  "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "verified_police_stations_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "safety_helpline_configs" (
  "code" VARCHAR(40) NOT NULL,
  "number" VARCHAR(32) NOT NULL,
  "title" VARCHAR(160) NOT NULL,
  "subtitle" VARCHAR(255) NOT NULL,
  "category" VARCHAR(64) NOT NULL DEFAULT 'EMERGENCY',
  "is_enabled" BOOLEAN NOT NULL DEFAULT true,
  "display_order" INTEGER NOT NULL DEFAULT 1,
  "updated_by" VARCHAR(120),
  "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "safety_helpline_configs_pkey" PRIMARY KEY ("code")
);

CREATE UNIQUE INDEX "safety_location_shares_share_token_key" ON "safety_location_shares"("share_token");
CREATE INDEX "safety_location_shares_account_status_idx" ON "safety_location_shares"("account_id", "status");
CREATE UNIQUE INDEX "verified_police_stations_station_code_key" ON "verified_police_stations"("station_code");
CREATE INDEX "verified_police_stations_city_verified_idx" ON "verified_police_stations"("city", "is_verified");

ALTER TABLE "safety_location_shares"
  ADD CONSTRAINT "safety_location_shares_account_id_fkey"
  FOREIGN KEY ("account_id") REFERENCES "member_accounts"("id")
  ON DELETE CASCADE ON UPDATE CASCADE;
