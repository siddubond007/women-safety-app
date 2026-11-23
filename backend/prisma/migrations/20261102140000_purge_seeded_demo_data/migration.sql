-- Migration: Purge legacy seeded demo users and demo posts from staging/production database

-- 1. Remove all legacy seeded demo community posts
DELETE FROM "community_posts"
WHERE "id"::text LIKE '11111111-1111-4111-8111-%'
   OR "author_username" IN ('@siddhu', '@ananya', '@meera', '@kavya', '@ishita', '@priya', '@sneha', '@riya')
   OR "author_name" = 'Siddhu';

-- 2. Remove all legacy seeded demo directory profiles
DELETE FROM "community_directory_profiles"
WHERE "username" IN ('@siddhu', '@ananya', '@meera', '@kavya', '@ishita', '@priya', '@sneha', '@riya');

-- 3. Remove all legacy seeded demo member accounts and associated records
DO $$
DECLARE
  v_demo_phones text[] := ARRAY[
    '+919999992222',
    '+919845010101',
    '+919845010102',
    '+919845010103',
    '+919845010104',
    '+919845010105',
    '+919845010106',
    '+919845010107'
  ];
  v_account_ids uuid[];
BEGIN
  SELECT array_agg(id) INTO v_account_ids
  FROM "member_accounts"
  WHERE "phone_e164" = ANY(v_demo_phones);

  IF v_account_ids IS NOT NULL AND array_length(v_account_ids, 1) > 0 THEN
    DELETE FROM "community_post_comments" WHERE "account_id" = ANY(v_account_ids);
    DELETE FROM "community_post_likes" WHERE "account_id" = ANY(v_account_ids);
    DELETE FROM "community_post_saves" WHERE "account_id" = ANY(v_account_ids);
    DELETE FROM "member_follows" WHERE "account_id" = ANY(v_account_ids);
    DELETE FROM "community_posts" WHERE "author_account_id" = ANY(v_account_ids);
    DELETE FROM "eligibility_submissions" WHERE "account_id" = ANY(v_account_ids);
    DELETE FROM "member_profiles" WHERE "account_id" = ANY(v_account_ids);
    DELETE FROM "member_privacy_preferences" WHERE "account_id" = ANY(v_account_ids);
    DELETE FROM "member_notification_preferences" WHERE "account_id" = ANY(v_account_ids);
    DELETE FROM "auth_sessions" WHERE "account_id" = ANY(v_account_ids);
    DELETE FROM "member_accounts" WHERE "id" = ANY(v_account_ids);
  END IF;
END $$;
