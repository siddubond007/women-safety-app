-- Run ONCE in SQL Editor of the new, empty sakhi-friend-testing Supabase project.
-- Replace both placeholders with different, unique 40+ character URL-safe secrets.
-- Never commit actual passwords or paste them into chat.
CREATE ROLE sakhi_staging_migrator WITH LOGIN PASSWORD 'REPLACE_WITH_UNIQUE_40_CHAR_MIGRATOR_SECRET' NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;
CREATE ROLE sakhi_staging_app WITH LOGIN PASSWORD 'REPLACE_WITH_DIFFERENT_40_CHAR_APP_SECRET' NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;

GRANT CONNECT ON DATABASE postgres TO sakhi_staging_migrator, sakhi_staging_app;
GRANT USAGE, CREATE ON SCHEMA public TO sakhi_staging_migrator;
GRANT USAGE ON SCHEMA public TO sakhi_staging_app;

-- Do not give the app role blanket default CRUD privileges. The staging runtime
-- grants are explicit and are applied by bootstrap-staging.ps1/db-migrate.ps1.
