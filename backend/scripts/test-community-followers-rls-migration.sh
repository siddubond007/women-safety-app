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
HIDDEN_ROLES=false
restore_roles() {
  if [[ "$HIDDEN_ROLES" == true ]]; then
    psql "postgresql://$PGUSER:$PGPASSWORD@$PGHOST:$PGPORT/$PGDATABASE" -v ON_ERROR_STOP=1 <<'SQL'
ALTER ROLE sakhi_ci_hidden_dev_app RENAME TO sakhi_dev_app;
ALTER ROLE sakhi_ci_hidden_test_app RENAME TO sakhi_test_app;
ALTER ROLE sakhi_ci_hidden_staging_app RENAME TO sakhi_staging_app;
SQL
    HIDDEN_ROLES=false
  fi
}
cleanup() {
  restore_roles || true
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

# Role names are cluster-wide. Rename the three allowlisted non-superuser
# roles temporarily, preserving their OIDs/grants, to exercise fail-closed
# behavior. Restore them before any subsequent test step.
psql "postgresql://$PGUSER:$PGPASSWORD@$PGHOST:$PGPORT/$PGDATABASE" -v ON_ERROR_STOP=1 <<'SQL'
ALTER ROLE sakhi_dev_app RENAME TO sakhi_ci_hidden_dev_app;
ALTER ROLE sakhi_test_app RENAME TO sakhi_ci_hidden_test_app;
ALTER ROLE sakhi_staging_app RENAME TO sakhi_ci_hidden_staging_app;
SQL
HIDDEN_ROLES=true

if psql "$DB_URL" -v ON_ERROR_STOP=1 -f "$MIGRATION" > /tmp/sakhi-community-rls-no-role.log 2>&1; then
  echo "Expected migration to fail when no approved Sakhi app role exists." >&2
  exit 1
fi
grep -q "no approved Sakhi application role exists" /tmp/sakhi-community-rls-no-role.log || {
  cat /tmp/sakhi-community-rls-no-role.log >&2
  echo "Migration failed for an unexpected reason in the no-role test." >&2
  exit 1
}
restore_roles

# Execute the unmodified migration with all three approved runtime roles
# present, then verify exact policy targets and the index in PostgreSQL.
psql "$DB_URL" -v ON_ERROR_STOP=1 -f "$MIGRATION"
psql "$DB_URL" -v ON_ERROR_STOP=1 <<'SQL'
DO $assertions$
DECLARE
  policy_roles name[];
BEGIN
  SELECT roles INTO policy_roles
  FROM pg_catalog.pg_policies
  WHERE schemaname='public' AND tablename='community_posts'
    AND policyname='community_posts_followers_read';
  IF policy_roles IS DISTINCT FROM ARRAY['sakhi_dev_app','sakhi_staging_app','sakhi_test_app']::name[] THEN
    RAISE EXCEPTION 'Unexpected community_posts policy roles: %', policy_roles;
  END IF;

  SELECT roles INTO policy_roles
  FROM pg_catalog.pg_policies
  WHERE schemaname='public' AND tablename='media_assets'
    AND policyname='media_assets_followers_read';
  IF policy_roles IS DISTINCT FROM ARRAY['sakhi_dev_app','sakhi_staging_app','sakhi_test_app']::name[] THEN
    RAISE EXCEPTION 'Unexpected media_assets policy roles: %', policy_roles;
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
