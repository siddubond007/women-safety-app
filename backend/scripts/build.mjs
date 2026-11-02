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

// Optional, one-time staging migration gate. Render's normal build never mutates a
// database; operators must explicitly set SAKHI_RUN_MODULE6_MIGRATION=true.
// Prisma's config enforces the exact staging Supabase host, database, role, TLS,
// and schema. This gate also refuses to apply any migration except Module 6.
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

function runOptionalModule6StagingMigration() {
  const flag = process.env.SAKHI_RUN_MODULE6_MIGRATION ?? "false";
  if (flag !== "true" && flag !== "false") {
    throw new Error("SAKHI_RUN_MODULE6_MIGRATION must be exactly 'true' or 'false'.");
  }
  if (flag !== "true") {
    return;
  }

  if (process.env.SAKHI_ENV !== "staging") {
    throw new Error("The one-time Module 6 migration gate only runs with SAKHI_ENV=staging.");
  }
  if (!process.env.SAKHI_MIGRATOR_DATABASE_URL) {
    throw new Error(
      "SAKHI_MIGRATOR_DATABASE_URL is missing. Refusing to deploy without the protected staging migrator.",
    );
  }

  const migrationEnv = { ...process.env, SAKHI_ENV: "staging" };
  const allowedMigration = "20261029190000_module6_business_pages";
  const pending = readPrismaMigrationStatus(migrationEnv);

  if (pending.length === 0) {
    console.log("Staging database is already current; no migration is needed.");
    return;
  }
  if (pending.length !== 1 || pending[0] !== allowedMigration) {
    throw new Error(
      "Refusing migration. The only allowed pending migration is " +
        allowedMigration +
        "; found: " +
        (pending.join(", ") || "none") +
        ".",
    );
  }

  console.log("Applying the verified additive Module 6 staging migration.");
  runNodeScript(
    "node_modules/prisma/build/index.js",
    ["migrate", "deploy"],
    migrationEnv,
  );

  const remaining = readPrismaMigrationStatus(migrationEnv);
  if (remaining.length !== 0) {
    throw new Error("Module 6 staging migration did not leave the database fully migrated.");
  }
  console.log("Module 6 staging migration verified successfully.");
}

try {
  runOptionalModule6StagingMigration();
} catch (error) {
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
}

// Prisma loads prisma.config.ts even for client generation. Keep only that
// child process in the local/offline schema-generation context so it can use
// the placeholder datasource and never needs the staging migrator URL.
// The parent build process and eventual Render runtime keep their original
// environment. Database mutation remains disabled by default; only the explicit
// staging flag above can run the single reviewed Module 6 migration.
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
