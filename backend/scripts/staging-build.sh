#!/usr/bin/env bash
set -euo pipefail

if [[ "${SAKHI_ENV:-}" != "staging" ]]; then
  echo "Refusing staged migration build: SAKHI_ENV must be staging." >&2
  exit 1
fi

if [[ "${NODE_ENV:-}" != "production" ]]; then
  echo "Refusing staged migration build: NODE_ENV must be production." >&2
  exit 1
fi

if [[ -z "${SAKHI_MIGRATOR_DATABASE_URL:-}" ]]; then
  echo "Refusing staged migration build: SAKHI_MIGRATOR_DATABASE_URL is not configured." >&2
  exit 1
fi

# Validate the dedicated Supabase project, migrator login, TLS CA, and baseline.
node scripts/staging-preflight.cjs migrations

# Apply only migrations absent from the Prisma ledger.
npm run db:migrate:deploy

# Apply only explicit privileges for the staging application login role.
./node_modules/.bin/prisma db execute --file ./prisma/staging/runtime-grants.sql

# Do not build/deploy the app image unless migration status is clean.
npm run db:migrate:status

npm run build
