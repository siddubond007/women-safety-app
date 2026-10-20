import { defineConfig } from "prisma/config";
import {
  assertSakhiDatabaseTarget,
  parseSakhiEnvironment,
} from "./src/config/database-target.js";

function getMigrationDatasourceUrl(): string {
  const environment = parseSakhiEnvironment(process.env.SAKHI_ENV);
  const suppliedUrl = process.env.SAKHI_MIGRATOR_DATABASE_URL;

  if (environment === "staging") {
    if (!suppliedUrl) {
      throw new Error(
        "Staging migrations require an explicit SAKHI_MIGRATOR_DATABASE_URL supplied securely to the migration process.",
      );
    }
    assertSakhiDatabaseTarget(suppliedUrl, "migrator", "staging");
    return suppliedUrl;
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
