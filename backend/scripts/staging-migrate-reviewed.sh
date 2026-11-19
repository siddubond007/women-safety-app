#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

STAGE3B2_MIGRATIONS="20261113130000_allow_scoped_system_auth_audit,20261113140000_retention_deletion_runtime_grants,20261114110000_scope_retention_system_audit"
STAGE3B2_APPROVAL="YES_APPLY_20261113_14_STAGE3B2"
STAGE4_MIGRATIONS="20261119140000_admin_staff_role_constraints,20261119150000_secure_admin_bootstrap_function_search_path,20261119160000_revoke_data_api_roles_from_member_data"
STAGE4_APPROVAL="YES_APPLY_20261119_STAGE4_RBAC_RLS"

case "${SAKHI_MIGRATION_TARGET:-}" in
  "$STAGE3B2_MIGRATIONS")
    EXPECTED_MIGRATIONS="$STAGE3B2_MIGRATIONS"
    APPROVAL_PHRASE="$STAGE3B2_APPROVAL"
    ;;
  "$STAGE4_MIGRATIONS")
    EXPECTED_MIGRATIONS="$STAGE4_MIGRATIONS"
    APPROVAL_PHRASE="$STAGE4_APPROVAL"
    ;;
  *)
    echo "Refusing migration: target is not an explicitly reviewed migration set." >&2
    exit 1
    ;;
esac

if [[ "${SAKHI_ENV:-}" != "staging" ]]; then
  echo "Refusing migration: SAKHI_ENV must be staging." >&2
  exit 1
fi

if [[ "${SAKHI_ALLOW_STAGING_MIGRATIONS:-}" != "$APPROVAL_PHRASE" ]]; then
  echo "Refusing migration: set SAKHI_ALLOW_STAGING_MIGRATIONS to the exact approval phrase for the selected reviewed migration set." >&2
  exit 1
fi

if [[ "${SAKHI_MIGRATION_TARGET:-}" != "$EXPECTED_MIGRATIONS" ]]; then
  echo "Refusing migration: SAKHI_MIGRATION_TARGET must list one exact reviewed migration set in order." >&2
  exit 1
fi

if [[ -z "${SAKHI_MIGRATOR_DATABASE_URL:-}" ]]; then
  echo "Refusing migration: SAKHI_MIGRATOR_DATABASE_URL is not configured." >&2
  exit 1
fi

# Stage 4 requires the restricted postgres role for the bootstrap trigger and
# owner-aware revocations. It must never run through generic Prisma migrate deploy.
if [[ "${SAKHI_MIGRATION_TARGET}" == "$STAGE4_MIGRATIONS" ]]; then
  ./scripts/staging-apply-stage4-reviewed.sh
  exit 0
fi

# Read-only checks prove the exact staging project, migration role, full
# Modules 1–7 predecessor chain, exact release tree, and permitted reviewed pending migration set.
node scripts/staging-preflight.cjs migrations

# Prisma migrate deploy is safe here only because preflight rejects every
# pending migration except the three reviewed Stage 3B2 migrations.
npm run db:migrate:deploy

# Apply the reviewed least-privilege grants after the schema migration.
./node_modules/.bin/prisma db execute --file ./prisma/staging/runtime-grants.sql

npm run db:migrate:status
echo "Reviewed staging migration command completed."
