import type { NextFunction, Request, Response } from "express";

const WINDOW_MS = 15 * 60 * 1000;
const MAX_UPLOADS_PER_WINDOW = 8;
const MAX_TRACKED_CLIENTS = 10_000;

type Bucket = { count: number; resetAt: number };

/**
 * Best-effort per-client upload abuse control for the anonymous evidence route.
 * Render's single free web instance uses this in-process store; deployments
 * with multiple instances should replace it with a shared atomic limiter.
 */
export class AnonymousEvidenceUploadRateLimitMiddleware {
  private readonly buckets = new Map<string, Bucket>();
  private lastPruneAt = 0;

  use(request: Request, response: Response, next: NextFunction): void {
    const now = Date.now();
    if (now - this.lastPruneAt >= 60_000) {
      for (const [key, bucket] of this.buckets) {
        if (bucket.resetAt <= now) this.buckets.delete(key);
      }
      this.lastPruneAt = now;
    }

    // Render is fronted by Cloudflare. Prefer its edge-populated client IP
    // header; Express request.ip remains the fallback for local/test runtimes.
    const edgeClientIp = request.get?.("cf-connecting-ip")?.trim();
    const clientKey =
      edgeClientIp || request.ip || request.socket.remoteAddress || "unknown";
    let bucket = this.buckets.get(clientKey);
    if (!bucket || bucket.resetAt <= now) {
      if (this.buckets.size >= MAX_TRACKED_CLIENTS) {
        const oldest = this.buckets.keys().next().value;
        if (oldest) this.buckets.delete(oldest);
      }
      bucket = { count: 0, resetAt: now + WINDOW_MS };
      this.buckets.set(clientKey, bucket);
    }

    if (bucket.count >= MAX_UPLOADS_PER_WINDOW) {
      const retryAfterSeconds = Math.max(
        1,
        Math.ceil((bucket.resetAt - now) / 1000),
      );
      response.setHeader("Retry-After", String(retryAfterSeconds));
      response.status(429).json({
        statusCode: 429,
        message:
          "Evidence upload limit reached. Please retry after the stated interval.",
      });
      return;
    }

    bucket.count += 1;
    next();
  }
}
