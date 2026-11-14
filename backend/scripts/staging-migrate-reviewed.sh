#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

EXPECTED_MIGRATIONS="20261113130000_allow_scoped_system_auth_audit,20261113140000_retention_deletion_runtime_grants,20261114110000_scope_retention_system_audit"
APPROVAL_PHRASE="YES_APPLY_20261113_14_STAGE3B2"

if [[ "${SAKHI_ENV:-}" != "staging" ]]; then
  echo "Refusing migration: SAKHI_ENV must be staging." >&2
  exit 1
fi

if [[ "${SAKHI_ALLOW_STAGING_MIGRATIONS:-}" != "$APPROVAL_PHRASE" ]]; then
  echo "Refusing migration: set SAKHI_ALLOW_STAGING_MIGRATIONS to the exact reviewed approval phrase for a deliberate manual run." >&2
  exit 1
fi

if [[ "${SAKHI_MIGRATION_TARGET:-}" != "$EXPECTED_MIGRATIONS" ]]; then
  echo "Refusing migration: SAKHI_MIGRATION_TARGET must list the exact three reviewed Stage 3B2 migrations in order." >&2
  exit 1
fi

if [[ -z "${SAKHI_MIGRATOR_DATABASE_URL:-}" ]]; then
  echo "Refusing migration: SAKHI_MIGRATOR_DATABASE_URL is not configured." >&2
  exit 1
fi

# Read-only checks prove the exact staging project, migration role, full
# Modules 1–7 predecessor chain, exact release tree, and permitted Stage 3B2 pending set.
node scripts/staging-preflight.cjs migrations

# Prisma migrate deploy is safe here only because preflight rejects every
# pending migration except the three reviewed Stage 3B2 migrations.
npm run db:migrate:deploy

# Apply the reviewed least-privilege grants after the schema migration.
./node_modules/.bin/prisma db execute --file ./prisma/staging/runtime-grants.sql

npm run db:migrate:status
echo "Reviewed Stage 3B2 migration command completed."
