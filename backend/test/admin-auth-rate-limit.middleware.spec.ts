import type { NextFunction, Request, Response } from "express";
import { afterEach, describe, expect, it, vi } from "vitest";
import {
  AdminAuthRateLimitMiddleware,
  ADMIN_AUTH_RATE_LIMIT_POLICIES,
} from "../src/common/middleware/admin-auth-rate-limit.middleware.js";

function responseDouble() {
  const headers = new Map<string, string>();
  const response = {
    setHeader: vi.fn((name: string, value: string) => {
      headers.set(name, value);
      return response;
    }),
    status: vi.fn(() => response),
    json: vi.fn(() => response),
  } as unknown as Response;
  return { response, headers };
}

function requestDouble(
  path = "/api/v1/admin-review/auth/login",
  ip = "198.51.100.10",
  method = "POST",
): Request {
  return {
    method,
    path,
    ip,
    socket: { remoteAddress: "127.0.0.1" },
    get: (name: string) =>
      name.toLowerCase() === "cf-connecting-ip" ? "203.0.113.99" : undefined,
  } as unknown as Request;
}

afterEach(() => {
  vi.useRealTimers();
});

describe("AdminAuthRateLimitMiddleware", () => {
  it("defines explicit limits for privileged authentication and MFA routes", () => {
    expect(
      ADMIN_AUTH_RATE_LIMIT_POLICIES["POST /api/v1/admin-review/auth/login"]
        ?.limit,
    ).toBe(10);
    expect(
      ADMIN_AUTH_RATE_LIMIT_POLICIES[
        "POST /api/v1/staging-test-admin/bootstrap/super-admin"
      ]?.limit,
    ).toBe(5);
    expect(
      ADMIN_AUTH_RATE_LIMIT_POLICIES[
        "POST /api/v1/staging-test-admin/staff-mfa/recovery/request"
      ]?.limit,
    ).toBe(5);
  });

  it("allows the configured number of admin login attempts and then returns 429", () => {
    const limiter = new AdminAuthRateLimitMiddleware();
    const next = vi.fn() as unknown as NextFunction;
    const { response, headers } = responseDouble();
    const request = requestDouble();

    for (let index = 0; index < 10; index += 1) {
      limiter.use(request, response, next);
    }

    expect(next).toHaveBeenCalledTimes(10);
    expect(headers.get("RateLimit-Limit")).toBe("10");
    expect(headers.get("RateLimit-Remaining")).toBe("0");

    limiter.use(request, response, next);

    expect(next).toHaveBeenCalledTimes(10);
    expect(response.setHeader).toHaveBeenCalledWith(
      "Retry-After",
      expect.any(String),
    );
    expect(response.status).toHaveBeenCalledWith(429);
    expect(response.json).toHaveBeenCalledWith(
      expect.objectContaining({ statusCode: 429 }),
    );
  });

  it("keeps client IP and endpoint buckets separate", () => {
    const limiter = new AdminAuthRateLimitMiddleware();
    const next = vi.fn() as unknown as NextFunction;
    const { response } = responseDouble();

    for (let index = 0; index < 10; index += 1) {
      limiter.use(requestDouble(), response, next);
    }
    limiter.use(
      requestDouble("/api/v1/staging-test-admin/session"),
      response,
      next,
    );
    limiter.use(
      requestDouble("/api/v1/admin-review/auth/login", "198.51.100.11"),
      response,
      next,
    );

    expect(next).toHaveBeenCalledTimes(12);
    expect(response.status).not.toHaveBeenCalled();
  });

  it("does not trust a client-supplied Cloudflare address header over Express request.ip", () => {
    const limiter = new AdminAuthRateLimitMiddleware();
    const next = vi.fn() as unknown as NextFunction;
    const { response } = responseDouble();

    for (let index = 0; index < 10; index += 1) {
      limiter.use(
        requestDouble("/api/v1/admin-review/auth/login", "198.51.100.20"),
        response,
        next,
      );
    }
    limiter.use(
      requestDouble("/api/v1/admin-review/auth/login", "198.51.100.21"),
      response,
      next,
    );

    expect(next).toHaveBeenCalledTimes(11);
    expect(response.status).not.toHaveBeenCalled();
  });

  it("resets an expired fixed window", () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date("2026-11-18T10:00:00.000Z"));
    const limiter = new AdminAuthRateLimitMiddleware();
    const next = vi.fn() as unknown as NextFunction;
    const { response } = responseDouble();
    const request = requestDouble();

    for (let index = 0; index < 10; index += 1) {
      limiter.use(request, response, next);
    }
    limiter.use(request, response, next);
    expect(response.status).toHaveBeenCalledWith(429);

    vi.advanceTimersByTime(15 * 60 * 1000 + 1);
    limiter.use(request, response, next);

    expect(next).toHaveBeenCalledTimes(11);
  });

  it("does not throttle unrelated routes or non-POST requests", () => {
    const limiter = new AdminAuthRateLimitMiddleware();
    const next = vi.fn() as unknown as NextFunction;
    const { response } = responseDouble();

    limiter.use(requestDouble("/api/v1/admin-review/session"), response, next);
    limiter.use(
      requestDouble("/api/v1/admin-review/auth/login", "198.51.100.10", "GET"),
      response,
      next,
    );

    expect(next).toHaveBeenCalledTimes(2);
    expect(response.status).not.toHaveBeenCalled();
  });

  it("applies the stricter recovery-request limit independently", () => {
    const limiter = new AdminAuthRateLimitMiddleware();
    const next = vi.fn() as unknown as NextFunction;
    const { response } = responseDouble();
    const request = requestDouble(
      "/api/v1/staging-test-admin/staff-mfa/recovery/request",
    );

    for (let index = 0; index < 5; index += 1) {
      limiter.use(request, response, next);
    }
    limiter.use(request, response, next);

    expect(next).toHaveBeenCalledTimes(5);
    expect(response.status).toHaveBeenCalledWith(429);
  });
});
