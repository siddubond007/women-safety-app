#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

EXPECTED_MIGRATION="20261106010000_modules8_9_10_11_12_complete"
APPROVAL_PHRASE="YES_APPLY_20261106010000_MODULES8_12"

if [[ "${SAKHI_ENV:-}" != "staging" ]]; then
  echo "Refusing migration: SAKHI_ENV must be staging." >&2
  exit 1
fi

if [[ "${SAKHI_ALLOW_STAGING_MIGRATIONS:-}" != "$APPROVAL_PHRASE" ]]; then
  echo "Refusing migration: set SAKHI_ALLOW_STAGING_MIGRATIONS to the exact reviewed approval phrase for a deliberate manual run." >&2
  exit 1
fi

if [[ "${SAKHI_MIGRATION_TARGET:-}" != "$EXPECTED_MIGRATION" ]]; then
  echo "Refusing migration: SAKHI_MIGRATION_TARGET must identify the reviewed Modules 8–12 migration." >&2
  exit 1
fi

if [[ -z "${SAKHI_MIGRATOR_DATABASE_URL:-}" ]]; then
  echo "Refusing migration: SAKHI_MIGRATOR_DATABASE_URL is not configured." >&2
  exit 1
fi

# Read-only checks prove the exact staging project, migration role, full
# Modules 1–7 predecessor chain, and permitted pending-migration set.
node scripts/staging-preflight.cjs migrations

# Prisma migrate deploy is safe here only because preflight rejects every
# pending migration except the single reviewed Modules 8–12 migration.
npm run db:migrate:deploy

# Apply the reviewed least-privilege grants after the schema migration.
./node_modules/.bin/prisma db execute --file ./prisma/staging/runtime-grants.sql

npm run db:migrate:status
echo "Reviewed Modules 8–12 migration command completed."
