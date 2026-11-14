import { afterEach, describe, expect, it, vi } from "vitest";
import { StagingTestAdminController } from "../src/staging-test-admin/staging-test-admin.controller.js";

const previousNodeEnv = process.env.NODE_ENV;

afterEach(() => {
  if (previousNodeEnv === undefined) delete process.env.NODE_ENV;
  else process.env.NODE_ENV = previousNodeEnv;
  vi.restoreAllMocks();
});

function responseRecorder() {
  const headers = new Map<string, unknown>();
  return {
    headers,
    setHeader: vi.fn((name: string, value: unknown) =>
      headers.set(name.toLowerCase(), value),
    ),
  };
}

describe("staging staff session cookie attributes", () => {
  it("sets cross-origin credential cookies as SameSite=None and Secure in production", async () => {
    process.env.NODE_ENV = "production";
    const expiresAt = new Date(Date.now() + 60 * 60 * 1000).toISOString();
    const service = {
      assertAdminOrigin: vi.fn(),
      loginWithToken: vi.fn().mockResolvedValue({
        authenticated: true,
        sessionToken: "staff-admin.signed-session",
        sessionExpiresAt: expiresAt,
        staffId: "staff-1",
      }),
    };
    const controller = new StagingTestAdminController(service as any);
    const response = responseRecorder();

    const result = await controller.login(
      { token: "individual-staff-token" } as any,
      "https://sakhi-staging-admin.onrender.com",
      response as any,
    );

    const cookies = response.headers.get("set-cookie") as string[];
    expect(cookies).toHaveLength(2);
    for (const cookie of cookies) {
      expect(cookie).toContain("Path=/api/v1");
      expect(cookie).toContain("SameSite=None");
      expect(cookie).toContain("Secure");
      expect(cookie).toContain("Partitioned");
    }
    expect(cookies[0]).toContain("HttpOnly");
    expect(cookies[1]).not.toContain("HttpOnly");
    expect(result).not.toHaveProperty("sessionToken");
    expect(result).toHaveProperty("csrfToken");
  });

  it("uses the same production attributes when rotating and clearing session cookies", async () => {
    process.env.NODE_ENV = "production";
    const service = {
      assertAdminOrigin: vi.fn(),
      rotateStaffSession: vi.fn().mockResolvedValue({
        sessionToken: "staff-admin.rotated-session",
        sessionExpiresAt: new Date(Date.now() + 60 * 60 * 1000).toISOString(),
      }),
      logout: vi
        .fn()
        .mockResolvedValue({ signedOut: true, serverSessionRevoked: true }),
    };
    const controller = new StagingTestAdminController(service as any);
    const rotateResponse = responseRecorder();
    await controller.rotateSession(
      "staff-admin.old-session",
      "https://sakhi-staging-admin.onrender.com",
      rotateResponse as any,
    );
    const rotatedCookies = rotateResponse.headers.get("set-cookie") as string[];
    expect(
      rotatedCookies.every(
        (cookie) =>
          cookie.includes("SameSite=None") && cookie.includes("Secure"),
      ),
    ).toBe(true);

    const logoutResponse = responseRecorder();
    await controller.logout(
      "staff-admin.rotated-session",
      "https://sakhi-staging-admin.onrender.com",
      logoutResponse as any,
    );
    const clearedCookies = logoutResponse.headers.get("set-cookie") as string[];
    expect(
      clearedCookies.every(
        (cookie) =>
          cookie.includes("Max-Age=0") &&
          cookie.includes("SameSite=None") &&
          cookie.includes("Secure"),
      ),
    ).toBe(true);
  });
});
