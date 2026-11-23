const fs = require("node:fs");
const path = require("node:path");
const { spawnSync } = require("node:child_process");
const { Client } = require("pg");

const PROJECT_REF = "wmlpokholjfadyohdlgo";
const EXPECTED_HOST = "aws-0-ap-south-1.pooler.supabase.com";
const MIGRATION = "20261120130000_community_followers_rls_performance";
const MIGRATION_TARGET = MIGRATION;
const APPROVAL_PHRASE = "YES_APPLY_20261120_COMMUNITY_FOLLOWERS_RLS";
const PROTECTED_TABLES = ["community_posts", "media_assets", "member_follows"];

function config(raw, expectedUser, ca, schemaRequired) {
  if (!raw) throw new Error("Required staging database URL is missing.");
  const url = new URL(raw);
  const password = decodeURIComponent(url.password);
  const checks = {
    protocol: ["postgres:", "postgresql:"].includes(url.protocol),
    host: url.hostname === EXPECTED_HOST,
    port: url.port === "5432",
    database: url.pathname === "/postgres",
    username: decodeURIComponent(url.username) === expectedUser,
    passwordPresentAndPlausible:
      password.length >= 32 &&
      !password.includes("REPLACE_WITH") &&
      !password.includes("[YOUR-PASSWORD]"),
    schema: !schemaRequired || url.searchParams.get("schema") === "public",
    sslmode: ["verify-full", "require"].includes(url.searchParams.get("sslmode")),
  };
  const failedChecks = Object.entries(checks)
    .filter(([, passed]) => !passed)
    .map(([name]) => name);
  if (failedChecks.length) {
    // Deliberately report only field names, never URL values or credentials.
    throw new Error(
      "Staging database URL validation failed fields: " + failedChecks.join(", ") + "."
    );
  }
  // Supabase pooler URIs commonly use sslmode=require. This is safe here because
  // the connection below independently enforces the pinned Supabase Root 2021 CA
  // with rejectUnauthorized=true (certificate-chain and hostname verification).
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

async function connect(raw, role, ca) {
  const expectedUser = role === "postgres"
    ? `postgres.${PROJECT_REF}`
    : `sakhi_staging_migrator.${PROJECT_REF}`;
  const client = new Client(config(raw, expectedUser, ca, role === "sakhi_staging_migrator"));
  await client.connect();
  return client;
}

async function assertIdentity(postgres, migrator) {
  const pg = await postgres.query(
    `SELECT current_database() AS db,current_user AS role,r.rolsuper,r.rolbypassrls,
            pg_has_role(current_user,'sakhi_staging_migrator','SET') AS can_set_migrator
     FROM pg_roles r WHERE r.rolname=current_user`,
  );
  const p = pg.rows[0];
  if (p?.db !== "postgres" || p?.role !== "postgres" || p?.rolsuper !== false ||
      p?.rolbypassrls !== true || p?.can_set_migrator !== true) {
    throw new Error("Restricted staging postgres connection did not match the reviewed execution boundary.");
  }
  const mr = await migrator.query(
    `SELECT current_database() AS db,current_user AS role,r.rolsuper,r.rolbypassrls
     FROM pg_roles r WHERE r.rolname=current_user`,
  );
  const m = mr.rows[0];
  if (m?.db !== "postgres" || m?.role !== "sakhi_staging_migrator" ||
      m?.rolsuper !== false || m?.rolbypassrls !== false) {
    throw new Error("Dedicated staging migrator identity or role attributes are incorrect.");
  }
  const ownership = await postgres.query(
    `SELECT c.relname,pg_get_userbyid(c.relowner) AS owner
     FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
     WHERE n.nspname='public' AND c.relkind IN ('r','p')
       AND c.relname=ANY($1::text[])`,
    [PROTECTED_TABLES],
  );
  const owners = new Map(ownership.rows.map(x => [x.relname,x.owner]));
  if (owners.size !== PROTECTED_TABLES.length ||
      PROTECTED_TABLES.some(name => owners.get(name) !== "sakhi_staging_migrator")) {
    throw new Error("Community table ownership differs from the reviewed migration execution boundary.");
  }
  const appRole = await postgres.query(
    "SELECT rolsuper,rolbypassrls FROM pg_roles WHERE rolname='sakhi_staging_app'",
  );
  if (appRole.rows[0]?.rolsuper !== false || appRole.rows[0]?.rolbypassrls !== false) {
    throw new Error("Sakhi staging runtime role is missing or has unsafe role attributes.");
  }
}

async function ledger(migrator) {
  const result = await migrator.query(
    "SELECT migration_name,finished_at,rolled_back_at FROM public._prisma_migrations",
  );
  const failed = result.rows.filter(x => !x.finished_at && !x.rolled_back_at);
  if (failed.length) throw new Error("Prisma migration ledger contains an unfinished migration.");
  const applied = new Set(result.rows.filter(x => x.finished_at && !x.rolled_back_at).map(x => x.migration_name));
  const root = path.join(__dirname, "..", "prisma", "migrations");
  const local = fs.readdirSync(root,{withFileTypes:true}).filter(x=>x.isDirectory()).map(x=>x.name);
  if ([...applied].some(name => !local.includes(name))) {
    throw new Error("Prisma ledger contains migrations absent from this release tree.");
  }
  const unexpected = local.filter(name => !applied.has(name) && name !== MIGRATION);
  if (unexpected.length) throw new Error("Unexpected pending migrations exist; refusing to apply a partial release backlog.");
  if (!local.includes(MIGRATION)) throw new Error("Exact reviewed community RLS migration is missing from release tree.");
  return applied;
}

async function postflight(client) {
  const policies = await client.query(
    `SELECT polname,polcmd,polpermissive,
            'sakhi_staging_app'::regrole = ANY(polroles) AS includes_app,
            pg_get_expr(polqual,polrelid) AS using_expression
     FROM pg_policy
     WHERE polrelid IN ('public.community_posts'::regclass,'public.media_assets'::regclass)
       AND polname IN ('community_posts_followers_read','media_assets_followers_read')`,
  );
  const byName = new Map(policies.rows.map(x=>[x.polname,x]));
  for (const name of ["community_posts_followers_read","media_assets_followers_read"]) {
    const p = byName.get(name);
    if (!p || p.polcmd !== "r" || p.polpermissive !== true || p.includes_app !== true ||
        !p.using_expression?.includes("FOLLOWERS_ONLY") ||
        !p.using_expression?.includes("app.account_id")) {
      throw new Error(`Follower read policy postcondition failed: ${name}.`);
    }
  }
  const index = await client.query(
    `SELECT i.indisvalid,i.indisready,pg_get_indexdef(i.indexrelid) AS definition
     FROM pg_index i
     JOIN pg_class idx ON idx.oid=i.indexrelid
     JOIN pg_namespace n ON n.oid=idx.relnamespace
     WHERE n.nspname='public' AND idx.relname='member_follows_directory_profile_id_idx'`,
  );
  const ix = index.rows[0];
  if (!ix?.indisvalid || !ix?.indisready ||
      !ix.definition.includes("USING btree (directory_profile_id)")) {
    throw new Error("Follower lookup index postcondition failed.");
  }
}

async function main() {
  if (process.env.SAKHI_ENV !== "staging") throw new Error("SAKHI_ENV must be staging.");
  if (process.env.SAKHI_MIGRATION_TARGET !== MIGRATION_TARGET) throw new Error("Exact community follower migration target is required.");
  if (process.env.SAKHI_ALLOW_STAGING_MIGRATIONS !== APPROVAL_PHRASE) throw new Error("Exact community follower migration approval phrase is required.");
  const caPath = path.join(__dirname, "..", "prod-ca-2021.crt");
  if (!fs.existsSync(caPath)) throw new Error("Pinned Supabase root CA file is missing.");
  const ca = fs.readFileSync(caPath,"utf8");
  if (!ca.includes("-----BEGIN CERTIFICATE-----") || !ca.includes("-----END CERTIFICATE-----")) {
    throw new Error("Pinned Supabase root CA certificate is invalid.");
  }
  const postgres = await connect(process.env.SAKHI_STAGING_POSTGRES_DATABASE_URL,"postgres",ca);
  let migrator;
  try {
    migrator = await connect(process.env.SAKHI_MIGRATOR_DATABASE_URL,"sakhi_staging_migrator",ca);
    await assertIdentity(postgres,migrator);
    const applied = await ledger(migrator);
    const alreadyApplied = applied.has(MIGRATION);
    if (alreadyApplied) {
      await postflight(postgres);
      process.stdout.write("Community follower RLS migration is already recorded and its database postconditions pass; no DDL executed.\n");
      return;
    }

    await postgres.query("BEGIN");
    try {
      await postgres.query("SET LOCAL ROLE sakhi_staging_migrator");
      const sql = fs.readFileSync(
        path.join(__dirname,"..","prisma","migrations",MIGRATION,"migration.sql"),"utf8"
      );
      await postgres.query(sql);
      await postgres.query("COMMIT");
    } catch (error) {
      await postgres.query("ROLLBACK").catch(()=>undefined);
      throw error;
    }

    await postflight(postgres);
    const executable = process.platform === "win32" ? "npx.cmd" : "npx";
    const resolved = spawnSync(executable,["prisma","migrate","resolve","--applied",MIGRATION],{
      cwd:path.join(__dirname,".."),env:process.env,encoding:"utf8"
    });
    if (resolved.status !== 0) {
      throw new Error("DDL and postflight succeeded, but Prisma history reconciliation failed; rerun this workflow to reconcile the exact migration.");
    }
    const finalLedger = await ledger(migrator);
    if (!finalLedger.has(MIGRATION)) throw new Error("Prisma migration ledger postcondition failed.");
    await postflight(postgres);
    process.stdout.write("Community follower RLS migration applied, postflight-verified, and Prisma history reconciled.\n");
  } finally {
    await Promise.all([postgres.end().catch(()=>undefined),migrator?.end().catch(()=>undefined)]);
  }
}

main().catch(error => {
  const code = typeof error?.code === "string" ? error.code : "COMMUNITY_FOLLOWER_RLS";
  const message = String(error?.message ?? "No safe diagnostic available.")
    .replace(/postgres(?:ql)?:\/\/\S+/gi,"[REDACTED CONNECTION]")
    .replace(/password[=: ]+\S+/gi,"password=[REDACTED]")
    .slice(0,240);
  process.stderr.write(`Community follower RLS migration failed (${code}): ${message}\n`);
  process.exitCode = 1;
});
