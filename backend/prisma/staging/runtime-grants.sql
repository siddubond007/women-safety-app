-- Run as sakhi_staging_migrator after the baseline has been applied.
-- Keep schema ownership and migration rights separate from the API role.
GRANT USAGE ON SCHEMA public TO sakhi_staging_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO sakhi_staging_app;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public TO sakhi_staging_app;
GRANT USAGE ON ALL TYPES IN SCHEMA public TO sakhi_staging_app;
REVOKE CREATE ON SCHEMA public FROM sakhi_staging_app;
REVOKE ALL ON TABLE public._prisma_migrations FROM sakhi_staging_app;
