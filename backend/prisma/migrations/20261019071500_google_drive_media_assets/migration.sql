CREATE TABLE "media_assets" (
    "id" UUID NOT NULL,
    "account_id" UUID NOT NULL,
    "purpose" VARCHAR(16) NOT NULL,
    "provider" VARCHAR(32) NOT NULL DEFAULT 'google_drive',
    "drive_file_id" VARCHAR(255) NOT NULL,
    "file_name" VARCHAR(180) NOT NULL,
    "content_type" VARCHAR(64) NOT NULL,
    "size_bytes" INTEGER NOT NULL,
    "media_url" VARCHAR(512) NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "media_assets_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "media_assets_account_id_fkey"
        FOREIGN KEY ("account_id") REFERENCES "member_accounts"("id")
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT "media_assets_purpose_check"
        CHECK ("purpose" IN ('avatar', 'post')),
    CONSTRAINT "media_assets_provider_check"
        CHECK ("provider" = 'google_drive'),
    CONSTRAINT "media_assets_content_type_check"
        CHECK ("content_type" IN ('image/jpeg', 'image/png', 'image/webp')),
    CONSTRAINT "media_assets_size_bytes_check"
        CHECK ("size_bytes" > 0 AND "size_bytes" <= 10485760)
);

CREATE UNIQUE INDEX "media_assets_drive_file_id_key"
    ON "media_assets"("drive_file_id");

CREATE INDEX "media_assets_account_purpose_created_idx"
    ON "media_assets"("account_id", "purpose", "created_at");

DO $grant_media_asset_permissions$
DECLARE
    app_role TEXT;
BEGIN
    IF current_database() = 'sakhi_dev' THEN
        app_role := 'sakhi_dev_app';
    ELSIF current_database() = 'sakhi_test' THEN
        app_role := 'sakhi_test_app';
    ELSE
        RAISE EXCEPTION 'Sakhi migrations may only run on sakhi_dev or sakhi_test';
    END IF;

    EXECUTE format('GRANT USAGE ON SCHEMA public TO %I', app_role);
    EXECUTE format('GRANT SELECT, INSERT ON TABLE media_assets TO %I', app_role);
END
$grant_media_asset_permissions$;
