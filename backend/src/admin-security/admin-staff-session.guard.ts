import { Injectable, UnauthorizedException, ServiceUnavailableException, ForbiddenException } from "@nestjs/common";
import type { CanActivate, ExecutionContext } from "@nestjs/common";
import type { Request } from "express";
import { timingSafeEqual } from "node:crypto";
import { AdminSessionService } from "./admin-session.service.js";
import { SakhiAdminRbacRegistry } from "../admin-review/admin-rbac.helper.js";
import { setAdminDatabaseIdentity } from "../database/database-request-identity.context.js";

function firstHeader(value: string | string[] | undefined): string | undefined {
  return Array.isArray(value) ? value[0] : value;
}

function cookieValue(request: Request, name: string): string | undefined {
  const cookieHeader = firstHeader(request.headers.cookie);
  if (!cookieHeader) return undefined;
  for (const part of cookieHeader.split(";")) {
    const separator = part.indexOf("=");
    if (separator < 0) continue;
    if (part.slice(0, separator).trim() === name) {
      try {
        return decodeURIComponent(part.slice(separator + 1).trim());
      } catch {
        return undefined;
      }
    }
  }
  return undefined;
}

function requestToken(request: Request): {
  token?: string;
  fromCookie: boolean;
} {
  const cookieToken = cookieValue(request, "sakhi_admin_session");
  if (cookieToken) return { token: cookieToken, fromCookie: true };
  const headers = request.headers;
  const sessionHeader = firstHeader(headers["x-sakhi-staging-admin-session"]);
  const authorization = firstHeader(headers.authorization);
  const bearer = authorization?.match(/^Bearer\s+(.+)$/i)?.[1]?.trim();
  return { token: sessionHeader ?? bearer, fromCookie: false };
}

@Injectable()
export class AdminStaffSessionGuard implements CanActivate {
  constructor(private readonly sessions: AdminSessionService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<Request>();
    const { token, fromCookie } = requestToken(request);
    const path = request.originalUrl.split("?")[0] ?? request.path;
    const stagingEnvironment =
      process.env.SAKHI_ENV === "staging" &&
      process.env.NODE_ENV === "production";
    const loopbackDevelopment =
      (process.env.SAKHI_ENV === "dev" || process.env.SAKHI_ENV === "test") &&
      process.env.NODE_ENV !== "production" &&
      (process.env.HOST ?? "127.0.0.1") === "127.0.0.1";
    if (!stagingEnvironment && !loopbackDevelopment) {
      throw new ServiceUnavailableException(
        "Admin authentication is available only on the dedicated staging service or loopback development/test backend.",
      );
    }
    const isBootstrapStatusRoute =
      request.method.toUpperCase() === "GET" &&
      path.endsWith("/staging-test-admin/bootstrap/status");
    const isFirstFactorRoute =
      isBootstrapStatusRoute ||
      (request.method.toUpperCase() === "POST" &&
      [
        "/staging-test-admin/session",
        "/admin-review/auth/login",
        "/staging-test-admin/bootstrap/super-admin",
        "/staging-test-admin/staff-mfa/enroll",
        "/staging-test-admin/staff-mfa/verify-enrollment",
        "/staging-test-admin/staff-mfa/recovery/request",
        "/staging-test-admin/staff-mfa/recovery/complete",
      ].some((suffix) => path.endsWith(suffix)));

    // Only the non-secret bootstrap availability check and explicit
    // first-factor/enrollment endpoints are public to this guard.
    if (isFirstFactorRoute) return true;
    if (!token?.startsWith("staff-admin.")) {
      throw new UnauthorizedException(
        "An individual persistent MFA-verified staff session is required.",
      );
    }
    if (
      process.env.SAKHI_ENV === "staging" &&
      process.env.NODE_ENV === "production" &&
      !fromCookie
    ) {
      throw new UnauthorizedException(
        "Staging staff sessions must use the HttpOnly session cookie.",
      );
    }
    if (
      fromCookie &&
      ["POST", "PUT", "PATCH", "DELETE"].includes(
        request.method.toUpperCase(),
      )
    ) {
      const origin = firstHeader(request.headers.origin);
      const allowedOrigins = String(process.env.SAKHI_ADMIN_CORS_ORIGIN ?? "")
        .split(",")
        .map((item) => item.trim())
        .filter(Boolean);
      if (!origin || !allowedOrigins.includes(origin)) {
        throw new UnauthorizedException(
          "The admin request origin is not allowed.",
        );
      }
      const cookieCsrf = cookieValue(request, "sakhi_admin_csrf") ?? "";
      const headerCsrf = firstHeader(request.headers["x-sakhi-csrf"]) ?? "";
      const expected = Buffer.from(cookieCsrf);
      const supplied = Buffer.from(headerCsrf);
      if (
        expected.length < 32 ||
        supplied.length !== expected.length ||
        !timingSafeEqual(expected, supplied)
      ) {
        throw new UnauthorizedException(
          "The admin request CSRF token is missing or invalid.",
        );
      }
    }

    const validated = await this.sessions.validateSession(token);
    const currentStaff = SakhiAdminRbacRegistry.refreshStaffRecordFromDatabase(
      validated.staff as unknown as Record<string, unknown>,
    );
    const passwordResetAllowed =
      (request.method.toUpperCase() === "POST" &&
        [
          "/admin-review/auth/password/change",
          "/admin-review/auth/logout",
          "/staging-test-admin/logout",
        ].some((suffix) => path.endsWith(suffix))) ||
      (request.method.toUpperCase() === "GET" &&
        path.endsWith("/staging-test-admin/session"));
    if (currentStaff.mustResetPassword && !passwordResetAllowed) {
      throw new ForbiddenException(
        "This staff account must change its initial password before accessing the Admin workspace.",
      );
    }
    setAdminDatabaseIdentity(String(currentStaff.id), String(currentStaff.role));
    (request as Request & { adminStaff?: unknown }).adminStaff = currentStaff;
    request.headers["x-sakhi-staging-admin-session"] = token;
    return true;
  }
}
