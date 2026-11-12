-- Persist the blocked member identity so RLS can hide a member who blocked the viewer.
ALTER TABLE public.member_moderation_blocks
  ADD COLUMN IF NOT EXISTS blocked_account_id uuid;

DO $block_target_fk$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname='member_moderation_blocks_blocked_account_id_fkey'
      AND conrelid='public.member_moderation_blocks'::regclass
  ) THEN
    ALTER TABLE public.member_moderation_blocks
      ADD CONSTRAINT member_moderation_blocks_blocked_account_id_fkey
      FOREIGN KEY (blocked_account_id) REFERENCES public.member_accounts(id)
      ON DELETE SET NULL ON UPDATE CASCADE;
  END IF;
END
$block_target_fk$;

CREATE INDEX IF NOT EXISTS member_moderation_blocks_blocked_account_idx
  ON public.member_moderation_blocks(blocked_account_id);

UPDATE public.member_moderation_blocks b
SET blocked_account_id=d.account_id
FROM public.community_directory_profiles d
WHERE b.blocked_account_id IS NULL
  AND lower(b.blocked_username)=lower(d.username)
  AND d.account_id IS NOT NULL;

DROP POLICY IF EXISTS member_moderation_blocks_target_read
  ON public.member_moderation_blocks;
CREATE POLICY member_moderation_blocks_target_read
ON public.member_moderation_blocks
FOR SELECT TO PUBLIC
USING (
  current_user IN ('sakhi_dev_app','sakhi_test_app','sakhi_staging_app')
  AND blocked_account_id=NULLIF(current_setting('app.account_id',true),'')::uuid
);

DROP POLICY IF EXISTS community_directory_profiles_verified_member_read
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
      AND NOT EXISTS (
        SELECT 1 FROM public.member_moderation_blocks b
        WHERE b.account_id=community_directory_profiles.account_id
          AND b.blocked_account_id=NULLIF(current_setting('app.account_id',true),'')::uuid
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

DO $block_visibility_postflight$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname='public' AND tablename='member_moderation_blocks'
      AND policyname='member_moderation_blocks_target_read'
  ) THEN
    RAISE EXCEPTION 'Incoming block visibility policy was not installed';
  END IF;
END
$block_visibility_postflight$;
