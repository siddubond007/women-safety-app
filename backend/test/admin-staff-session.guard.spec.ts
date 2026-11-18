import { afterEach, describe, expect, it, vi } from "vitest";
import type { ExecutionContext } from "@nestjs/common";
import { AdminStaffSessionGuard } from "../src/admin-security/admin-staff-session.guard.js";
import { SakhiAdminRbacRegistry } from "../src/admin-review/admin-rbac.helper.js";

const oldEnv = {
  sakhiEnv: process.env.SAKHI_ENV,
  nodeEnv: process.env.NODE_ENV,
  corsOrigin: process.env.SAKHI_ADMIN_CORS_ORIGIN,
  host: process.env.HOST,
};

function contextFor(request: Record<string, any>): ExecutionContext {
  return {
    switchToHttp: () => ({ getRequest: () => request }),
  } as unknown as ExecutionContext;
}

function activeStaffRow(mustResetPassword = false) {
  const now = new Date();
  return {
    id: "2d5fce37-6aab-4cb4-8a6c-6a2d07f87e91",
    staffCode: "#SA-123",
    fullName: "Guard Test Super Admin",
    email: "guard.superadmin@example.test",
    role: "SUPER_ADMIN",
    status: "ACTIVE",
    mustResetPassword,
    accessTokenDigest: "a".repeat(64),
    accessTokenPreview: "SAKHI-STAFF-••••",
    isAuthorisedComplaintReviewer: true,
    clearanceLevel: "LEVEL_4_MASTER_GOVERNANCE",
    permissions: {},
    createdBy: "Test",
    lastLoginAt: now,
    createdAt: now,
    updatedAt: now,
  };
}

describe("AdminStaffSessionGuard", () => {
  afterEach(() => {
    if (oldEnv.sakhiEnv === undefined) delete process.env.SAKHI_ENV;
    else process.env.SAKHI_ENV = oldEnv.sakhiEnv;
    if (oldEnv.nodeEnv === undefined) delete process.env.NODE_ENV;
    else process.env.NODE_ENV = oldEnv.nodeEnv;
    if (oldEnv.corsOrigin === undefined) delete process.env.SAKHI_ADMIN_CORS_ORIGIN;
    else process.env.SAKHI_ADMIN_CORS_ORIGIN = oldEnv.corsOrigin;
    if (oldEnv.host === undefined) delete process.env.HOST;
    else process.env.HOST = oldEnv.host;
    SakhiAdminRbacRegistry.resetForTesting();
    vi.restoreAllMocks();
  });

  it("allows only the non-secret Super Admin bootstrap status check without a session", async () => {
    process.env.SAKHI_ENV = "staging";
    process.env.NODE_ENV = "production";
    process.env.SAKHI_ADMIN_CORS_ORIGIN = "https://sakhi-admin.example.test";
    const request = {
      method: "GET",
      originalUrl: "/api/v1/staging-test-admin/bootstrap/status",
      path: "/api/v1/staging-test-admin/bootstrap/status",
      headers: { origin: "https://sakhi-admin.example.test" },
    };
    const sessions = { validateSession: vi.fn() };
    const guard = new AdminStaffSessionGuard(sessions as any);
    await expect(guard.canActivate(contextFor(request))).resolves.toBe(true);
    expect(sessions.validateSession).not.toHaveBeenCalled();
  });

  it("validates the persistent cookie session, enforces origin and CSRF, and refreshes current staff role data", async () => {
    process.env.SAKHI_ENV = "staging";
    process.env.NODE_ENV = "production";
    process.env.SAKHI_ADMIN_CORS_ORIGIN = "https://sakhi-admin.example.test";
    const token = "staff-admin.signed-persistent-token";
    const csrf = "c".repeat(48);
    const request = {
      method: "POST",
      originalUrl: "/api/v1/admin-review/complaints",
      path: "/api/v1/admin-review/complaints",
      headers: {
        cookie: `sakhi_admin_session=${encodeURIComponent(token)}; sakhi_admin_csrf=${csrf}`,
        origin: "https://sakhi-admin.example.test",
        "x-sakhi-csrf": csrf,
      } as Record<string, string>,
    };
    const sessions = {
      validateSession: vi.fn().mockResolvedValue({ staff: activeStaffRow() }),
    };
    const guard = new AdminStaffSessionGuard(sessions as any);

    await expect(guard.canActivate(contextFor(request))).resolves.toBe(true);
    expect(sessions.validateSession).toHaveBeenCalledWith(token);
    expect(request.headers["x-sakhi-admin-token"]).toBeUndefined();
    expect(request.headers["x-sakhi-staging-admin-session"]).toBe(token);
    expect((request as any).adminStaff).toMatchObject({
      id: activeStaffRow().id,
      role: "SUPER_ADMIN",
      status: "ACTIVE",
    });
  });

  it("restricts initial-password accounts to session introspection, logout and password change", async () => {
    process.env.SAKHI_ENV = "staging";
    process.env.NODE_ENV = "production";
    process.env.SAKHI_ADMIN_CORS_ORIGIN = "https://sakhi-admin.example.test";
    const token = "staff-admin.password-reset-required";
    const csrf = "r".repeat(48);
    const sessions = {
      validateSession: vi.fn().mockResolvedValue({ staff: activeStaffRow(true) }),
    };
    const guard = new AdminStaffSessionGuard(sessions as any);
    const introspection = {
      method: "GET",
      originalUrl: "/api/v1/staging-test-admin/session",
      path: "/api/v1/staging-test-admin/session",
      headers: { cookie: `sakhi_admin_session=${encodeURIComponent(token)}` },
    };
    await expect(guard.canActivate(contextFor(introspection))).resolves.toBe(true);

    const passwordChange = {
      method: "POST",
      originalUrl: "/api/v1/admin-review/auth/password/change",
      path: "/api/v1/admin-review/auth/password/change",
      headers: {
        cookie: `sakhi_admin_session=${encodeURIComponent(token)}; sakhi_admin_csrf=${csrf}`,
        origin: "https://sakhi-admin.example.test",
        "x-sakhi-csrf": csrf,
      },
    };
    await expect(guard.canActivate(contextFor(passwordChange))).resolves.toBe(true);

    const protectedRoute = {
      method: "GET",
      originalUrl: "/api/v1/admin-review/staff",
      path: "/api/v1/admin-review/staff",
      headers: { cookie: `sakhi_admin_session=${encodeURIComponent(token)}` },
    };
    await expect(guard.canActivate(contextFor(protectedRoute))).rejects.toThrow(
      /must change its initial password/i,
    );
  });

  it("rejects cookie-authenticated state changes without the configured origin and CSRF token", async () => {
    process.env.SAKHI_ENV = "staging";
    process.env.NODE_ENV = "production";
    process.env.SAKHI_ADMIN_CORS_ORIGIN = "https://sakhi-admin.example.test";
    const request = {
      method: "POST",
      originalUrl: "/api/v1/complaints/admin/queue",
      path: "/api/v1/complaints/admin/queue",
      headers: {
        cookie: `sakhi_admin_session=${encodeURIComponent("staff-admin.token")}; sakhi_admin_csrf=${"c".repeat(48)}`,
        origin: "https://attacker.example.test",
        "x-sakhi-csrf": "c".repeat(48),
      },
    };
    const sessions = { validateSession: vi.fn() };
    const guard = new AdminStaffSessionGuard(sessions as any);

    await expect(guard.canActivate(contextFor(request))).rejects.toThrow(
      /origin is not allowed/i,
    );
    expect(sessions.validateSession).not.toHaveBeenCalled();
  });

  it("rejects header-borne staff sessions in production staging", async () => {
    process.env.SAKHI_ENV = "staging";
    process.env.NODE_ENV = "production";
    const request = {
      method: "GET",
      originalUrl: "/api/v1/admin-review/session",
      path: "/api/v1/admin-review/session",
      headers: { "x-sakhi-admin-token": "staff-admin.header-token" },
    };
    const sessions = { validateSession: vi.fn() };
    const guard = new AdminStaffSessionGuard(sessions as any);

    await expect(guard.canActivate(contextFor(request))).rejects.toThrow(
      /persistent MFA-verified staff session/i,
    );
    expect(sessions.validateSession).not.toHaveBeenCalled();
  });
});
  it.each([
    ["x-sakhi-admin-token", "legacy-shared-reviewer-token"],
    ["x-sakhi-admin-review-token", "legacy-shared-reviewer-token"],
    ["authorization", "Bearer legacy-shared-reviewer-token"],
  ])("rejects legacy shared-token credential via %s", async (header, value) => {
    process.env.SAKHI_ENV = "dev";
    process.env.NODE_ENV = "development";
    process.env.HOST = "127.0.0.1";
    const request = {
      method: "GET",
      originalUrl: "/api/v1/admin-review/staff",
      path: "/api/v1/admin-review/staff",
      headers: { [header]: value },
    };
    const sessions = { validateSession: vi.fn() };
    const guard = new AdminStaffSessionGuard(sessions as any);

    await expect(guard.canActivate(contextFor(request))).rejects.toThrow(
      /persistent MFA-verified staff session/i,
    );
    expect(sessions.validateSession).not.toHaveBeenCalled();
  });

  it("allows only explicitly listed first-factor login to bypass an existing session", async () => {
    process.env.SAKHI_ENV = "staging";
    process.env.NODE_ENV = "production";
    const request = {
      method: "POST",
      originalUrl: "/api/v1/staging-test-admin/session",
      path: "/api/v1/staging-test-admin/session",
      headers: {},
    };
    const sessions = { validateSession: vi.fn() };
    const guard = new AdminStaffSessionGuard(sessions as any);

    await expect(guard.canActivate(contextFor(request))).resolves.toBe(true);
    expect(sessions.validateSession).not.toHaveBeenCalled();
  });

  it.each(["/api/v1/staging-test-admin/logout", "/api/v1/staging-test-admin/session/rotate"])(
    "does not exempt logout or rotation from persistent-session validation: %s",
    async (path) => {
      process.env.SAKHI_ENV = "staging";
      process.env.NODE_ENV = "production";
      const request = { method: "POST", originalUrl: path, path, headers: {} };
      const sessions = { validateSession: vi.fn() };
      const guard = new AdminStaffSessionGuard(sessions as any);

      await expect(guard.canActivate(contextFor(request))).rejects.toThrow(
        /persistent MFA-verified staff session/i,
      );
      expect(sessions.validateSession).not.toHaveBeenCalled();
    },
  );
