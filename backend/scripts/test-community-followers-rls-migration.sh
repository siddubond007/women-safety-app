#!/usr/bin/env bash
set -euo pipefail

# Execute the exact community follower performance migration against a fresh,
# disposable PostgreSQL database. This script is called only by the isolated
# PostgreSQL 17 CI harness after its role boundary has been prepared.
: "${PGHOST:=127.0.0.1}"
: "${PGPORT:=5432}"
: "${PGUSER:=postgres}"
: "${PGPASSWORD:?Disposable PostgreSQL password is required}"
: "${PGDATABASE:=sakhi_test}"

if [[ "$PGHOST" != "127.0.0.1" || "$PGDATABASE" != "sakhi_test" ]]; then
  echo "Refusing migration execution outside the disposable local sakhi_test CI environment." >&2
  exit 1
fi

TEST_DB="sakhi_community_rls_migration_test"
MIGRATION="prisma/migrations/20261120130000_community_followers_rls_performance/migration.sql"
cleanup() {
  dropdb --if-exists --force --host="$PGHOST" --port="$PGPORT" --username="$PGUSER" "$TEST_DB" >/dev/null 2>&1 || true
  psql "postgresql://$PGUSER:$PGPASSWORD@$PGHOST:$PGPORT/$PGDATABASE" -v ON_ERROR_STOP=1 \
    -c "DROP ROLE IF EXISTS sakhi_community_rls_migration_test_role" >/dev/null 2>&1 || true
}
trap cleanup EXIT

dropdb --if-exists --force --host="$PGHOST" --port="$PGPORT" --username="$PGUSER" "$TEST_DB"
createdb --host="$PGHOST" --port="$PGPORT" --username="$PGUSER" "$TEST_DB"
DB_URL="postgresql://$PGUSER:$PGPASSWORD@$PGHOST:$PGPORT/$TEST_DB"

# Minimal schema matching every column/table referenced by the migration.
psql "$DB_URL" -v ON_ERROR_STOP=1 <<'SQL'
CREATE TABLE public.community_posts (
  id uuid PRIMARY KEY,
  author_account_id uuid,
  visibility text,
  status text,
  deleted_at timestamptz
);
CREATE TABLE public.media_assets (
  id uuid PRIMARY KEY,
  owner_account_id uuid,
  post_id uuid,
  purpose text,
  visibility text,
  status text,
  deleted_at timestamptz
);
CREATE TABLE public.community_directory_profiles (
  id uuid PRIMARY KEY,
  account_id uuid
);
CREATE TABLE public.member_follows (
  id uuid PRIMARY KEY,
  directory_profile_id uuid,
  account_id uuid,
  is_following boolean
);
CREATE TABLE public.member_moderation_blocks (
  id uuid PRIMARY KEY,
  account_id uuid,
  blocked_account_id uuid
);
SQL

# No allowlisted Sakhi runtime role exists yet. The exact migration must fail
# closed with its explicit exception instead of creating broad policies.
if psql "$DB_URL" -v ON_ERROR_STOP=1 -f "$MIGRATION" > /tmp/sakhi-community-rls-no-role.log 2>&1; then
  echo "Expected the migration to fail when no approved Sakhi app role exists." >&2
  cat /tmp/sakhi-community-rls-no-role.log >&2
  exit 1
fi
if ! grep -q "no approved Sakhi application role exists" /tmp/sakhi-community-rls-no-role.log; then
  echo "Migration failed for an unexpected reason in the no-role test." >&2
  cat /tmp/sakhi-community-rls-no-role.log >&2
  exit 1
fi

# One approved runtime role is sufficient. Execute the unmodified migration
# and verify both policies target exactly that role and the index exists.
psql "postgresql://$PGUSER:$PGPASSWORD@$PGHOST:$PGPORT/$PGDATABASE" -v ON_ERROR_STOP=1 \
  -c "CREATE ROLE sakhi_community_rls_migration_test_role NOLOGIN NOSUPERUSER NOBYPASSRLS"
psql "$DB_URL" -v ON_ERROR_STOP=1 \
  -c "CREATE ROLE sakhi_community_rls_migration_test_role NOLOGIN NOSUPERUSER NOBYPASSRLS" 2>/dev/null || true
# The role is cluster-wide; the first CREATE ROLE is sufficient.
psql "$DB_URL" -v ON_ERROR_STOP=1 -f "$MIGRATION"

psql "$DB_URL" -v ON_ERROR_STOP=1 <<'SQL'
DO $assertions$
DECLARE
  policy_roles text[];
BEGIN
  SELECT roles INTO policy_roles
  FROM pg_catalog.pg_policies
  WHERE schemaname = 'public'
    AND tablename = 'community_posts'
    AND policyname = 'community_posts_followers_read';
  IF policy_roles IS DISTINCT FROM ARRAY['sakhi_community_rls_migration_test_role']::name[] THEN
    RAISE EXCEPTION 'community_posts policy has unexpected role targets: %', policy_roles;
  END IF;

  SELECT roles INTO policy_roles
  FROM pg_catalog.pg_policies
  WHERE schemaname = 'public'
    AND tablename = 'media_assets'
    AND policyname = 'media_assets_followers_read';
  IF policy_roles IS DISTINCT FROM ARRAY['sakhi_community_rls_migration_test_role']::name[] THEN
    RAISE EXCEPTION 'media_assets policy has unexpected role targets: %', policy_roles;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_catalog.pg_indexes
    WHERE schemaname = 'public'
      AND tablename = 'member_follows'
      AND indexname = 'member_follows_directory_profile_id_idx'
  ) THEN
    RAISE EXCEPTION 'Expected follower lookup index was not created';
  END IF;
END
$assertions$;
SQL

echo "Community follower RLS migration execution passed on disposable PostgreSQL."
