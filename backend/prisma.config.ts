import { defineConfig } from "prisma/config";

type SakhiEnvironment = "dev" | "test";

function getMigrationDatasourceUrl(): string {
  const environment = (process.env.SAKHI_ENV ?? "dev") as SakhiEnvironment;
  if (environment !== "dev" && environment !== "test") {
    throw new Error("Only Sakhi dev/test environments are enabled in Stage 1.");
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
  const value = process.env.SAKHI_MIGRATOR_DATABASE_URL ?? fallback;

  let parsed: URL;
  try {
    parsed = new URL(value);
  } catch {
    throw new Error("SAKHI_MIGRATOR_DATABASE_URL is not a valid URL.");
  }

  const database = decodeURIComponent(parsed.pathname.slice(1));
  const username = decodeURIComponent(parsed.username);
  if (
    !["postgres:", "postgresql:"].includes(parsed.protocol) ||
    !["127.0.0.1", "localhost"].includes(parsed.hostname) ||
    database !== expectedDatabase ||
    username !== expectedUser ||
    parsed.searchParams.get("schema") !== "public"
  ) {
    throw new Error(
      "Database target rejected: migrations may only target the matching local Sakhi database.",
    );
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
