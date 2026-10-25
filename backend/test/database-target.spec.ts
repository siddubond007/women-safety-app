import { describe, expect, it } from "vitest";
import {
  assertSakhiDatabaseTarget,
  parseSakhiEnvironment,
  validateRuntimeEnvironment,
} from "../src/config/database-target.js";

function databaseUrl(
  role: string,
  database: string,
  host = "127.0.0.1",
): string {
  return (
    "postgresql://" +
    role +
    ":fixture-secret@" +
    host +
    ":5432/" +
    database +
    "?schema=public"
  );
}

describe("Sakhi database-target guard", () => {
  it("accepts only the matching local dev app role and database", () => {
    expect(
      assertSakhiDatabaseTarget(
        databaseUrl("sakhi_dev_app", "sakhi_dev"),
        "app",
        "dev",
      ),
    ).toEqual({
      environment: "dev",
      databaseName: "sakhi_dev",
      username: "sakhi_dev_app",
    });
  });

  it("accepts only the matching local test migrator role and database", () => {
    expect(
      assertSakhiDatabaseTarget(
        databaseUrl("sakhi_test_migrator", "sakhi_test"),
        "migrator",
        "test",
      ).databaseName,
    ).toBe("sakhi_test");
  });

  it("rejects the marketplace database before a connection is attempted", () => {
    expect(() =>
      assertSakhiDatabaseTarget(
        databaseUrl("postgres", "marketplacedb"),
        "app",
        "dev",
      ),
    ).toThrow(/Database target rejected/);
  });

  it("rejects an app role attempting to use the migrator identity", () => {
    expect(() =>
      assertSakhiDatabaseTarget(
        databaseUrl("sakhi_dev_migrator", "sakhi_dev"),
        "app",
        "dev",
      ),
    ).toThrow(/Database target rejected/);
  });

  it("rejects remote database hosts in this local-only stage", () => {
    expect(() =>
      assertSakhiDatabaseTarget(
        databaseUrl("sakhi_dev_app", "sakhi_dev", "example.com"),
        "app",
        "dev",
      ),
    ).toThrow(/Database target rejected/);
  });

  it("rejects missing passwords and schema-only placeholder credentials", () => {
    expect(() =>
      assertSakhiDatabaseTarget(
        "postgresql://sakhi_dev_app:@127.0.0.1:5432/sakhi_dev?schema=public",
        "app",
        "dev",
      ),
    ).toThrow(/Database target rejected/);

    expect(() =>
      assertSakhiDatabaseTarget(
        databaseUrl("sakhi_dev_migrator", "sakhi_dev").replace(
          "fixture-secret",
          "SCHEMA_ONLY_DO_NOT_CONNECT",
        ),
        "migrator",
        "dev",
      ),
    ).toThrow(/Database target rejected/);
  });

  it("does not silently accept any other environment name", () => {
    expect(() => parseSakhiEnvironment("production")).toThrow(/dev.*test/);
  });

  it("permits development OTP echo only on the loopback listener", () => {
    const base = {
      SAKHI_ENV: "dev",
      NODE_ENV: "development",
      SAKHI_APP_DATABASE_URL: databaseUrl("sakhi_dev_app", "sakhi_dev"),
      HOST: "127.0.0.1",
      PORT: "3000",
      LOG_LEVEL: "info",
      SAKHI_OTP_MODE: "development",
      SAKHI_PREVIEW_MINIMUM_AGE_YEARS: "13",
    };
    expect(validateRuntimeEnvironment(base)).toMatchObject({
      SAKHI_OTP_MODE: "development",
      HOST: "127.0.0.1",
    });
    expect(() =>
      validateRuntimeEnvironment({ ...base, HOST: "0.0.0.0" }),
    ).toThrow(/local loopback listener/);
    expect(() =>
      validateRuntimeEnvironment({ ...base, NODE_ENV: "production" }),
    ).toThrow(/production startup is disabled/);
  });

  it("accepts only the dedicated Supabase staging session-pooler target", () => {
    const stagingUrl =
      "postgresql://sakhi_staging_app.wmlpokholjfadyohdlgo:UNIT_TEST_FAKE_PASSWORD_0123456789ABCDEF0123456789@aws-0-ap-south-1.pooler.supabase.com:5432/postgres?schema=public&sslmode=verify-full&sslrootcert=prod-ca-2021.crt";

    expect(
      assertSakhiDatabaseTarget(stagingUrl, "app", "staging"),
    ).toEqual({
      environment: "staging",
      databaseName: "postgres",
      username: "sakhi_staging_app.wmlpokholjfadyohdlgo",
    });

    expect(() =>
      assertSakhiDatabaseTarget(
        stagingUrl.replace("aws-0-ap-south-1.pooler.supabase.com", "example.com"),
        "app",
        "staging",
      ),
    ).toThrow(/Staging database target rejected/);

    expect(() =>
      assertSakhiDatabaseTarget(
        stagingUrl.replace("sakhi_staging_app.wmlpokholjfadyohdlgo", "postgres.wmlpokholjfadyohdlgo"),
        "app",
        "staging",
      ),
    ).toThrow(/Staging database target rejected/);
  });

  it("permits staging runtime only with production mode, HTTPS-ready host binding, and OTP disabled", () => {
    const stagingConfig = {
      SAKHI_ENV: "staging",
      NODE_ENV: "production",
      SAKHI_APP_DATABASE_URL:
        "postgresql://sakhi_staging_app.wmlpokholjfadyohdlgo:UNIT_TEST_FAKE_PASSWORD_0123456789ABCDEF0123456789@aws-0-ap-south-1.pooler.supabase.com:5432/postgres?schema=public&sslmode=verify-full&sslrootcert=prod-ca-2021.crt",
      HOST: "0.0.0.0",
      PORT: "10000",
      LOG_LEVEL: "info",
      SAKHI_OTP_MODE: "disabled",
      SAKHI_PREVIEW_MINIMUM_AGE_YEARS: "",
    };

    expect(validateRuntimeEnvironment(stagingConfig)).toMatchObject({
      SAKHI_ENV: "staging",
      NODE_ENV: "production",
      HOST: "0.0.0.0",
      SAKHI_OTP_MODE: "disabled",
    });
    expect(() =>
      validateRuntimeEnvironment({ ...stagingConfig, HOST: "127.0.0.1" }),
    ).toThrow(/HOST=0\.0\.0\.0/);
    expect(() =>
      validateRuntimeEnvironment({
        ...stagingConfig,
        SAKHI_OTP_MODE: "development",
      }),
    ).toThrow(/OTP disabled/);
    expect(() =>
      validateRuntimeEnvironment({
        ...stagingConfig,
        SAKHI_PREVIEW_MINIMUM_AGE_YEARS: "13",
      }),
    ).toThrow(/cannot be enabled in staging/);
  });

  it("allows the India-wide phone wildcard only in isolated staging test mode", () => {
    const testConfig = {
      SAKHI_ENV: "staging",
      NODE_ENV: "production",
      SAKHI_APP_DATABASE_URL:
        "postgresql://sakhi_staging_app.wmlpokholjfadyohdlgo:UNIT_TEST_FAKE_PASSWORD_0123456789ABCDEF0123456789@aws-0-ap-south-1.pooler.supabase.com:5432/postgres?schema=public&sslmode=verify-full&sslrootcert=prod-ca-2021.crt",
      HOST: "0.0.0.0",
      PORT: "10000",
      LOG_LEVEL: "info",
      SAKHI_OTP_MODE: "staging_test",
      SAKHI_STAGING_TEST_PHONE_ALLOWLIST: "+91*",
      SAKHI_STAGING_TEST_OTP_CODE: "314159",
      SAKHI_STAGING_TEST_MINIMUM_AGE_YEARS: "18",
      SAKHI_PREVIEW_MINIMUM_AGE_YEARS: "",
    };

    expect(validateRuntimeEnvironment(testConfig)).toMatchObject({
      SAKHI_ENV: "staging",
      NODE_ENV: "production",
      SAKHI_OTP_MODE: "staging_test",
    });

    expect(() =>
      validateRuntimeEnvironment({
        ...testConfig,
        SAKHI_STAGING_TEST_PHONE_ALLOWLIST: "+91*,+919876543210",
      }),
    ).toThrow(/wildcard.*by itself/);

    expect(() =>
      validateRuntimeEnvironment({
        ...testConfig,
        NODE_ENV: "development",
      }),
    ).toThrow(/must use NODE_ENV=production/);
  });
});
