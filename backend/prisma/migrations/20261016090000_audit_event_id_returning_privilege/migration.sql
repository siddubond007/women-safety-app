-- Prisma's OTP audit create operation returns only the generated ID.
-- PostgreSQL requires SELECT privilege for columns returned by INSERT.
-- Grant that single-column privilege to the matching local runtime role only.
DO $grant_audit_event_id_select$
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

    EXECUTE format(
      'GRANT SELECT (id) ON TABLE public.audit_events TO %I',
      app_role
    );
END
$grant_audit_event_id_select$;
