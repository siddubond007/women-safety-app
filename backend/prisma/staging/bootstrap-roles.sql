-- Run ONCE in SQL Editor of the new, empty sakhi-friend-testing Supabase project.
-- Replace both placeholders with different, unique 40+ character URL-safe secrets.
-- Never commit actual passwords or paste them into chat.
CREATE ROLE sakhi_staging_migrator WITH LOGIN PASSWORD 'REPLACE_WITH_UNIQUE_40_CHAR_MIGRATOR_SECRET' NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;
CREATE ROLE sakhi_staging_app WITH LOGIN PASSWORD 'REPLACE_WITH_DIFFERENT_40_CHAR_APP_SECRET' NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;

GRANT CONNECT ON DATABASE postgres TO sakhi_staging_migrator, sakhi_staging_app;
GRANT USAGE, CREATE ON SCHEMA public TO sakhi_staging_migrator;
GRANT USAGE ON SCHEMA public TO sakhi_staging_app;

ALTER DEFAULT PRIVILEGES FOR ROLE sakhi_staging_migrator IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO sakhi_staging_app;
ALTER DEFAULT PRIVILEGES FOR ROLE sakhi_staging_migrator IN SCHEMA public GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO sakhi_staging_app;
ALTER DEFAULT PRIVILEGES FOR ROLE sakhi_staging_migrator IN SCHEMA public GRANT USAGE ON TYPES TO sakhi_staging_app;
