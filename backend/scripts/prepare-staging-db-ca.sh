#!/usr/bin/env bash
set -euo pipefail

: "${SAKHI_APP_DATABASE_URL:?Missing staging app database URL}"
: "${SAKHI_MIGRATOR_DATABASE_URL:?Missing staging migrator database URL}"
: "${RUNNER_TEMP:?GitHub Actions runner temp directory is unavailable}"
: "${GITHUB_ENV:?GitHub Actions environment file is unavailable}"

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ca_source="${script_dir}/../certs/prod-ca-2021.crt"
ca_file="${RUNNER_TEMP}/prod-ca-2021.crt"
test -s "$ca_source"
cp "$ca_source" "$ca_file"
test -s "$ca_file"

# Pin the official Supabase Root 2021 CA fingerprint. The certificate is
# checked into the repository so CI does not depend on a mutable download URL.
actual_fingerprint="$(
  openssl x509 -in "$ca_file" -noout -fingerprint -sha256 |
    sed 's/.*=//; s/://g' |
    tr '[:upper:]' '[:lower:]'
)"
expected_fingerprint="807025ad50d4ed219d2c9c7d299c004f824eb00cf7f65afef607d07b72e6cafa"
if [[ "$actual_fingerprint" != "$expected_fingerprint" ]]; then
  echo "::error::Downloaded Supabase CA fingerprint did not match the pinned trust anchor."
  exit 1
fi

chmod 600 "$ca_file"

# The Render secret-file path is valid only inside Render. In GitHub Actions,
# preserve sslmode=verify-full and point both least-privilege DB URLs at the
# independently fingerprint-verified CA file in the runner's temporary dir.
node --input-type=module <<'NODE' >> "$GITHUB_ENV"
import { appendFileSync } from "node:fs";
const caFile = `${process.env.RUNNER_TEMP}/prod-ca-2021.crt`;
for (const key of ["SAKHI_APP_DATABASE_URL", "SAKHI_MIGRATOR_DATABASE_URL"]) {
  const raw = process.env[key];
  if (!raw) throw new Error(`Missing ${key}`);
  const url = new URL(raw);
  const configuredCa = (url.searchParams.get("sslrootcert") ?? "").replaceAll("\\", "/");
  if (!configuredCa.endsWith("/prod-ca-2021.crt") && configuredCa !== "prod-ca-2021.crt") {
    throw new Error(`${key} must reference the expected Supabase prod-ca-2021.crt trust anchor.`);
  }
  if (url.searchParams.get("sslmode") !== "verify-full") {
    throw new Error(`${key} must retain sslmode=verify-full.`);
  }
  url.searchParams.set("sslrootcert", caFile);
  appendFileSync(process.env.GITHUB_ENV, `${key}=${url.toString()}\n`, { mode: 0o600 });
}
NODE

echo "Supabase Root 2021 CA fingerprint verified; both staging DB URLs retain verify-full."
