#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

EXPECTED_TARGET="20261119140000_admin_staff_role_constraints,20261119150000_secure_admin_bootstrap_function_search_path,20261119160000_revoke_data_api_roles_from_member_data"
APPROVAL_PHRASE="YES_APPLY_20261119_STAGE4_RBAC_RLS"

if [[ "${SAKHI_ENV:-}" != "staging" ]]; then
  echo "Refusing Stage 4 migration: SAKHI_ENV must be staging." >&2
  exit 1
fi
if [[ "${SAKHI_MIGRATION_TARGET:-}" != "$EXPECTED_TARGET" ]]; then
  echo "Refusing Stage 4 migration: exact ordered migration target is required." >&2
  exit 1
fi
if [[ "${SAKHI_ALLOW_STAGING_MIGRATIONS:-}" != "$APPROVAL_PHRASE" ]]; then
  echo "Refusing Stage 4 migration: exact approval phrase is required." >&2
  exit 1
fi
if [[ -z "${SAKHI_STAGING_POSTGRES_DATABASE_URL:-}" ]]; then
  echo "Refusing Stage 4 migration: SAKHI_STAGING_POSTGRES_DATABASE_URL is not configured." >&2
  exit 1
fi
if [[ -z "${SAKHI_MIGRATOR_DATABASE_URL:-}" ]]; then
  echo "Refusing Stage 4 migration: SAKHI_MIGRATOR_DATABASE_URL is not configured." >&2
  exit 1
fi

# The migrator preflight verifies the exact Supabase project, TLS target,
# predecessor chain and that only the three reviewed Stage 4 migrations remain pending.
node scripts/staging-preflight.cjs migrations

# This owner-aware runner applies the DDL atomically as restricted postgres,
# SET ROLEs to the migrator only for migrator-owned objects, then records the
# exact three migrations through Prisma using the dedicated migrator URL.
node scripts/staging-stage4-migration.cjs

npm run db:migrate:status
echo "Reviewed Stage 4 RBAC/RLS migration command completed."
