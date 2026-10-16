import {
  ForbiddenException,
  type ExecutionContext,
} from "@nestjs/common";
import { describe, expect, it, vi } from "vitest";
import type { AuthenticationService } from "../src/auth/auth.service.js";
import { VerifiedEligibilityGuard } from "../src/eligibility/verified-eligibility.guard.js";

function contextFor(authorization: string) {
  return {
    switchToHttp: () => ({
      getRequest: () => ({
        headers: { authorization },
      }),
    }),
  } as unknown as ExecutionContext;
}

describe("VerifiedEligibilityGuard", () => {
  it.each([
    "NOT_VERIFIED",
    "VERIFICATION_IN_PROGRESS",
    "PENDING_MANUAL_REVIEW",
    "VERIFICATION_FAILED",
    "TEMPORARILY_RESTRICTED",
    "REVERIFICATION_REQUIRED",
  ])("denies protected access for %s", async (eligibilityStatus) => {
    const auth = {
      authenticateAuthorization: vi.fn().mockResolvedValue({
        accountId: "account-id",
        account: { eligibilityStatus },
      }),
    };
    const guard = new VerifiedEligibilityGuard(
      auth as unknown as AuthenticationService,
    );

    await expect(
      guard.canActivate(contextFor("Bearer synthetic-token")),
    ).rejects.toThrow(ForbiddenException);
    expect(auth.authenticateAuthorization).toHaveBeenCalledWith(
      "Bearer synthetic-token",
    );
  });

  it("allows only a backend-confirmed VERIFIED account and binds the account ID to the request", async () => {
    const request = { headers: { authorization: "Bearer synthetic-token" } };
    const auth = {
      authenticateAuthorization: vi.fn().mockResolvedValue({
        accountId: "verified-account-id",
        account: { eligibilityStatus: "VERIFIED" },
      }),
    };
    const guard = new VerifiedEligibilityGuard(
      auth as unknown as AuthenticationService,
    );
    const context = {
      switchToHttp: () => ({ getRequest: () => request }),
    } as unknown as ExecutionContext;

    await expect(guard.canActivate(context)).resolves.toBe(true);
    expect(request).toHaveProperty("sakhiAccountId", "verified-account-id");
  });
});
