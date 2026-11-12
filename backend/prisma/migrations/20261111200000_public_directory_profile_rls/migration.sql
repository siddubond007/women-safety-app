-- Stage C: the directory is a deliberately small public-profile projection.
-- It must never be used as an unrestricted mirror of member_accounts/profiles.
ALTER TABLE public.community_directory_profiles
  ADD COLUMN IF NOT EXISTS account_id uuid,
  ADD COLUMN IF NOT EXISTS searchable boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS profile_visibility varchar(32) NOT NULL DEFAULT 'HIDDEN',
  ADD COLUMN IF NOT EXISTS posts_visibility varchar(64) NOT NULL DEFAULT 'Verified members only',
  ADD COLUMN IF NOT EXISTS message_visibility varchar(64) NOT NULL DEFAULT 'Verified members only';

DO $directory_projection_backfill$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname='community_directory_profiles_account_id_fkey'
      AND conrelid='public.community_directory_profiles'::regclass
  ) THEN
    ALTER TABLE public.community_directory_profiles
      ADD CONSTRAINT community_directory_profiles_account_id_fkey
      FOREIGN KEY (account_id) REFERENCES public.member_accounts(id)
      ON DELETE CASCADE ON UPDATE CASCADE;
  END IF;
END
$directory_projection_backfill$;

CREATE UNIQUE INDEX IF NOT EXISTS community_directory_profiles_account_id_key
  ON public.community_directory_profiles(account_id);
CREATE INDEX IF NOT EXISTS community_directory_profiles_visibility_idx
  ON public.community_directory_profiles(searchable, profile_visibility);

-- Link existing member projections only where a real, active, verified member
-- profile exists. Unlinked catalogue/demo rows remain invisible to member search.
UPDATE public.community_directory_profiles d
SET account_id = p.account_id,
    searchable = (
      a.status='ACTIVE' AND a.verification_status='VERIFIED' AND
      COALESCE(lower(pp.search_results),'yes') <> 'no' AND
      COALESCE(lower(pp.view_profile),'verified members only') NOT LIKE '%only me%' AND
      COALESCE(lower(pp.view_profile),'verified members only') NOT LIKE '%no one%'
    ),
    profile_visibility = CASE
      WHEN lower(COALESCE(pp.view_profile,'verified members only')) LIKE '%follower%'
        THEN 'FOLLOWERS_ONLY'
      WHEN lower(COALESCE(pp.view_profile,'verified members only')) LIKE '%only me%'
        OR lower(COALESCE(pp.view_profile,'verified members only')) LIKE '%no one%'
        OR lower(COALESCE(pp.search_results,'yes'))='no'
        THEN 'HIDDEN'
      ELSE 'VERIFIED_MEMBERS'
    END,
    posts_visibility = COALESCE(pp.see_posts,'Verified members only'),
    message_visibility = COALESCE(pp.message_me,'Verified members only')
FROM public.member_profiles p
JOIN public.member_accounts a ON a.id=p.account_id
LEFT JOIN public.member_privacy_preferences pp ON pp.account_id=p.account_id
WHERE lower(p.username)=lower(d.username);

ALTER TABLE public.community_directory_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.community_directory_profiles FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS community_directory_profiles_verified_member_read
  ON public.community_directory_profiles;
DROP POLICY IF EXISTS community_directory_profiles_owner_write
  ON public.community_directory_profiles;

CREATE POLICY community_directory_profiles_verified_member_read
ON public.community_directory_profiles
FOR SELECT TO PUBLIC
USING (
  current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app')
  AND NULLIF(current_setting('app.account_id',true),'') IS NOT NULL
  AND (
    account_id=NULLIF(current_setting('app.account_id',true),'')::uuid
    OR (
      searchable=true
      AND profile_visibility IN ('VERIFIED_MEMBERS','FOLLOWERS_ONLY')
      AND EXISTS (
        SELECT 1 FROM public.member_accounts viewer
        WHERE viewer.id=NULLIF(current_setting('app.account_id',true),'')::uuid
          AND viewer.status='ACTIVE' AND viewer.verification_status='VERIFIED'
      )
      AND (
        profile_visibility='VERIFIED_MEMBERS'
        OR EXISTS (
          SELECT 1 FROM public.member_follows f
          WHERE f.account_id=NULLIF(current_setting('app.account_id',true),'')::uuid
            AND f.directory_profile_id=community_directory_profiles.id
            AND f.is_following=true
        )
      )
    )
  )
);

CREATE POLICY community_directory_profiles_owner_write
ON public.community_directory_profiles
FOR ALL TO PUBLIC
USING (
  current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app')
  AND account_id=NULLIF(current_setting('app.account_id',true),'')::uuid
)
WITH CHECK (
  current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app')
  AND account_id=NULLIF(current_setting('app.account_id',true),'')::uuid
);

DO $directory_postflight$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname='public' AND c.relname='community_directory_profiles'
      AND c.relrowsecurity AND c.relforcerowsecurity
  ) THEN
    RAISE EXCEPTION 'Public directory profile RLS is not enabled and forced';
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.community_directory_profiles
    WHERE account_id IS NULL AND searchable=true
  ) THEN
    RAISE EXCEPTION 'Unlinked directory rows cannot be searchable';
  END IF;
END
$directory_postflight$;
