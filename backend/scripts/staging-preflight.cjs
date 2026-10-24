const fs = require("node:fs");
const path = require("node:path");
const { Client } = require("pg");

const SUPABASE_ROOT_CA = path.join(__dirname, "..", "prod-ca-2021.crt");

const EXPECTED_HOST = "aws-0-ap-south-1.pooler.supabase.com";
const PROJECT_REF = "wmlpokholjfadyohdlgo";
const EXPECTED_USER = `sakhi_staging_migrator.${PROJECT_REF}`;
const BASELINE_MIGRATIONS = [
  "20261015163000_stage1_foundation",
  "20261015170000_dev_auth_sessions",
  "20261016090000_audit_event_id_returning_privilege",
  "20261016120000_eligibility_status_domain",
  "20261016140000_eligibility_consent_sessions_support",
  "20261016150000_eligibility_provider_callback_events",
  "20261017121500_admin_manual_review_decisions",
  "20261017123000_eligibility_submissions",
  "20261018090000_module2_core_domain",
  "20261018090000_module2_profile_social_settings",
  "20261019120000_module3_social_wall_and_drive_media",
  "20261022103000_platform_registration_policy_settings",
  "20261023110000_module4_emergency_sos_and_safety",
];

async function main() {
  const mode = process.argv[2] ?? "bootstrap";
  if (mode !== "bootstrap" && mode !== "migrations") {
    throw new Error("Unsupported staging preflight mode.");
  }

  const rawUrl = process.env.SAKHI_MIGRATOR_DATABASE_URL;
  if (!rawUrl) throw new Error("Missing staging migration connection.");

  const url = new URL(rawUrl);
  const password = decodeURIComponent(url.password);
  if (
    !["postgres:", "postgresql:"].includes(url.protocol) ||
    url.hostname !== EXPECTED_HOST ||
    url.port !== "5432" ||
    url.pathname !== "/postgres" ||
    decodeURIComponent(url.username) !== EXPECTED_USER ||
    password.length < 32 ||
    password.includes("REPLACE_WITH") ||
    password.includes("[YOUR-PASSWORD]") ||
    url.searchParams.get("schema") !== "public" ||
    url.searchParams.get("sslmode") !== "verify-full" ||
    !((url.searchParams.get("sslcert") ?? "").replace(/\\/g, "/").endsWith("/prod-ca-2021.crt") ||
      url.searchParams.get("sslcert") === "prod-ca-2021.crt")
  ) {
    throw new Error("Staging connection target rejected; details are redacted.");
  }

  // Use the downloaded Supabase root CA explicitly for this read-only pg check.
  // Prisma CLI receives sslcert in the URL; remove that parameter here because
  // pg treats sslcert as a client certificate rather than a root CA.
  const clientUrl = new URL(rawUrl);
  clientUrl.searchParams.delete("sslmode");
  clientUrl.searchParams.delete("sslcert");
  const rootCa = fs.readFileSync(SUPABASE_ROOT_CA, "utf8");
  const client = new Client({
    connectionString: clientUrl.toString(),
    ssl: { ca: rootCa, rejectUnauthorized: true },
  });
  try {
    await client.connect();
    const { rows } = await client.query(
      "SELECT current_database() AS database_name, current_user AS database_user",
    );
    if (
      rows[0]?.database_name !== "postgres" ||
      rows[0]?.database_user !== "sakhi_staging_migrator"
    ) {
      throw new Error("Connected database identity did not match the staging migration role.");
    }

    const tableResult = await client.query(
      "SELECT tablename FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename",
    );
    const tableNames = tableResult.rows.map((row) => row.tablename);

    if (mode === "bootstrap") {
      const applicationTables = tableNames.filter(
        (name) => name !== "_prisma_migrations",
      );
      if (applicationTables.length > 0) {
        throw new Error(
          "The public schema is not empty. Staging bootstrap stopped without changing it.",
        );
      }
      if (tableNames.includes("_prisma_migrations")) {
        throw new Error(
          "A Prisma migration ledger already exists. Staging bootstrap stopped rather than reinitializing it.",
        );
      }
      process.stdout.write(
        "Staging preflight passed: dedicated Supabase project, migration role, and empty public schema confirmed.\n",
      );
      return;
    }

    if (!tableNames.includes("_prisma_migrations")) {
      throw new Error("The staging baseline is not installed; refusing to deploy migrations.");
    }

    const migrationRows = await client.query(
      "SELECT migration_name, finished_at, rolled_back_at FROM public._prisma_migrations",
    );
    const applied = new Set(
      migrationRows.rows
        .filter((row) => row.finished_at && !row.rolled_back_at)
        .map((row) => row.migration_name),
    );
    const missing = BASELINE_MIGRATIONS.filter((name) => !applied.has(name));
    if (missing.length > 0) {
      throw new Error(
        "The fresh staging baseline is incomplete; refusing to deploy migrations.",
      );
    }

    process.stdout.write(
      "Staging migration preflight passed: all existing baseline migrations are recorded as applied.\n",
    );
  } finally {
    await client.end().catch(() => undefined);
  }
}

main().catch((error) => {
  const code = error && typeof error.code === "string" ? error.code : "STAGING_PREFLIGHT";
  const safeMessage = String(error && error.message ? error.message : "No safe diagnostic available.")
    .replace(/postgres(?:ql)?:\/\/\S+/gi, "[REDACTED CONNECTION]")
    .replace(/password[=: ]+\S+/gi, "password=[REDACTED]")
    .slice(0, 200);
  process.stderr.write(
    "Staging preflight failed (" + code + "): " + safeMessage + "\n",
  );
  process.exitCode = 1;
});
