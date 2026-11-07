export type SakhiEnvironment = "dev" | "test" | "staging";
export type DatabasePurpose = "app" | "migrator";

export interface ParsedSakhiDatabaseTarget {
  environment: SakhiEnvironment;
  databaseName: "sakhi_dev" | "sakhi_test" | "postgres";
  username: string;
}

const STAGING_SUPABASE_PROJECT_REF = "wmlpokholjfadyohdlgo";
const STAGING_SUPABASE_POOLER_HOST = "aws-0-ap-south-1.pooler.supabase.com";

export function parseSakhiEnvironment(value: unknown): SakhiEnvironment {
  if (value === undefined || value === null || value === "") {
    return "dev";
  }
  if (value === "dev" || value === "test" || value === "staging") {
    return value;
  }
  throw new Error('SAKHI_ENV must be "dev", "test", or "staging".');
}

function isPlaceholderPassword(password: string): boolean {
  return (
    password.length === 0 ||
    password === "SCHEMA_ONLY_DO_NOT_CONNECT" ||
    password.includes("[YOUR-PASSWORD]") ||
    password.includes("REPLACE_WITH")
  );
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

  const databaseName =
    environment === "staging"
      ? "postgres"
      : environment === "test"
        ? "sakhi_test"
        : "sakhi_dev";
  const localUsername =
    purpose === "app"
      ? environment === "test"
        ? "sakhi_test_app"
        : "sakhi_dev_app"
      : environment === "test"
        ? "sakhi_test_migrator"
        : "sakhi_dev_migrator";
  const username =
    environment === "staging"
      ? `sakhi_staging_${purpose}.${STAGING_SUPABASE_PROJECT_REF}`
      : localUsername;

  const protocolIsPostgres =
    parsed.protocol === "postgres:" || parsed.protocol === "postgresql:";
  const databaseMatches =
    decodeURIComponent(parsed.pathname.slice(1)) === databaseName;
  const usernameMatches = decodeURIComponent(parsed.username) === username;
  const decodedPassword = decodeURIComponent(parsed.password);
  const commonCredentialsValid = !isPlaceholderPassword(decodedPassword);
  const schemaMatches = parsed.searchParams.get("schema") === "public";
  const stagingRootCertificate = parsed.searchParams.get("sslrootcert") ?? "";
  const stagingTlsCertificateMatches =
    stagingRootCertificate.replace(/\\/g, "/").endsWith("/prod-ca-2021.crt") ||
    stagingRootCertificate === "prod-ca-2021.crt";

  if (environment === "staging") {
    // Staging is allowed to reach exactly the dedicated Supabase project
    // created for friend testing. It must never fall back to the local DB.
    if (
      !protocolIsPostgres ||
      parsed.hostname !== STAGING_SUPABASE_POOLER_HOST ||
      parsed.port !== "5432" ||
      !databaseMatches ||
      !usernameMatches ||
      !commonCredentialsValid ||
      decodedPassword.length < 32 ||
      !schemaMatches ||
      parsed.searchParams.get("sslmode") !== "verify-full" ||
      !stagingTlsCertificateMatches
    ) {
      throw new Error(
        "Staging database target rejected. Use only the configured Sakhi Supabase session pooler, staging role, postgres database, TLS, and public schema.",
      );
    }
  } else if (
    !protocolIsPostgres ||
    !["127.0.0.1", "localhost"].includes(parsed.hostname) ||
    !databaseMatches ||
    !usernameMatches ||
    !commonCredentialsValid ||
    !schemaMatches
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
  const nodeEnvironment = String(config.NODE_ENV ?? "development");

  if (environment === "staging" && nodeEnvironment !== "production") {
    throw new Error("The Sakhi staging runtime must use NODE_ENV=production.");
  }
  if (environment !== "staging" && nodeEnvironment === "production") {
    throw new Error(
      "This Stage 1 foundation is dev/test only; production startup is disabled outside the explicit staging environment.",
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

  const defaultHost = environment === "staging" ? "0.0.0.0" : "127.0.0.1";
  const host = String(config.HOST ?? defaultHost);
  if (host !== "127.0.0.1" && host !== "0.0.0.0") {
    throw new Error("HOST must be 127.0.0.1 or 0.0.0.0.");
  }
  if (environment === "staging" && host !== "0.0.0.0") {
    throw new Error("Staging web services must bind to HOST=0.0.0.0.");
  }

  const logLevel = String(config.LOG_LEVEL ?? "info");
  if (
    !["fatal", "error", "warn", "info", "debug", "trace", "silent"].includes(
      logLevel,
    )
  ) {
    throw new Error("LOG_LEVEL is invalid.");
  }

  const otpMode = String(config.SAKHI_OTP_MODE ?? "disabled");
  if (!["disabled", "development", "staging_test"].includes(otpMode)) {
    throw new Error(
      'SAKHI_OTP_MODE must be "disabled", "development", or "staging_test".',
    );
  }

  const stagingTestPhoneAllowlist = String(
    config.SAKHI_STAGING_TEST_PHONE_ALLOWLIST ?? "",
  )
    .split(",")
    .map((phone) => phone.trim())
    .filter(Boolean);
  const stagingTestOtpCode = String(config.SAKHI_STAGING_TEST_OTP_CODE ?? "");
  const stagingTestMinimumAgeYears = String(
    config.SAKHI_STAGING_TEST_MINIMUM_AGE_YEARS ?? "",
  );

  if (otpMode === "staging_test") {
    if (
      environment !== "staging" ||
      nodeEnvironment !== "production" ||
      host !== "0.0.0.0"
    ) {
      throw new Error(
        "Staging test login is allowed only on the explicitly configured staging service.",
      );
    }
    const usesIndiaPhoneWildcard = stagingTestPhoneAllowlist.includes("+91*");
    if (
      stagingTestPhoneAllowlist.length === 0 ||
      (usesIndiaPhoneWildcard && stagingTestPhoneAllowlist.length !== 1) ||
      stagingTestPhoneAllowlist.some(
        (phone) => phone !== "+91*" && !/^\+[1-9]\d{7,14}$/.test(phone),
      ) ||
      new Set(stagingTestPhoneAllowlist).size !==
        stagingTestPhoneAllowlist.length
    ) {
      throw new Error(
        'Staging test login requires unique E.164 phone numbers, or the staging-only wildcard "+91*" by itself.',
      );
    }
    if (!/^\d{6}$/.test(stagingTestOtpCode)) {
      throw new Error(
        "Staging test login requires a six-digit shared code in the protected environment settings.",
      );
    }
    if (stagingTestMinimumAgeYears !== "18") {
      throw new Error(
        "Staging test login requires the temporary minimum age to be explicitly set to 18.",
      );
    }
  } else {
    if (environment === "staging" && otpMode !== "disabled") {
      throw new Error(
        "Staging must keep OTP disabled unless the explicit staging_test mode is configured.",
      );
    }
    if (
      otpMode === "development" &&
      (nodeEnvironment === "production" ||
        (environment !== "dev" && environment !== "test") ||
        host !== "127.0.0.1")
    ) {
      throw new Error(
        "Development OTP echo is permitted only on a local loopback listener in dev/test.",
      );
    }
  }

  const previewMinimumAgeYears = String(
    config.SAKHI_PREVIEW_MINIMUM_AGE_YEARS ?? "",
  );
  if (
    previewMinimumAgeYears !== "" &&
    (previewMinimumAgeYears !== "13" || environment === "staging")
  ) {
    throw new Error(
      "The temporary age-13 rule is local dev/test only and cannot be enabled in staging.",
    );
  }

  return {
    ...config,
    SAKHI_ENV: environment,
    PORT: String(port),
    HOST: host,
    LOG_LEVEL: logLevel,
    SAKHI_OTP_MODE: otpMode,
    SAKHI_PREVIEW_MINIMUM_AGE_YEARS: previewMinimumAgeYears,
  };
}
