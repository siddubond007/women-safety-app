const fs = require("node:fs");
const path = require("node:path");
const { Client } = require("pg");

const SUPABASE_ROOT_CA = path.join(__dirname, "..", "prod-ca-2021.crt");

const EXPECTED_HOST = "aws-0-ap-south-1.pooler.supabase.com";
const PROJECT_REF = "wmlpokholjfadyohdlgo";
const REVIEWED_MIGRATION_SETS = [
  {
    migrations: [
      "20261113130000_allow_scoped_system_auth_audit",
      "20261113140000_retention_deletion_runtime_grants",
      "20261114110000_scope_retention_system_audit",
    ],
    approvalPhrase: "YES_APPLY_20261113_14_STAGE3B2",
    label: "Stage 3B2",
  },
  {
    migrations: [
      "20261119140000_admin_staff_role_constraints",
      "20261119150000_secure_admin_bootstrap_function_search_path",
      "20261119160000_revoke_data_api_roles_from_member_data",
    ],
    approvalPhrase: "YES_APPLY_20261119_STAGE4_RBAC_RLS",
    label: "Stage 4 RBAC/RLS",
  },
];
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
  "20261026183000_module5_discreet_complaint_system",
  "20261027170000_module10_rbac_admin_roles_and_module5_fixes",
  "20261029190000_module6_business_pages",
  "20261101120000_direct_message_dedicated_storage",
  "20261101130000_direct_message_runtime_grants",
  "20261101140000_auth_session_device_metadata",
  "20261102140000_purge_seeded_demo_data",
  "20261103090000_module7_menstrual_cycle_tracker",
];

async function main() {
  const mode = process.argv[2] ?? "bootstrap";
  if (mode !== "bootstrap" && mode !== "migrations") {
    throw new Error("Unsupported staging preflight mode.");
  }

  let expectedMigrations = [];
  let selectedMigrationSet = null;
  if (mode === "migrations") {
    selectedMigrationSet = REVIEWED_MIGRATION_SETS.find(
      (candidate) =>
        candidate.migrations.join(",") === process.env.SAKHI_MIGRATION_TARGET,
    );
    if (!selectedMigrationSet) {
      throw new Error("The exact reviewed staging migration target was not selected.");
    }
    if (process.env.SAKHI_ALLOW_STAGING_MIGRATIONS !== selectedMigrationSet.approvalPhrase) {
      throw new Error("The exact explicit staging migration approval phrase was not supplied.");
    }
    expectedMigrations = selectedMigrationSet.migrations;
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
    !(
      (url.searchParams.get("sslrootcert") ?? url.searchParams.get("sslcert") ?? "")
        .replace(/\\/g, "/")
        .endsWith("/prod-ca-2021.crt") ||
      (url.searchParams.get("sslrootcert") ?? url.searchParams.get("sslcert")) === "prod-ca-2021.crt"
    )
  ) {
    throw new Error("Staging connection target rejected; details are redacted.");
  }

  // Use the downloaded Supabase root CA explicitly for this read-only pg check.
  // Prisma CLI receives sslcert in the URL; remove that parameter here because
  // pg treats sslcert as a client certificate rather than a root CA.
  const clientUrl = new URL(rawUrl);
  clientUrl.searchParams.delete("sslmode");
  clientUrl.searchParams.delete("sslcert");
  clientUrl.searchParams.delete("sslrootcert");
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
    const failed = migrationRows.rows.filter(
      (row) => !row.finished_at && !row.rolled_back_at,
    );
    if (failed.length > 0) {
      throw new Error(
        "The Prisma migration ledger contains an unfinished migration; refusing to continue.",
      );
    }

    const missing = BASELINE_MIGRATIONS.filter((name) => !applied.has(name));
    if (missing.length > 0) {
      throw new Error(
        "A required Module 1–7 predecessor migration is missing; refusing to deploy migrations.",
      );
    }

    // Never let migrate deploy apply an arbitrary backlog. The only permitted
    // pending migrations are the three explicitly reviewed Stage 3B2 IDs.
    const migrationRoot = path.join(__dirname, "..", "prisma", "migrations");
    const localMigrations = fs
      .readdirSync(migrationRoot, { withFileTypes: true })
      .filter((entry) => entry.isDirectory())
      .map((entry) => entry.name)
      .sort();
    const pending = localMigrations.filter((name) => !applied.has(name));
    const unknownApplied = [...applied].filter((name) => !localMigrations.includes(name));
    const missingTargets = expectedMigrations.filter((name) => !localMigrations.includes(name));
    const unexpectedPending = pending.filter((name) => !expectedMigrations.includes(name));
    if (missingTargets.length > 0) {
      throw new Error("One or more reviewed reviewed staging migration directories are missing.");
    }
    if (unknownApplied.length > 0) {
      throw new Error("The staging migration ledger contains migrations absent from this release tree.");
    }
    if (unexpectedPending.length > 0) {
      throw new Error(
        "Unexpected pending migration set; only the three reviewed reviewed staging migrations are permitted.",
      );
    }

    process.stdout.write(
      pending.length > 0
        ? `Staging migration preflight passed: exact Stage 3B2 target selected; ${pending.length} reviewed migration(s) remain pending and no other migration may run.\n`
        : "Staging migration preflight passed: all three reviewed reviewed staging migrations are already applied; no schema migration is pending.\n",
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
