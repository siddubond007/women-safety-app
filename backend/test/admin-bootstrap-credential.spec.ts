import { afterEach, describe, expect, it } from "vitest";
import {
  getFullAdminBootstrapConfig,
  matchesBootstrapCredential,
} from "../src/staging-test-admin/staging-test-admin.service.js";
import { createHash } from "node:crypto";

const ENV_KEYS = [
  "SAKHI_ENV",
  "NODE_ENV",
  "SAKHI_STAGING_FULL_ADMIN_ENABLED",
  "SAKHI_STAGING_FULL_ADMIN_TOKEN_SHA256",
  "SAKHI_STAGING_FULL_ADMIN_TOKEN_EXPIRES_AT",
] as const;
const originalEnv = new Map(ENV_KEYS.map((key) => [key, process.env[key]]));
const now = new Date("2026-11-17T12:00:00.000Z");
const token = "a-secure-bootstrap-token-that-is-never-committed";
const digest = createHash("sha256").update(token).digest("hex");

function configure(overrides: Record<string, string | undefined> = {}) {
  process.env.SAKHI_ENV = "staging";
  process.env.NODE_ENV = "production";
  process.env.SAKHI_STAGING_FULL_ADMIN_ENABLED = "true";
  process.env.SAKHI_STAGING_FULL_ADMIN_TOKEN_SHA256 = digest;
  process.env.SAKHI_STAGING_FULL_ADMIN_TOKEN_EXPIRES_AT =
    "2026-11-17T18:00:00.000Z";
  for (const [key, value] of Object.entries(overrides)) {
    if (value === undefined) delete process.env[key];
    else process.env[key] = value;
  }
}

afterEach(() => {
  for (const key of ENV_KEYS) {
    const value = originalEnv.get(key);
    if (value === undefined) delete process.env[key];
    else process.env[key] = value;
  }
});

describe("single-use staging Super Admin bootstrap credential configuration", () => {
  it("accepts only a SHA-256 digest with an absolute expiry within 24 hours", () => {
    configure();
    const config = getFullAdminBootstrapConfig(now);
    expect(config?.tokenDigest).toBe(digest);
    expect(config?.expiresAt.toISOString()).toBe("2026-11-17T18:00:00.000Z");
  });

  it("fails closed outside production staging or when the feature is disabled", () => {
    configure({ SAKHI_ENV: "dev" });
    expect(getFullAdminBootstrapConfig(now)).toBeNull();
    configure({ NODE_ENV: "development" });
    expect(getFullAdminBootstrapConfig(now)).toBeNull();
    configure({ SAKHI_STAGING_FULL_ADMIN_ENABLED: "false" });
    expect(getFullAdminBootstrapConfig(now)).toBeNull();
  });

  it("rejects a plaintext environment token and malformed digest", () => {
    configure({ SAKHI_STAGING_FULL_ADMIN_TOKEN_SHA256: token });
    expect(getFullAdminBootstrapConfig(now)).toBeNull();
    configure({ SAKHI_STAGING_FULL_ADMIN_TOKEN_SHA256: "abc123" });
    expect(getFullAdminBootstrapConfig(now)).toBeNull();
  });

  it("rejects missing, invalid, expired, and excessively long expiry values", () => {
    configure({ SAKHI_STAGING_FULL_ADMIN_TOKEN_EXPIRES_AT: undefined });
    expect(getFullAdminBootstrapConfig(now)).toBeNull();
    configure({ SAKHI_STAGING_FULL_ADMIN_TOKEN_EXPIRES_AT: "not-a-date" });
    expect(getFullAdminBootstrapConfig(now)).toBeNull();
    configure({ SAKHI_STAGING_FULL_ADMIN_TOKEN_EXPIRES_AT: "2026-11-17T11:59:59.000Z" });
    expect(getFullAdminBootstrapConfig(now)).toBeNull();
    configure({ SAKHI_STAGING_FULL_ADMIN_TOKEN_EXPIRES_AT: "2026-11-19T12:00:00.000Z" });
    expect(getFullAdminBootstrapConfig(now)).toBeNull();
  });

  it("compares the supplied token to the configured digest and rejects wrong or empty tokens", () => {
    expect(matchesBootstrapCredential(token, digest)).toBe(true);
    expect(matchesBootstrapCredential(` ${token} `, digest)).toBe(true);
    expect(matchesBootstrapCredential("wrong-token", digest)).toBe(false);
    expect(matchesBootstrapCredential(undefined, digest)).toBe(false);
    expect(matchesBootstrapCredential(token, "not-a-digest")).toBe(false);
  });
});
