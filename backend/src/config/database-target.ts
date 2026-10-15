export type SakhiEnvironment = "dev" | "test";
export type DatabasePurpose = "app" | "migrator";

export interface ParsedSakhiDatabaseTarget {
  environment: SakhiEnvironment;
  databaseName: "sakhi_dev" | "sakhi_test";
  username: string;
}

export function parseSakhiEnvironment(value: unknown): SakhiEnvironment {
  if (value === undefined || value === null || value === "") {
    return "dev";
  }
  if (value === "dev" || value === "test") {
    return value;
  }
  throw new Error('SAKHI_ENV must be either "dev" or "test" in Stage 1.');
}

export function assertSakhiDatabaseTarget(
  rawUrl: string | undefined,
  purpose: DatabasePurpose,
  environment: SakhiEnvironment,
): ParsedSakhiDatabaseTarget {
  if (!rawUrl) {
    throw new Error("The required Sakhi database URL is not configured.");
  }

  let parsed: URL;
  try {
    parsed = new URL(rawUrl);
  } catch {
    throw new Error("The Sakhi database URL is invalid.");
  }

  const databaseName = environment === "test" ? "sakhi_test" : "sakhi_dev";
  const username =
    purpose === "app"
      ? environment === "test"
        ? "sakhi_test_app"
        : "sakhi_dev_app"
      : environment === "test"
        ? "sakhi_test_migrator"
        : "sakhi_dev_migrator";

  if (
    (parsed.protocol !== "postgres:" && parsed.protocol !== "postgresql:") ||
    !["127.0.0.1", "localhost"].includes(parsed.hostname) ||
    decodeURIComponent(parsed.pathname.slice(1)) !== databaseName ||
    decodeURIComponent(parsed.username) !== username ||
    parsed.password.length === 0 ||
    parsed.password === "SCHEMA_ONLY_DO_NOT_CONNECT" ||
    parsed.searchParams.get("schema") !== "public"
  ) {
    throw new Error(
      "Database target rejected. This process may only use its own local Sakhi dev/test database and least-privilege role.",
    );
  }

  return { environment, databaseName, username };
}

export function validateRuntimeEnvironment(
  config: Record<string, unknown>,
): Record<string, unknown> {
  const environment = parseSakhiEnvironment(config.SAKHI_ENV);
  if (config.NODE_ENV === "production") {
    throw new Error(
      "This Stage 1 foundation is dev/test only; production startup is disabled.",
    );
  }

  assertSakhiDatabaseTarget(
    typeof config.SAKHI_APP_DATABASE_URL === "string"
      ? config.SAKHI_APP_DATABASE_URL
      : undefined,
    "app",
    environment,
  );

  const port = Number(config.PORT ?? 3000);
  if (!Number.isInteger(port) || port < 1 || port > 65535) {
    throw new Error("PORT must be an integer between 1 and 65535.");
  }

  const host = String(config.HOST ?? "127.0.0.1");
  if (host !== "127.0.0.1" && host !== "0.0.0.0") {
    throw new Error("HOST must be 127.0.0.1 or 0.0.0.0.");
  }

  const logLevel = String(config.LOG_LEVEL ?? "info");
  if (
    !["fatal", "error", "warn", "info", "debug", "trace", "silent"].includes(
      logLevel,
    )
  ) {
    throw new Error("LOG_LEVEL is invalid.");
  }

  return {
    ...config,
    SAKHI_ENV: environment,
    PORT: String(port),
    HOST: host,
    LOG_LEVEL: logLevel,
  };
}
