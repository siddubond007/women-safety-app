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
const PROTECTED_TABLES = [
  "member_accounts","auth_sessions","otp_challenges","account_deletion_requests",
  "member_profiles","member_consents","member_communication_preferences",
  "eligibility_submissions","community_posts","community_post_likes","community_post_saves",
  "community_post_comments","community_groups","community_circle_memberships","community_circle_posts",
  "member_follows","member_privacy_preferences","member_notification_preferences","member_push_tokens",
  "member_wellness_preferences","member_notifications","safety_emergency_contacts","safety_sos_events",
  "safety_location_shares","member_moderation_blocks","member_user_reports","direct_messages","media_assets",
  "community_post_reactions","business_directory_listings","business_enquiries","business_reports",
  "menstrual_cycle_logs","menstrual_daily_logs","menstrual_tracker_preferences","community_directory_profiles",
  "eligibility_consents","eligibility_support_requests","eligibility_verification_sessions","audit_events",
  "moderation_decisions","admin_staff_accounts","admin_staff_sessions","admin_staff_mfa",
  "admin_staff_backup_codes","admin_staff_recovery_requests","admin_auth_sessions","discreet_complaints",
  "eligibility_provider_callback_events","admin_bootstrap_credentials"
];

function getClientConfig(raw, ca) {
  if (!raw) throw new Error("Staging migrator URL is missing.");
  const url = new URL(raw);
  const password = decodeURIComponent(url.password);
  if (
    !["postgres:", "postgresql:"].includes(url.protocol) ||
    url.hostname !== EXPECTED_HOST ||
    url.port !== "5432" ||
    url.pathname !== "/postgres" ||
    decodeURIComponent(url.username) !== `sakhi_staging_migrator.${PROJECT_REF}` ||
    password.length < 32 ||
    password.includes("REPLACE_WITH") ||
    password.includes("[YOUR-PASSWORD]") ||
    url.searchParams.get("schema") !== "public" ||
    url.searchParams.get("sslmode") !== "verify-full"
  ) {
    throw new Error("Staging migrator URL failed the exact project, role, schema or TLS checks.");
  }
  url.searchParams.delete("sslmode");
  url.searchParams.delete("sslrootcert");
  url.searchParams.delete("sslcert");
  url.searchParams.delete("schema");
  return {
    connectionString: url.toString(),
    ssl: { ca, rejectUnauthorized: true },
    connectionTimeoutMillis: 10000,
    statement_timeout: 30000,
    query_timeout: 45000,
  };
}

async function inspectDatabase(client) {
  const legacyMfaResult = await client.query(
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
  const legacyMfaFlagRemoved =
    legacyMfa?.mfa_table_exists === true &&
    legacyMfa?.has_enrollment_verified_at === true &&
    legacyMfa?.has_disabled_at === true &&
    legacyMfa?.legacy_flag_present === false;

  const identity = await client.query(
    `SELECT current_database() AS database_name,current_user AS role_name,
            r.rolsuper,r.rolbypassrls
     FROM pg_roles r WHERE r.rolname=current_user`,
  );
  const actor = identity.rows[0];
  if (
    actor?.database_name !== "postgres" ||
    actor?.role_name !== "sakhi_staging_migrator" ||
    actor?.rolsuper !== false ||
    actor?.rolbypassrls !== false
  ) {
    throw new Error("Staging ledger connection does not match the restricted migrator role.");
  }

  const runtimeRoles = await client.query(
    `SELECT rolname,rolsuper,rolbypassrls
     FROM pg_roles
     WHERE rolname=ANY(ARRAY['sakhi_staging_app','anon','authenticated','service_role']::name[])`,
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

  const roleResult = await client.query(
    `SELECT c.conname,c.convalidated,col.column_default
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
  const constraintsValid = roleResult.rows.filter((row) => row.conname && row.convalidated).length === 3;
  const defaultsAbsent = roleResult.rows.length === 3 && roleResult.rows.every((row) => row.column_default === null);

  const functionResult = await client.query(
    `SELECT COALESCE(proconfig @> ARRAY['search_path=pg_catalog']::text[],false) AS pinned
     FROM pg_proc WHERE oid='public.guard_admin_bootstrap_credential_consumption()'::regprocedure`,
  );
  const functionPinned = functionResult.rows[0]?.pinned === true;

  const grantResult = await client.query(
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
  const grants = grantResult.rows[0];
  return {
    legacyMfaFlagRemoved,
    roleConstraints: constraintsValid && defaultsAbsent,
    functionSearchPath: functionPinned,
    dataApiGrants: grants?.no_data_api_grants === true,
    appGrants: grants?.app_grants_preserved === true,
    defaultAcl: grants?.default_acl_hardened === true,
  };
}

async function main() {
  if (process.env.SAKHI_ENV !== "staging") throw new Error("SAKHI_ENV must be staging.");
  if (process.env.SAKHI_MIGRATION_TARGET !== MIGRATION_TARGET) throw new Error("Exact Stage 4 migration target is required.");
  if (process.env.SAKHI_ALLOW_STAGING_MIGRATIONS !== APPROVAL_PHRASE) throw new Error("Exact Stage 4 approval phrase is required.");
  const caPath = path.join(__dirname, "..", "prod-ca-2021.crt");
  if (!fs.existsSync(caPath)) throw new Error("Reviewed Supabase root CA file is missing.");
  const ca = fs.readFileSync(caPath, "utf8");
  if (!ca.includes("-----BEGIN CERTIFICATE-----") || !ca.includes("-----END CERTIFICATE-----")) {
    throw new Error("Verified Supabase CA certificate is invalid.");
  }

  const client = new Client(getClientConfig(process.env.SAKHI_MIGRATOR_DATABASE_URL, ca));
  await client.connect();
  try {
    const state = await inspectDatabase(client);
    if (Object.values(state).some((value) => value !== true)) {
      throw new Error("Stage 4 database postconditions are not all satisfied; ledger reconciliation is blocked.");
    }

    const ledger = await client.query(
      "SELECT migration_name,finished_at,rolled_back_at FROM public._prisma_migrations",
    );
    const applied = new Set(
      ledger.rows
        .filter((row) => row.finished_at && !row.rolled_back_at)
        .map((row) => row.migration_name),
    );
    if (ledger.rows.some((row) => !row.finished_at && !row.rolled_back_at)) {
      throw new Error("Prisma migration ledger contains an unfinished migration.");
    }
    const pending = MIGRATIONS.filter((name) => !applied.has(name));
    const unknownApplied = [...applied].filter((name) =>
      !fs.existsSync(path.join(__dirname, "..", "prisma", "migrations", name, "migration.sql")),
    );
    if (unknownApplied.length) throw new Error("Prisma ledger contains a migration absent from this release tree.");

    for (const migration of pending) {
      const executable = process.platform === "win32" ? "npx.cmd" : "npx";
      const result = spawnSync(
        executable,
        ["prisma", "migrate", "resolve", "--applied", migration],
        { cwd: path.join(__dirname, ".."), env: process.env, encoding: "utf8" },
      );
      if (result.status !== 0) {
        throw new Error(`Prisma could not record already-verified Stage 4 migration ${migration}; rerun reconciliation.`);
      }
    }

    const finalLedger = await client.query(
      "SELECT migration_name,finished_at,rolled_back_at FROM public._prisma_migrations",
    );
    const finalApplied = new Set(
      finalLedger.rows
        .filter((row) => row.finished_at && !row.rolled_back_at)
        .map((row) => row.migration_name),
    );
    if (MIGRATIONS.some((name) => !finalApplied.has(name))) {
      throw new Error("Stage 4 migrations are still missing from Prisma migration history.");
    }
    process.stdout.write("Stage 4 database postconditions verified; Prisma migration history reconciled.\n");
  } finally {
    await client.end().catch(() => undefined);
  }
}

main().catch((error) => {
  const code = typeof error?.code === "string" ? error.code : "STAGE4_LEDGER";
  const safeMessage = String(error?.message ?? "No safe diagnostic available.")
    .replace(/postgres(?:ql)?:\/\/\S+/gi, "[REDACTED CONNECTION]")
    .replace(/password[=: ]+\S+/gi, "password=[REDACTED]")
    .slice(0, 240);
  process.stderr.write(`Stage 4 ledger reconciliation failed (${code}): ${safeMessage}\n`);
  process.exitCode = 1;
});
