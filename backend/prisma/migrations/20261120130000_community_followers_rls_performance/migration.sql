-- Optimize follower-only community reads without assuming every environment
-- provisions every Sakhi runtime role. Staging has sakhi_staging_app; isolated
-- dev/test databases may additionally have sakhi_dev_app and sakhi_test_app.
-- The policy remains restricted to the exact allowlisted runtime roles that
-- exist in the target database. Request identity is evaluated once per query.
DROP POLICY IF EXISTS community_posts_followers_read ON public.community_posts;
DROP POLICY IF EXISTS media_assets_followers_read ON public.media_assets;

DO $migration$
DECLARE
  policy_roles text;
BEGIN
  SELECT string_agg(format('%I', candidate.role_name), ', ' ORDER BY candidate.role_name)
    INTO policy_roles
  FROM unnest(ARRAY[
    'sakhi_dev_app',
    'sakhi_test_app',
    'sakhi_staging_app'
  ]::text[]) AS candidate(role_name)
  WHERE EXISTS (
    SELECT 1
    FROM pg_catalog.pg_roles AS existing_role
    WHERE existing_role.rolname = candidate.role_name
  );

  IF policy_roles IS NULL THEN
    RAISE EXCEPTION
      'Cannot create community follower policies: no approved Sakhi application role exists in this database';
  END IF;

  EXECUTE format($policy$
    CREATE POLICY community_posts_followers_read
    ON public.community_posts
    AS PERMISSIVE
    FOR SELECT
    TO %s
    USING (
      (SELECT NULLIF(current_setting('app.account_id', true), '')) IS NOT NULL
      AND author_account_id IS NOT NULL
      AND visibility = 'FOLLOWERS_ONLY'
      AND status IN ('PUBLISHED', 'EDITED')
      AND deleted_at IS NULL
      AND EXISTS (
        SELECT 1
        FROM public.community_directory_profiles AS directory_profile
        JOIN public.member_follows AS member_follow
          ON member_follow.directory_profile_id = directory_profile.id
        WHERE directory_profile.account_id = community_posts.author_account_id
          AND member_follow.account_id =
            ((SELECT NULLIF(current_setting('app.account_id', true), ''))::uuid)
          AND member_follow.is_following = true
      )
      AND NOT EXISTS (
        SELECT 1
        FROM public.member_moderation_blocks AS viewer_block
        WHERE viewer_block.account_id =
          ((SELECT NULLIF(current_setting('app.account_id', true), ''))::uuid)
          AND viewer_block.blocked_account_id = community_posts.author_account_id
      )
    )
  $policy$, policy_roles);

  EXECUTE format($policy$
    CREATE POLICY media_assets_followers_read
    ON public.media_assets
    AS PERMISSIVE
    FOR SELECT
    TO %s
    USING (
      (SELECT NULLIF(current_setting('app.account_id', true), '')) IS NOT NULL
      AND purpose IN ('COMMUNITY_POST_IMAGE', 'COMMUNITY_POST_VIDEO')
      AND visibility = 'FOLLOWERS_ONLY'
      AND status = 'ATTACHED'
      AND deleted_at IS NULL
      AND post_id IS NOT NULL
      AND EXISTS (
        SELECT 1
        FROM public.community_posts AS community_post
        WHERE community_post.id = media_assets.post_id
          AND community_post.author_account_id = media_assets.owner_account_id
          AND community_post.visibility = 'FOLLOWERS_ONLY'
          AND community_post.status IN ('PUBLISHED', 'EDITED')
          AND community_post.deleted_at IS NULL
      )
    )
  $policy$, policy_roles);
END
$migration$;

-- Supports the follower lookup used by the community-post visibility policy.
CREATE INDEX IF NOT EXISTS member_follows_directory_profile_id_idx
  ON public.member_follows (directory_profile_id);
