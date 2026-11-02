import { spawnSync } from "node:child_process";
import { resolve } from "node:path";

function runNodeScript(scriptPath, args, env) {
  const result = spawnSync(
    process.execPath,
    [resolve(scriptPath), ...args],
    {
      cwd: process.cwd(),
      env,
      stdio: "inherit",
      windowsHide: true,
    },
  );

  if (result.error) {
    console.error(result.error.message);
    process.exit(1);
  }

  if (result.signal) {
    console.error(`Build subprocess terminated by signal: ${result.signal}`);
    process.exit(1);
  }

  if (result.status !== 0) {
    process.exit(result.status ?? 1);
  }
}

// Render builds are read-only by default. An operator must explicitly enable
// this one-time gate for the dedicated staging service. Prisma's config checks
// the exact Supabase project, pooler, migrator role, database, TLS, and schema.
// This gate accepts only the reviewed Module 2 DM/session migrations that are
// pending after the already-applied Module 6 schema.
function readPrismaMigrationStatus(env) {
  const result = spawnSync(
    process.execPath,
    [resolve("node_modules/prisma/build/index.js"), "migrate", "status"],
    {
      cwd: process.cwd(),
      env,
      encoding: "utf8",
      windowsHide: true,
    },
  );

  if (result.error) {
    throw new Error("Could not inspect staging migration status: " + result.error.message);
  }

  const output =
    String(result.stdout ?? "") + "\n" + String(result.stderr ?? "");
  process.stdout.write(output);

  const pending = output
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter((line) => /^\d{14}_[A-Za-z0-9_-]+$/.test(line));

  if (/All migrations have been successfully applied|Database schema is up to date|No pending migrations/i.test(output)) {
    if (pending.length !== 0 || result.status !== 0) {
      throw new Error("Prisma reported an inconsistent completed migration state.");
    }
    return [];
  }

  if (/have not yet been applied/i.test(output) && pending.length > 0) {
    return pending;
  }

  throw new Error(
    "Could not establish a clean migration state (exit " +
      String(result.status ?? "unknown") +
      "). No migration was attempted.",
  );
}

function runOptionalStagingReleaseMigrations() {
  const flag = process.env.SAKHI_RUN_STAGING_RELEASE_MIGRATIONS ?? "false";
  if (flag !== "true" && flag !== "false") {
    throw new Error("SAKHI_RUN_STAGING_RELEASE_MIGRATIONS must be exactly 'true' or 'false'.");
  }
  if (flag !== "true") {
    return;
  }

  if (process.env.SAKHI_ENV !== "staging") {
    throw new Error("The staging release migration gate only runs with SAKHI_ENV=staging.");
  }
  if (!process.env.SAKHI_MIGRATOR_DATABASE_URL) {
    throw new Error(
      "SAKHI_MIGRATOR_DATABASE_URL is missing. Refusing to deploy without the protected staging migrator.",
    );
  }

  const migrationEnv = { ...process.env, SAKHI_ENV: "staging" };
  const allowedMigrations = [
    "20261101120000_direct_message_dedicated_storage",
    "20261101130000_direct_message_runtime_grants",
    "20261101140000_auth_session_device_metadata",
  ];
  const pending = readPrismaMigrationStatus(migrationEnv);
  const unexpected = pending.filter((name) => !allowedMigrations.includes(name));
  const pendingOrder = pending.map((name) => allowedMigrations.indexOf(name));

  if (
    unexpected.length > 0 ||
    pendingOrder.some((index, position) => index < 0 || (position > 0 && index <= pendingOrder[position - 1]))
  ) {
    throw new Error(
      "Refusing staging migration. Only the reviewed Direct Message and session metadata migrations are allowed; found: " +
        (pending.join(", ") || "none") +
        ".",
    );
  }

  if (pending.length > 0) {
    console.log("Applying the exact reviewed staging Direct Message/session migrations.");
    runNodeScript(
      "node_modules/prisma/build/index.js",
      ["migrate", "deploy"],
      migrationEnv,
    );
  } else {
    console.log("Staging Prisma migration ledger is already current.");
  }

  const remaining = readPrismaMigrationStatus(migrationEnv);
  if (remaining.length !== 0) {
    throw new Error("Staging release migrations did not leave the database fully migrated.");
  }

  // The migration-specific grant intentionally skips hosted PostgreSQL. Apply
  // the checked-in least-privilege grant file after the new DM table exists.
  // This is idempotent and keeps DDL privileges out of the runtime app role.
  console.log("Applying reviewed least-privilege staging runtime grants.");
  runNodeScript(
    "node_modules/prisma/build/index.js",
    ["db", "execute", "--file", "prisma/staging/runtime-grants.sql"],
    migrationEnv,
  );

  console.log("Staging release migrations and runtime grants verified successfully.");
}

try {
  runOptionalStagingReleaseMigrations();
} catch (error) {
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
}

// Prisma loads prisma.config.ts even for client generation. Keep only that
// child process in the local/offline schema-generation context so it can use
// the placeholder datasource and never needs the staging migrator URL.
// The parent build process and eventual Render runtime keep their original
// environment. Database mutation remains disabled by default; only the explicit
// staging flag above can run the three reviewed migrations.
console.log(
  "Generating Prisma Client in isolated offline build context (SAKHI_ENV=dev).",
);
const prismaGenerationEnv = {
  ...process.env,
  SAKHI_ENV: "dev",
};
delete prismaGenerationEnv.SAKHI_MIGRATOR_DATABASE_URL;
runNodeScript("node_modules/prisma/build/index.js", ["generate"], prismaGenerationEnv);

// TypeScript compilation inherits the caller environment. It does not need
// database access or migration credentials.
console.log("Compiling NestJS backend.");
runNodeScript("node_modules/typescript/bin/tsc", ["-p", "tsconfig.build.json"], {
  ...process.env,
});
