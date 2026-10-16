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
    ).toThrow(/127\.0\.0\.1/);
    expect(() =>
      validateRuntimeEnvironment({ ...base, NODE_ENV: "production" }),
    ).toThrow(/production startup is disabled/);
  });
});
