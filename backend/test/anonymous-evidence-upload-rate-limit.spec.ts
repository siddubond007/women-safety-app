import { describe, expect, it, vi } from "vitest";
import { AnonymousEvidenceUploadRateLimitMiddleware } from "../src/common/middleware/anonymous-evidence-upload-rate-limit.middleware.js";
import type { NextFunction, Request, Response } from "express";

describe("AnonymousEvidenceUploadRateLimitMiddleware", () => {
  it("allows eight uploads per client in a 15-minute window", () => {
    const limiter = new AnonymousEvidenceUploadRateLimitMiddleware();
    const next = vi.fn() as unknown as NextFunction;
    const response = {
      setHeader: vi.fn(),
      status: vi.fn().mockReturnThis(),
      json: vi.fn(),
    } as unknown as Response;
    const request = { ip: "198.51.100.10", socket: { remoteAddress: "proxy" } } as Request;

    for (let index = 0; index < 8; index += 1) limiter.use(request, response, next);
    expect(next).toHaveBeenCalledTimes(8);

    limiter.use(request, response, next);
    expect(next).toHaveBeenCalledTimes(8);
    expect(response.status).toHaveBeenCalledWith(429);
    expect(response.setHeader).toHaveBeenCalledWith("Retry-After", expect.any(String));
  });

  it("keeps separate client buckets", () => {
    const limiter = new AnonymousEvidenceUploadRateLimitMiddleware();
    const next = vi.fn() as unknown as NextFunction;
    const response = { setHeader: vi.fn(), status: vi.fn().mockReturnThis(), json: vi.fn() } as unknown as Response;
    limiter.use({ ip: "198.51.100.11", socket: { remoteAddress: "proxy" } } as Request, response, next);
    limiter.use({ ip: "198.51.100.12", socket: { remoteAddress: "proxy" } } as Request, response, next);
    expect(next).toHaveBeenCalledTimes(2);
  });
});
