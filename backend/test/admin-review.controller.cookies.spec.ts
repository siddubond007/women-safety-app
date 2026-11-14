import { afterEach, describe, expect, it, vi } from "vitest";
import { AdminReviewController } from "../src/admin-review/admin-review.controller.js";

const previous = {
  nodeEnv: process.env.NODE_ENV,
  sakhiEnv: process.env.SAKHI_ENV,
  corsOrigin: process.env.SAKHI_ADMIN_CORS_ORIGIN,
};

afterEach(() => {
  if (previous.nodeEnv === undefined) delete process.env.NODE_ENV;
  else process.env.NODE_ENV = previous.nodeEnv;
  if (previous.sakhiEnv === undefined) delete process.env.SAKHI_ENV;
  else process.env.SAKHI_ENV = previous.sakhiEnv;
  if (previous.corsOrigin === undefined) delete process.env.SAKHI_ADMIN_CORS_ORIGIN;
  else process.env.SAKHI_ADMIN_CORS_ORIGIN = previous.corsOrigin;
  vi.restoreAllMocks();
});

describe("AdminReviewController cross-origin credential cookies", () => {
  it("sets credential-login cookies as Secure, SameSite=None and Partitioned in production", async () => {
    process.env.NODE_ENV = "production";
    process.env.SAKHI_ENV = "staging";
    process.env.SAKHI_ADMIN_CORS_ORIGIN = "https://sakhi-staging-admin.onrender.com";
    const service = {
      loginWithCredentials: vi.fn().mockResolvedValue({
        authenticated: true,
        sessionToken: "staff-admin.session-token",
        csrfToken: "c".repeat(48),
        sessionExpiresAt: new Date(Date.now() + 60 * 60 * 1000).toISOString(),
      }),
    };
    const headers = new Map<string, unknown>();
    const response = { setHeader: vi.fn((name: string, value: unknown) => headers.set(name.toLowerCase(), value)) };
    const controller = new AdminReviewController(service as any);
    const result = await controller.loginWithCredentials(
      { identifier: "staff@example.test", password: "never-used-in-test", mfaCode: "123456" },
      "https://sakhi-staging-admin.onrender.com",
      response as any,
    );
    const cookies = headers.get("set-cookie") as string[];
    expect(cookies).toHaveLength(2);
    expect(cookies.every((cookie) => cookie.includes("SameSite=None") && cookie.includes("Secure") && cookie.includes("Partitioned"))).toBe(true);
    expect(cookies[0]).toContain("HttpOnly");
    expect(cookies[1]).not.toContain("HttpOnly");
    expect(result).not.toHaveProperty("sessionToken");
  });
});
