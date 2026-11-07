#!/usr/bin/env bash
set -euo pipefail

if [[ "${SAKHI_ENV:-}" != "staging" ]]; then
  echo "Refusing staging build: SAKHI_ENV must be staging." >&2
  exit 1
fi

if [[ "${NODE_ENV:-}" != "production" ]]; then
  echo "Refusing staging build: NODE_ENV must be production." >&2
  exit 1
fi

# Render auto-deploy builds are intentionally schema-neutral.
# Database migrations are never executed from this build command.
npm run build
