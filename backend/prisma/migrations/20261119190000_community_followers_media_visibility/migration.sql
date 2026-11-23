-- Add a member-safe read path for published FOLLOWERS_ONLY community posts.
-- Nested directory-profile and member-follow policies continue to enforce
-- active/verified membership, profile visibility, follow state and owner blocks.
DROP POLICY IF EXISTS community_posts_followers_read ON public.community_posts;
CREATE POLICY community_posts_followers_read
ON public.community_posts
FOR SELECT
USING (
  current_user = ANY (ARRAY['sakhi_dev_app', 'sakhi_test_app', 'sakhi_staging_app']::name[])
  AND NULLIF(current_setting('app.account_id', true), '') IS NOT NULL
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
      AND member_follow.account_id = NULLIF(current_setting('app.account_id', true), '')::uuid
      AND member_follow.is_following = true
  )
  AND NOT EXISTS (
    SELECT 1
    FROM public.member_moderation_blocks AS viewer_block
    WHERE viewer_block.account_id = NULLIF(current_setting('app.account_id', true), '')::uuid
      AND viewer_block.blocked_account_id = community_posts.author_account_id
  )
);

-- Follower-only media is visible only when attached to the matching published
-- post. Unattached uploads and draft media never qualify.
DROP POLICY IF EXISTS media_assets_followers_read ON public.media_assets;
CREATE POLICY media_assets_followers_read
ON public.media_assets
FOR SELECT
USING (
  current_user = ANY (ARRAY['sakhi_dev_app', 'sakhi_test_app', 'sakhi_staging_app']::name[])
  AND NULLIF(current_setting('app.account_id', true), '') IS NOT NULL
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
