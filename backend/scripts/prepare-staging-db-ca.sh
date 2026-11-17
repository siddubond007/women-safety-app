#!/usr/bin/env bash
set -euo pipefail

: "${RUNNER_TEMP:?GitHub Actions runner temp directory is unavailable}"
: "${GITHUB_ENV:?GitHub Actions environment file is unavailable}"

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ca_source="${script_dir}/../certs/prod-ca-2021.crt"
ca_file="${RUNNER_TEMP}/prod-ca-2021.crt"
test -s "$ca_source"
cp "$ca_source" "$ca_file"
test -s "$ca_file"

# Pin the official Supabase Root 2021 CA fingerprint. No database URL or
# credential is needed to prepare this trust anchor.
actual_fingerprint="$(
  openssl x509 -in "$ca_file" -noout -fingerprint -sha256 |
    sed 's/.*=//; s/://g' |
    tr '[:upper:]' '[:lower:]'
)"
expected_fingerprint="807025ad50d4ed219d2c9c7d299c004f824eb00cf7f65afef607d07b72e6cafa"
if [[ "$actual_fingerprint" != "$expected_fingerprint" ]]; then
  echo "::error::Supabase CA fingerprint did not match the pinned trust anchor."
  exit 1
fi

chmod 600 "$ca_file"
printf 'SAKHI_DB_CA_FILE=%s\n' "$ca_file" >> "$GITHUB_ENV"
echo "Supabase Root 2021 CA fingerprint verified. No database credentials were read or exported."
