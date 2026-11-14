import { defineConfig } from "prisma/config";
import { spawnSync } from "node:child_process";
import { join } from "node:path";
import {
  assertSakhiDatabaseTarget,
  parseSakhiEnvironment,
} from "./src/config/database-target.js";

function getMigrationDatasourceUrl(): string {
  const environment = parseSakhiEnvironment(process.env.SAKHI_ENV);
  const suppliedUrl = process.env.SAKHI_MIGRATOR_DATABASE_URL;

  if (environment === "staging") {
    const [commandGroup, commandAction] = process.argv.slice(2);
    const migrationApproved =
      process.env.SAKHI_MIGRATION_TARGET ===
        "20261113130000_allow_scoped_system_auth_audit,20261113140000_retention_deletion_runtime_grants,20261114110000_scope_retention_system_audit" &&
      process.env.SAKHI_ALLOW_STAGING_MIGRATIONS ===
        "YES_APPLY_20261113_14_STAGE3B2";
    const bootstrapApproved =
      process.env.SAKHI_ALLOW_STAGING_BOOTSTRAP ===
      "YES_BOOTSTRAP_SAKHI_STAGING_EMPTY_DATABASE";
    const readOnlyCommand =
      commandGroup === "generate" ||
      commandGroup === "validate" ||
      commandGroup === "format" ||
      commandGroup === "version" ||
      (commandGroup === "migrate" && commandAction === "status");

    if (!readOnlyCommand) {
      if (
        commandGroup === "migrate" &&
        commandAction === "deploy" &&
        !migrationApproved
      ) {
        throw new Error(
          "Staging migrate deploy requires the exact reviewed migration target and explicit approval phrase.",
        );
      }
      if (
        commandGroup === "migrate" &&
        commandAction === "deploy" &&
        migrationApproved
      ) {
        const preflight = spawnSync(
          process.execPath,
          [join(process.cwd(), "scripts", "staging-preflight.cjs"), "migrations"],
          { cwd: process.cwd(), env: process.env, encoding: "utf8" },
        );
        if (preflight.status !== 0) {
          throw new Error(
            "Staging migration preflight failed; Prisma migrate deploy is blocked.",
          );
        }
      }
      if (
        commandGroup === "migrate" &&
        commandAction === "resolve" &&
        !bootstrapApproved
      ) {
        throw new Error(
          "Staging migrate resolve is restricted to an explicitly approved fresh-schema bootstrap.",
        );
      }
      if (
        commandGroup === "db" &&
        commandAction === "execute" &&
        !(migrationApproved || bootstrapApproved)
      ) {
        throw new Error(
          "Staging SQL execution requires explicit migration or fresh-bootstrap approval.",
        );
      }
      if (
        !(
          (commandGroup === "migrate" &&
            (commandAction === "deploy" || commandAction === "resolve")) ||
          (commandGroup === "db" && commandAction === "execute")
        )
      ) {
        throw new Error(
          "This Prisma command is blocked for staging; only read-only checks and explicitly approved operations are allowed.",
        );
      }
    }
    if (!suppliedUrl) {
      throw new Error(
        "Staging migrations require an explicit SAKHI_MIGRATOR_DATABASE_URL supplied securely to the migration process.",
      );
    }
    const normalizedUrl = new URL(suppliedUrl);
    // Render may still hold the legacy sslcert query parameter. Normalize it
    // to Prisma's sslrootcert parameter and remove sslcert (a client-cert option).
    if (!normalizedUrl.searchParams.has("sslrootcert")) {
      const legacyRootCert = normalizedUrl.searchParams.get("sslcert");
      if (legacyRootCert) {
        normalizedUrl.searchParams.set("sslrootcert", legacyRootCert);
      }
    }
    normalizedUrl.searchParams.delete("sslcert");
    const validatedUrl = normalizedUrl.toString();
    assertSakhiDatabaseTarget(validatedUrl, "migrator", "staging");
    return validatedUrl;
  }

  const expectedDatabase = environment === "test" ? "sakhi_test" : "sakhi_dev";
  const expectedUser =
    environment === "test" ? "sakhi_test_migrator" : "sakhi_dev_migrator";
  const fallback =
    "postgresql://" +
    expectedUser +
    ":SCHEMA_ONLY_DO_NOT_CONNECT@127.0.0.1:5432/" +
    expectedDatabase +
    "?schema=public";
  const value = suppliedUrl ?? fallback;

  // The placeholder fallback is only for offline commands such as prisma generate.
  // Any real local connection string must still pass the dev/test database guard.
  if (suppliedUrl) {
    assertSakhiDatabaseTarget(suppliedUrl, "migrator", environment);
  }

  return value;
}

const migrationUrl = getMigrationDatasourceUrl();

export default defineConfig({
  schema: "prisma/schema.prisma",
  migrations: {
    path: "prisma/migrations",
    seed: "tsx prisma/seed.ts",
  },
  datasource: {
    url: migrationUrl,
  },
});
