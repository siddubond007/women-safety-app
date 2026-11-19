import type { NextFunction, Request, Response } from "express";

const WINDOW_MS = 15 * 60 * 1000;
const MAX_TRACKED_BUCKETS = 20_000;
const CAPACITY_RETRY_SECONDS = 60;

type RateLimitPolicy = {
  limit: number;
  windowMs: number;
  label: string;
};

type Bucket = {
  count: number;
  resetAt: number;
};

export const ADMIN_AUTH_RATE_LIMIT_POLICIES: Readonly<
  Record<string, RateLimitPolicy>
> = Object.freeze({
  "POST /api/v1/admin-review/auth/login": {
    limit: 10,
    windowMs: WINDOW_MS,
    label: "Admin login",
  },
  "POST /api/v1/staging-test-admin/session": {
    limit: 10,
    windowMs: WINDOW_MS,
    label: "Staging admin login",
  },
  "POST /api/v1/staging-test-admin/bootstrap/super-admin": {
    limit: 5,
    windowMs: WINDOW_MS,
    label: "Super Admin bootstrap",
  },
  "POST /api/v1/staging-test-admin/staff-mfa/enroll": {
    limit: 10,
    windowMs: WINDOW_MS,
    label: "Staff MFA enrollment",
  },
  "POST /api/v1/staging-test-admin/staff-mfa/verify-enrollment": {
    limit: 10,
    windowMs: WINDOW_MS,
    label: "Staff MFA enrollment verification",
  },
  "POST /api/v1/staging-test-admin/staff-mfa/recovery/request": {
    limit: 5,
    windowMs: WINDOW_MS,
    label: "Staff MFA recovery request",
  },
  "POST /api/v1/staging-test-admin/staff-mfa/recovery/approve": {
    limit: 10,
    windowMs: WINDOW_MS,
    label: "Staff MFA recovery approval",
  },
  "POST /api/v1/staging-test-admin/staff-mfa/recovery/complete": {
    limit: 10,
    windowMs: WINDOW_MS,
    label: "Staff MFA recovery completion",
  },
  "POST /api/v1/staging-test-admin/session/rotate": {
    limit: 20,
    windowMs: WINDOW_MS,
    label: "Staging admin session rotation",
  },
});

const RATE_LIMITED_RESPONSE = {
  statusCode: 429,
  message:
    "Too many authentication or MFA requests. Please wait before trying again.",
};

const CAPACITY_RESPONSE = {
  statusCode: 503,
  message:
    "Authentication protection is temporarily at capacity. Please retry shortly.",
};

/**
 * Per-process IP and endpoint rate limiter for privileged admin authentication
 * and MFA operations. Express request.ip is used so arbitrary client-supplied
 * forwarding headers are not trusted here. The application configures one
 * trusted proxy in main.ts; deployment topology changes must revisit that
 * trust setting.
 *
 * This bounded in-memory store is appropriate only for the current single
 * Render instance. It resets on process restart and is not shared across
 * replicas; horizontal scaling requires a shared atomic store.
 */
export class AdminAuthRateLimitMiddleware {
  private readonly buckets = new Map<string, Bucket>();
  private lastPruneAt = 0;

  use(request: Request, response: Response, next: NextFunction): void {
    const method = request.method.toUpperCase();
    const path = request.path.endsWith("/")
      ? request.path.slice(0, -1)
      : request.path;
    const policy = ADMIN_AUTH_RATE_LIMIT_POLICIES[`${method} ${path}`];

    if (!policy) {
      next();
      return;
    }

    const clientIp =
      request.ip?.trim() || request.socket.remoteAddress?.trim() || "unknown";
    const now = Date.now();

    if (now - this.lastPruneAt >= 60_000) {
      for (const [key, bucket] of this.buckets) {
        if (bucket.resetAt <= now) this.buckets.delete(key);
      }
      this.lastPruneAt = now;
    }

    const bucketKey = `${clientIp}:${method}:${path}`;
    let bucket = this.buckets.get(bucketKey);

    if (!bucket || bucket.resetAt <= now) {
      if (this.buckets.size >= MAX_TRACKED_BUCKETS) {
        response.setHeader("Retry-After", String(CAPACITY_RETRY_SECONDS));
        response.status(503).json(CAPACITY_RESPONSE);
        return;
      }
      bucket = { count: 0, resetAt: now + policy.windowMs };
      this.buckets.set(bucketKey, bucket);
    }

    const remaining = Math.max(0, policy.limit - bucket.count);
    const resetSeconds = Math.max(1, Math.ceil((bucket.resetAt - now) / 1000));
    response.setHeader("RateLimit-Limit", String(policy.limit));
    response.setHeader("RateLimit-Remaining", String(remaining));
    response.setHeader("RateLimit-Reset", String(resetSeconds));

    if (bucket.count >= policy.limit) {
      response.setHeader("Retry-After", String(resetSeconds));
      response.status(429).json(RATE_LIMITED_RESPONSE);
      return;
    }

    bucket.count += 1;
    response.setHeader(
      "RateLimit-Remaining",
      String(Math.max(0, policy.limit - bucket.count)),
    );
    next();
  }
}
