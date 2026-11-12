-- Confidential workflows whose authorization is not a simple member owner_id:
-- complaint retrieval is passkey-gated in ComplaintsService, and provider
-- callbacks are provider-signature-gated before persistence. RLS restricts
-- these tables to Sakhi backend roles; it intentionally does not claim
-- per-member row isolation for anonymous/passkey-authenticated complaint rows.
ALTER TABLE public.discreet_complaints ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.discreet_complaints FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS discreet_complaints_sakhi_backend_only
  ON public.discreet_complaints;
CREATE POLICY discreet_complaints_sakhi_backend_only
ON public.discreet_complaints
FOR ALL TO PUBLIC
USING (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app'))
WITH CHECK (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app'));

ALTER TABLE public.eligibility_provider_callback_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.eligibility_provider_callback_events FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS eligibility_provider_callback_events_backend_only
  ON public.eligibility_provider_callback_events;
CREATE POLICY eligibility_provider_callback_events_backend_only
ON public.eligibility_provider_callback_events
FOR ALL TO PUBLIC
USING (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app'))
WITH CHECK (current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app'));

DO $confidential_table_postflight$
DECLARE table_name text;
BEGIN
  FOREACH table_name IN ARRAY ARRAY[
    'discreet_complaints','eligibility_provider_callback_events'
  ] LOOP
    IF NOT EXISTS (
      SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
      WHERE n.nspname='public' AND c.relname=table_name
        AND c.relrowsecurity AND c.relforcerowsecurity
    ) THEN
      RAISE EXCEPTION 'Confidential backend-only RLS is not forced on public.%',table_name;
    END IF;
  END LOOP;
END
$confidential_table_postflight$;
