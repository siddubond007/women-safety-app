-- Tighten applicability and avoid per-row evaluation of request identity
-- in follower-read policies. This is a follow-up because the original policy
-- migration has already been applied to staging.
DROP POLICY IF EXISTS community_posts_followers_read ON public.community_posts;
CREATE POLICY community_posts_followers_read
ON public.community_posts
AS PERMISSIVE
FOR SELECT
TO sakhi_dev_app, sakhi_test_app, sakhi_staging_app
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
);

DROP POLICY IF EXISTS media_assets_followers_read ON public.media_assets;
CREATE POLICY media_assets_followers_read
ON public.media_assets
AS PERMISSIVE
FOR SELECT
TO sakhi_dev_app, sakhi_test_app, sakhi_staging_app
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
);

CREATE INDEX IF NOT EXISTS member_follows_directory_profile_id_idx
  ON public.member_follows (directory_profile_id);
