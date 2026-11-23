-- Give the runtime application role only the privileges needed for DM send and retrieval.
-- Message edits/deletes remain unavailable through the general member application role.
DO $grant_direct_message_runtime_permissions$
DECLARE
    app_role TEXT;
BEGIN
    IF current_database() = 'sakhi_dev' THEN
        app_role := 'sakhi_dev_app';
    ELSIF current_database() = 'sakhi_test' THEN
        app_role := 'sakhi_test_app';
    ELSIF current_database() = 'postgres' AND current_user = 'sakhi_staging_migrator' THEN
        -- Staging uses the reviewed runtime-grants.sql after Prisma deployment.
        RETURN;
    ELSE
        RAISE EXCEPTION 'Sakhi direct-message grants may only run on local Sakhi databases or the guarded staging migrator';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = app_role) THEN
        RAISE EXCEPTION 'Required Sakhi runtime role % does not exist', app_role;
    END IF;

    EXECUTE format(
        'GRANT SELECT, INSERT ON TABLE public.direct_messages TO %I',
        app_role
    );
END
$grant_direct_message_runtime_permissions$;