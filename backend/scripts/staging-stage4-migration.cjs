const fs = require("node:fs");
const path = require("node:path");
const { spawnSync } = require("node:child_process");
const { Client } = require("pg");

const PROJECT_REF = "wmlpokholjfadyohdlgo";
const EXPECTED_HOST = "aws-0-ap-south-1.pooler.supabase.com";
const MIGRATION_TARGET = "20261118130000_remove_legacy_admin_mfa_flag,20261119140000_admin_staff_role_constraints,20261119150000_secure_admin_bootstrap_function_search_path,20261119160000_revoke_data_api_roles_from_member_data";
const APPROVAL_PHRASE = "YES_APPLY_20261119_STAGE4_RBAC_RLS";
const MIGRATIONS = [
  "20261118130000_remove_legacy_admin_mfa_flag",
  "20261119140000_admin_staff_role_constraints",
  "20261119150000_secure_admin_bootstrap_function_search_path",
  "20261119160000_revoke_data_api_roles_from_member_data",
];
const MIGRATOR_OWNED_TABLES = [
  "member_accounts",
  "auth_sessions",
  "otp_challenges",
  "account_deletion_requests",
  "member_profiles",
  "member_consents",
  "member_communication_preferences",
  "eligibility_submissions",
  "community_posts",
  "community_post_likes",
  "community_post_saves",
  "community_post_comments",
  "community_groups",
  "member_follows",
  "member_privacy_preferences",
  "member_notification_preferences",
  "member_notifications",
  "safety_emergency_contacts",
  "safety_sos_events",
  "safety_location_shares",
  "member_moderation_blocks",
  "member_user_reports",
  "direct_messages",
  "media_assets",
  "community_post_reactions",
  "business_directory_listings",
  "business_enquiries",
  "business_reports",
  "menstrual_cycle_logs",
  "menstrual_daily_logs",
  "menstrual_tracker_preferences",
  "community_directory_profiles",
  "eligibility_consents",
  "eligibility_support_requests",
  "eligibility_verification_sessions",
  "audit_events",
  "moderation_decisions",
  "admin_staff_accounts",
  "discreet_complaints",
  "eligibility_provider_callback_events"
];
const POSTGRES_OWNED_TABLES = [
  "admin_auth_sessions",
  "admin_bootstrap_credentials",
  "admin_staff_backup_codes",
  "admin_staff_mfa",
  "admin_staff_recovery_requests",
  "admin_staff_sessions",
  "community_circle_memberships",
  "community_circle_posts",
  "member_push_tokens",
  "member_wellness_preferences"
];
const PROTECTED_TABLES = [
  "member_accounts",
  "auth_sessions",
  "otp_challenges",
  "account_deletion_requests",
  "member_profiles",
  "member_consents",
  "member_communication_preferences",
  "eligibility_submissions",
  "community_posts",
  "community_post_likes",
  "community_post_saves",
  "community_post_comments",
  "community_groups",
  "community_circle_memberships",
  "community_circle_posts",
  "member_follows",
  "member_privacy_preferences",
  "member_notification_preferences",
  "member_push_tokens",
  "member_wellness_preferences",
  "member_notifications",
  "safety_emergency_contacts",
  "safety_sos_events",
  "safety_location_shares",
  "member_moderation_blocks",
  "member_user_reports",
  "direct_messages",
  "media_assets",
  "community_post_reactions",
  "business_directory_listings",
  "business_enquiries",
  "business_reports",
  "menstrual_cycle_logs",
  "menstrual_daily_logs",
  "menstrual_tracker_preferences",
  "community_directory_profiles",
  "eligibility_consents",
  "eligibility_support_requests",
  "eligibility_verification_sessions",
  "audit_events",
  "moderation_decisions",
  "admin_staff_accounts",
  "admin_staff_sessions",
  "admin_staff_mfa",
  "admin_staff_backup_codes",
  "admin_staff_recovery_requests",
  "admin_auth_sessions",
  "discreet_complaints",
  "eligibility_provider_callback_events",
  "admin_bootstrap_credentials"
];

function databaseUrl(raw, expectedUser, ca, requireSchema) {
  if (!raw) throw new Error("Required staging database URL is missing.");
  const parsed = new URL(raw);
  if (
    !["postgres:", "postgresql:"].includes(parsed.protocol) ||
    parsed.hostname !== EXPECTED_HOST ||
    parsed.port !== "5432" ||
    parsed.pathname !== "/postgres" ||
    decodeURIComponent(parsed.username) !== expectedUser ||
    decodeURIComponent(parsed.password).length < 32 ||
    decodeURIComponent(parsed.password).includes("REPLACE_WITH") ||
    decodeURIComponent(parsed.password).includes("[YOUR-PASSWORD]") ||
    (requireSchema && parsed.searchParams.get("schema") !== "public") ||
    parsed.searchParams.get("sslmode") !== "verify-full"
  ) {
    throw new Error("Staging database URL failed the exact project, role, port, schema or TLS checks.");
  }
  parsed.searchParams.delete("sslmode");
  parsed.searchParams.delete("sslrootcert");
  parsed.searchParams.delete("sslcert");
  parsed.searchParams.delete("schema");
  return {
    connectionString: parsed.toString(),
    ssl: { ca, rejectUnauthorized: true },
    connectionTimeoutMillis: 10000,
    statement_timeout: 30000,
    query_timeout: 45000,
  };
}

async function connect(raw, role, ca) {
  const client = new Client(
    databaseUrl(raw, `${role}.${PROJECT_REF}`, ca, role === "sakhi_staging_migrator"),
  );
  await client.connect();
  return client;
}

async function verifyOwners(postgres) {
  const result = await postgres.query(
    `SELECT c.relname, pg_get_userbyid(c.relowner) AS owner
     FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
     WHERE n.nspname='public' AND c.relkind='r'
       AND c.relname = ANY($1::text[])`,
    [PROTECTED_TABLES],
  );
  const owners = new Map(result.rows.map((row) => [row.relname, row.owner]));
  if (owners.size !== PROTECTED_TABLES.length) {
    throw new Error("Protected table inventory differs from the reviewed Stage 4 migration.");
  }
  for (const table of MIGRATOR_OWNED_TABLES) {
    if (owners.get(table) !== "sakhi_staging_migrator") {
      throw new Error(`Unexpected owner for protected table ${table}; refusing Stage 4 migration.`);
    }
  }
  for (const table of POSTGRES_OWNED_TABLES) {
    if (owners.get(table) !== "postgres") {
      throw new Error(`Unexpected owner for protected table ${table}; refusing Stage 4 migration.`);
    }
  }
}

async function roleAndConnectionPreflight(postgres, migrator) {
  const pgIdentity = await postgres.query(
    `SELECT current_database() AS database_name, current_user AS role_name,
            r.rolsuper, r.rolbypassrls,
            pg_has_role(current_user,'sakhi_staging_migrator','SET') AS can_set_migrator
     FROM pg_roles r WHERE r.rolname=current_user`,
  );
  const p = pgIdentity.rows[0];
  if (
    p?.database_name !== "postgres" ||
    p?.role_name !== "postgres" ||
    p?.rolsuper !== false ||
    p?.rolbypassrls !== true ||
    p?.can_set_migrator !== true
  ) {
    throw new Error("Restricted postgres connection does not match the reviewed Stage 4 execution boundary.");
  }
  const migratorIdentity = await migrator.query(
    `SELECT current_database() AS database_name, current_user AS role_name,
            r.rolsuper, r.rolbypassrls
     FROM pg_roles r WHERE r.rolname=current_user`,
  );
  const m = migratorIdentity.rows[0];
  if (
    m?.database_name !== "postgres" ||
    m?.role_name !== "sakhi_staging_migrator" ||
    m?.rolsuper !== false ||
    m?.rolbypassrls !== false
  ) {
    throw new Error("Dedicated staging migrator connection does not match the reviewed role boundary.");
  }
  const runtimeRoles = await postgres.query(
    `SELECT rolname,rolsuper,rolbypassrls
     FROM pg_roles
     WHERE rolname = ANY(ARRAY['sakhi_staging_app','anon','authenticated','service_role']::name[])`,
  );
  const roleMap = new Map(runtimeRoles.rows.map((row) => [row.rolname, row]));
  if (
    roleMap.get("sakhi_staging_app")?.rolsuper !== false ||
    roleMap.get("sakhi_staging_app")?.rolbypassrls !== false ||
    roleMap.get("anon")?.rolsuper !== false ||
    roleMap.get("anon")?.rolbypassrls !== false ||
    roleMap.get("authenticated")?.rolsuper !== false ||
    roleMap.get("authenticated")?.rolbypassrls !== false ||
    roleMap.get("service_role")?.rolsuper !== false ||
    roleMap.get("service_role")?.rolbypassrls !== true
  ) {
    throw new Error("Supabase Data API and Sakhi runtime role attributes differ from the reviewed RLS model.");
  }
  await verifyOwners(postgres);
}

async function migrationLedger(migrator) {
  const result = await migrator.query(
    "SELECT migration_name,finished_at,rolled_back_at FROM public._prisma_migrations",
  );
  const applied = new Set(
    result.rows
      .filter((row) => row.finished_at && !row.rolled_back_at)
      .map((row) => row.migration_name),
  );
  const failed = result.rows.filter((row) => !row.finished_at && !row.rolled_back_at);
  if (failed.length) throw new Error("Prisma migration ledger contains an unfinished migration.");
  const unknown = [...applied].filter((name) => !fs.existsSync(path.join(__dirname, "..", "prisma", "migrations", name, "migration.sql")));
  if (unknown.length) throw new Error("Prisma migration ledger contains an unknown applied migration.");
  return applied;
}

async function state(postgres) {
  const legacyMfaResult = await postgres.query(
    `SELECT
       to_regclass('public.admin_staff_mfa') IS NOT NULL AS mfa_table_exists,
       EXISTS (
         SELECT 1 FROM information_schema.columns
         WHERE table_schema='public' AND table_name='admin_staff_mfa'
           AND column_name='enrollment_verified_at'
       ) AS has_enrollment_verified_at,
       EXISTS (
         SELECT 1 FROM information_schema.columns
         WHERE table_schema='public' AND table_name='admin_staff_mfa'
           AND column_name='disabled_at'
       ) AS has_disabled_at,
       EXISTS (
         SELECT 1 FROM information_schema.columns
         WHERE table_schema='public' AND table_name='admin_staff_accounts'
           AND column_name='mfa_enabled'
       ) AS legacy_flag_present`,
  );
  const legacyMfa = legacyMfaResult.rows[0];
  if (
    legacyMfa?.mfa_table_exists !== true ||
    legacyMfa?.has_enrollment_verified_at !== true ||
    legacyMfa?.has_disabled_at !== true
  ) {
    throw new Error("Per-staff MFA lifecycle columns are missing; refusing legacy flag cleanup.");
  }
  const mfaCleanupApplied = legacyMfa.legacy_flag_present === false;

  const roleResult = await postgres.query(
    `SELECT c.conname,c.convalidated,
            col.column_default
     FROM (VALUES
       ('admin_staff_accounts_role_allowed_check'),
       ('admin_staff_accounts_status_allowed_check'),
       ('admin_staff_accounts_reviewer_role_check')
     ) expected(name)
     LEFT JOIN pg_constraint c
       ON c.conrelid='public.admin_staff_accounts'::regclass
      AND c.conname=expected.name
     CROSS JOIN LATERAL (
       SELECT column_default
       FROM information_schema.columns
       WHERE table_schema='public' AND table_name='admin_staff_accounts'
         AND column_name=CASE
           WHEN expected.name='admin_staff_accounts_role_allowed_check' THEN 'role'
           ELSE 'status'
         END
     ) col`,
  );
  const presentConstraints = roleResult.rows.filter((row) => row.conname && row.convalidated).length;
  const defaultsAbsent = roleResult.rows.every((row) => row.column_default === null);
  const roleApplied = presentConstraints === 3 && defaultsAbsent;
  const rolePartial = (presentConstraints > 0 || roleResult.rows.some((row) => row.column_default === null)) && !roleApplied;

  const functionResult = await postgres.query(
    `SELECT COALESCE(proconfig @> ARRAY['search_path=pg_catalog']::text[],false) AS pinned
     FROM pg_proc WHERE oid='public.guard_admin_bootstrap_credential_consumption()'::regprocedure`,
  );
  const functionApplied = functionResult.rows[0]?.pinned === true;

  const dataResult = await postgres.query(
    `WITH t AS (SELECT unnest($1::text[]) AS table_name),
          r AS (SELECT unnest(ARRAY['anon','authenticated','service_role']::text[]) AS role_name)
     SELECT
       NOT EXISTS (
         SELECT 1 FROM t CROSS JOIN r
         WHERE has_table_privilege(r.role_name,format('public.%I',t.table_name),'SELECT')
            OR has_table_privilege(r.role_name,format('public.%I',t.table_name),'INSERT')
            OR has_table_privilege(r.role_name,format('public.%I',t.table_name),'UPDATE')
            OR has_table_privilege(r.role_name,format('public.%I',t.table_name),'DELETE')
            OR has_table_privilege(r.role_name,format('public.%I',t.table_name),'TRUNCATE')
            OR has_table_privilege(r.role_name,format('public.%I',t.table_name),'REFERENCES')
            OR has_table_privilege(r.role_name,format('public.%I',t.table_name),'TRIGGER')
            OR has_any_column_privilege(r.role_name,format('public.%I',t.table_name),'SELECT')
            OR has_any_column_privilege(r.role_name,format('public.%I',t.table_name),'INSERT')
            OR has_any_column_privilege(r.role_name,format('public.%I',t.table_name),'UPDATE')
            OR has_any_column_privilege(r.role_name,format('public.%I',t.table_name),'REFERENCES')
       ) AS no_data_api_grants,
       has_table_privilege('sakhi_staging_app','public.member_accounts','SELECT')
       AND has_table_privilege('sakhi_staging_app','public.member_profiles','SELECT')
       AND has_table_privilege('sakhi_staging_app','public.admin_staff_accounts','SELECT')
         AS app_grants_preserved,
       NOT EXISTS (
         SELECT 1
         FROM pg_default_acl d
         JOIN pg_namespace n ON n.oid=d.defaclnamespace
         CROSS JOIN LATERAL aclexplode(d.defaclacl) x
         WHERE n.nspname='public'
           AND d.defaclrole IN (
             (SELECT oid FROM pg_roles WHERE rolname='postgres'),
             (SELECT oid FROM pg_roles WHERE rolname='sakhi_staging_migrator')
           )
           AND x.grantee IN (
             0,
             (SELECT oid FROM pg_roles WHERE rolname='anon'),
             (SELECT oid FROM pg_roles WHERE rolname='authenticated'),
             (SELECT oid FROM pg_roles WHERE rolname='service_role')
           )
       ) AS default_acl_hardened`,
    [PROTECTED_TABLES],
  );
  const data = dataResult.rows[0];
  const dataApplied =
    data?.no_data_api_grants === true &&
    data?.app_grants_preserved === true &&
    data?.default_acl_hardened === true;
  return {
    mfaCleanupApplied,
    roleApplied,
    rolePartial,
    functionApplied,
    dataApplied,
  };
}

function stripTransaction(sql) {
  return sql.replace(/^\s*BEGIN;\s*/i, "").replace(/\s*COMMIT;\s*$/i, "");
}

async function applyMissingMigrations(postgres, currentState) {
  const migrationRoot = path.join(__dirname, "..", "prisma", "migrations");
  const files = MIGRATIONS.map((name) =>
    fs.readFileSync(path.join(migrationRoot, name, "migration.sql"), "utf8"),
  );
  await postgres.query("BEGIN");
  try {
    if (!currentState.mfaCleanupApplied || !currentState.roleApplied) {
      await postgres.query("SET LOCAL ROLE sakhi_staging_migrator");
      if (!currentState.mfaCleanupApplied) {
        await postgres.query(stripTransaction(files[0]));
      }
      if (!currentState.roleApplied) {
        await postgres.query(stripTransaction(files[1]));
      }
      await postgres.query("RESET ROLE");
    }
    if (!currentState.functionApplied) {
      await postgres.query(stripTransaction(files[2]));
    }
    if (!currentState.dataApplied) {
      await postgres.query(stripTransaction(files[3]));
    }
    await postgres.query("COMMIT");
  } catch (error) {
    await postgres.query("ROLLBACK").catch(() => undefined);
    throw error;
  }
}

async function main() {
  if (process.env.SAKHI_ENV !== "staging") throw new Error("SAKHI_ENV must be staging.");
  if (process.env.SAKHI_MIGRATION_TARGET !== MIGRATION_TARGET) throw new Error("Exact Stage 4 migration target is required.");
  if (process.env.SAKHI_ALLOW_STAGING_MIGRATIONS !== APPROVAL_PHRASE) throw new Error("Exact Stage 4 approval phrase is required.");
  const caPath = path.join(__dirname, "..", "prod-ca-2021.crt");
  if (!fs.existsSync(caPath)) {
    throw new Error("The reviewed Supabase root CA file is missing from the backend release tree.");
  }
  const ca = fs.readFileSync(caPath, "utf8");
  if (!ca.includes("-----BEGIN CERTIFICATE-----") || !ca.includes("-----END CERTIFICATE-----")) {
    throw new Error("Verified Supabase CA certificate is invalid.");
  }

  const postgres = await connect(
    process.env.SAKHI_STAGING_POSTGRES_DATABASE_URL,
    "postgres",
    ca,
  );
  let migrator;
  try {
    migrator = await connect(
      process.env.SAKHI_MIGRATOR_DATABASE_URL,
      "sakhi_staging_migrator",
      ca,
    );
    await roleAndConnectionPreflight(postgres, migrator);
    const applied = await migrationLedger(migrator);
    const migrationRoot = path.join(__dirname, "..", "prisma", "migrations");
    const localMigrations = fs
      .readdirSync(migrationRoot, { withFileTypes: true })
      .filter((entry) => entry.isDirectory())
      .map((entry) => entry.name);
    const unexpectedPending = localMigrations.filter(
      (name) => !applied.has(name) && !MIGRATIONS.includes(name),
    );
    const missingReviewed = MIGRATIONS.filter(
      (name) => !localMigrations.includes(name),
    );
    if (unexpectedPending.length || missingReviewed.length) {
      throw new Error("Prisma pending migration inventory differs from the exact reviewed Stage 4 target.");
    }
    const pendingStage4 = MIGRATIONS.filter((name) => !applied.has(name));
    const currentState = await state(postgres);
    if (currentState.rolePartial) {
      throw new Error("Admin role constraints are partially applied; refusing automatic repair.");
    }
    const ledgerPostconditionMismatch = [
      [MIGRATIONS[0], currentState.mfaCleanupApplied],
      [MIGRATIONS[1], currentState.roleApplied],
      [MIGRATIONS[2], currentState.functionApplied],
      [MIGRATIONS[3], currentState.dataApplied],
    ].some(([migrationName, postconditionSatisfied]) =>
      applied.has(migrationName) && !postconditionSatisfied,
    );
    if (ledgerPostconditionMismatch) {
      throw new Error("Prisma migration history claims Stage 4 is applied but database postconditions disagree; refusing automatic repair.");
    }

    if (
      !currentState.mfaCleanupApplied ||
      !currentState.roleApplied ||
      !currentState.functionApplied ||
      !currentState.dataApplied
    ) {
      await applyMissingMigrations(postgres, currentState);
    }

    const finalState = await state(postgres);
    if (!finalState.mfaCleanupApplied || !finalState.roleApplied || !finalState.functionApplied || !finalState.dataApplied) {
      throw new Error("Stage 4 database postflight failed; Prisma migration ledger was not changed.");
    }

    // Record only the exact migrations whose DDL has passed all postflight checks.
    for (const migration of pendingStage4) {
      const executable = process.platform === "win32" ? "npx.cmd" : "npx";
      const resolved = spawnSync(
        executable,
        ["prisma", "migrate", "resolve", "--applied", migration],
        {
          cwd: path.join(__dirname, ".."),
          env: process.env,
          encoding: "utf8",
        },
      );
      if (resolved.status !== 0) {
        throw new Error(`Stage 4 DDL is applied, but Prisma could not record migration ${migration}; rerun this script to reconcile the ledger.`);
      }
    }

    const finalLedger = await migrationLedger(migrator);
    const missingLedger = MIGRATIONS.filter((name) => !finalLedger.has(name));
    if (missingLedger.length) {
      throw new Error("One or more Stage 4 migrations are still missing from the Prisma ledger.");
    }
    process.stdout.write(
      "Stage 4 RBAC/RLS migrations applied and postflight-verified; Prisma migration history reconciled.\n",
    );
  } finally {
    await Promise.all([
      postgres.end().catch(() => undefined),
      migrator?.end().catch(() => undefined),
    ]);
  }
}

main().catch((error) => {
  const code = error && typeof error.code === "string" ? error.code : "STAGE4_MIGRATION";
  const safeMessage = String(error && error.message ? error.message : "No safe diagnostic available.")
    .replace(/postgres(?:ql)?:\/\/\S+/gi, "[REDACTED CONNECTION]")
    .replace(/password[=: ]+\S+/gi, "password=[REDACTED]")
    .slice(0, 240);
  process.stderr.write(`Stage 4 migration failed (${code}): ${safeMessage}\n`);
  process.exitCode = 1;
});
