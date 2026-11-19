BEGIN;

-- The trigger function references only OLD/NEW and built-in PL/pgSQL features.
-- Pin its search_path so no caller-controlled schema can shadow object names.
ALTER FUNCTION public.guard_admin_bootstrap_credential_consumption()
  SET search_path = pg_catalog;

DO $verify$
DECLARE configured_path text[];
BEGIN
  SELECT proconfig INTO configured_path
  FROM pg_proc
  WHERE oid = 'public.guard_admin_bootstrap_credential_consumption()'::regprocedure;

  IF configured_path IS NULL
     OR NOT ('search_path=pg_catalog' = ANY(configured_path)) THEN
    RAISE EXCEPTION 'Bootstrap credential trigger function search_path was not pinned';
  END IF;
END
$verify$;

COMMIT;
