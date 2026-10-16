import { afterEach, describe, expect, it, vi } from "vitest";
import {
  ELIGIBILITY_SESSION_EXPIRY_INTERVAL_MS,
  EligibilitySessionExpiryWorker,
} from "../src/eligibility/eligibility-session-expiry.worker.js";
import type { EligibilityService } from "../src/eligibility/eligibility.service.js";

describe("eligibility session expiry worker", () => {
  afterEach(() => {
    vi.useRealTimers();
  });

  it("runs immediately, repeats on the configured interval, and stops on shutdown", async () => {
    vi.useFakeTimers();
    const expireStaleVerificationSessions = vi.fn().mockResolvedValue(0);
    const worker = new EligibilitySessionExpiryWorker({
      expireStaleVerificationSessions,
    } as unknown as EligibilityService);

    worker.onModuleInit();
    expect(expireStaleVerificationSessions).toHaveBeenCalledTimes(1);

    await vi.advanceTimersByTimeAsync(ELIGIBILITY_SESSION_EXPIRY_INTERVAL_MS);
    expect(expireStaleVerificationSessions).toHaveBeenCalledTimes(2);

    worker.onModuleDestroy();
    await vi.advanceTimersByTimeAsync(ELIGIBILITY_SESSION_EXPIRY_INTERVAL_MS * 2);
    expect(expireStaleVerificationSessions).toHaveBeenCalledTimes(2);
  });

  it("retries after a sweep failure on the next interval without overlapping runs", async () => {
    vi.useFakeTimers();
    const expireStaleVerificationSessions = vi
      .fn()
      .mockRejectedValueOnce(new Error("synthetic sweep failure"))
      .mockResolvedValue(0);
    const worker = new EligibilitySessionExpiryWorker({
      expireStaleVerificationSessions,
    } as unknown as EligibilityService);

    worker.onModuleInit();
    await vi.advanceTimersByTimeAsync(ELIGIBILITY_SESSION_EXPIRY_INTERVAL_MS);
    expect(expireStaleVerificationSessions).toHaveBeenCalledTimes(2);

    worker.onModuleDestroy();
  });
});
