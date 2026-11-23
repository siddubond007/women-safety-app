#!/usr/bin/env bash
set -euo pipefail

# Exact migration execution in a disposable PostgreSQL 17 database only.
: "${PGHOST:=127.0.0.1}"
: "${PGPORT:=5432}"
: "${PGUSER:=postgres}"
: "${PGPASSWORD:?Disposable PostgreSQL password is required}"
: "${PGDATABASE:=sakhi_test}"
if [[ "$PGHOST" != "127.0.0.1" || "$PGDATABASE" != "sakhi_test" ]]; then
  echo "Refusing execution outside disposable local sakhi_test CI." >&2
  exit 1
fi

TEST_DB="sakhi_community_rls_migration_test"
MIGRATION="prisma/migrations/20261120130000_community_followers_rls_performance/migration.sql"
cleanup() {
  dropdb --if-exists --force --host="$PGHOST" --port="$PGPORT" --username="$PGUSER" "$TEST_DB" >/dev/null 2>&1 || true
}
trap cleanup EXIT

dropdb --if-exists --force --host="$PGHOST" --port="$PGPORT" --username="$PGUSER" "$TEST_DB"
createdb --host="$PGHOST" --port="$PGPORT" --username="$PGUSER" "$TEST_DB"
DB_URL="postgresql://$PGUSER:$PGPASSWORD@$PGHOST:$PGPORT/$TEST_DB"

psql "$DB_URL" -v ON_ERROR_STOP=1 <<'SQL'
CREATE TABLE public.community_posts (
  id uuid PRIMARY KEY, author_account_id uuid, visibility text, status text, deleted_at timestamptz
);
CREATE TABLE public.media_assets (
  id uuid PRIMARY KEY, owner_account_id uuid, post_id uuid, purpose text,
  visibility text, status text, deleted_at timestamptz
);
CREATE TABLE public.community_directory_profiles (id uuid PRIMARY KEY, account_id uuid);
CREATE TABLE public.member_follows (
  id uuid PRIMARY KEY, directory_profile_id uuid, account_id uuid, is_following boolean
);
CREATE TABLE public.member_moderation_blocks (id uuid PRIMARY KEY, account_id uuid, blocked_account_id uuid);
SQL

# Runtime roles are cluster-wide, so this test deliberately does not rename,
# drop, or otherwise mutate them. The migration must discover the approved
# roles present in this isolated CI cluster and target exactly those roles.
psql "$DB_URL" -v ON_ERROR_STOP=1 -f "$MIGRATION"

psql "$DB_URL" -v ON_ERROR_STOP=1 <<'SQL'
DO $assertions$
DECLARE
  policy_roles name[];
  expected_roles name[];
BEGIN
  SELECT array_agg(role_name::name ORDER BY role_name)
    INTO expected_roles
  FROM (VALUES ('sakhi_dev_app'), ('sakhi_staging_app'), ('sakhi_test_app')) AS approved(role_name)
  WHERE EXISTS (
    SELECT 1 FROM pg_catalog.pg_roles r WHERE r.rolname = approved.role_name
  );

  IF expected_roles IS NULL OR cardinality(expected_roles) = 0 THEN
    RAISE EXCEPTION 'CI fixture did not create any approved Sakhi application roles';
  END IF;

  SELECT roles INTO policy_roles
  FROM pg_catalog.pg_policies
  WHERE schemaname='public' AND tablename='community_posts'
    AND policyname='community_posts_followers_read';
  IF policy_roles IS DISTINCT FROM expected_roles THEN
    RAISE EXCEPTION 'Unexpected community_posts policy roles: %, expected %', policy_roles, expected_roles;
  END IF;

  SELECT roles INTO policy_roles
  FROM pg_catalog.pg_policies
  WHERE schemaname='public' AND tablename='media_assets'
    AND policyname='media_assets_followers_read';
  IF policy_roles IS DISTINCT FROM expected_roles THEN
    RAISE EXCEPTION 'Unexpected media_assets policy roles: %, expected %', policy_roles, expected_roles;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_catalog.pg_indexes
    WHERE schemaname='public' AND tablename='member_follows'
      AND indexname='member_follows_directory_profile_id_idx'
  ) THEN
    RAISE EXCEPTION 'Follower lookup index was not created';
  END IF;
END
$assertions$;
SQL

echo "Community follower RLS migration execution passed on disposable PostgreSQL."
