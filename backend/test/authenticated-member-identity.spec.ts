import { describe, expect, it, vi } from "vitest";
import { AuthenticationService } from "../src/auth/auth.service.js";

describe("AuthenticationService.authenticateMemberIdentity", () => {
  it("derives account and session identity only from the validated session", async () => {
    const validatedSession = {
      id: "b0b1c2d3-e4f5-4678-9123-456789abcdef",
      accountId: "a0b1c2d3-e4f5-4678-9123-456789abcdef",
    };
    const authenticateAuthorization = vi
      .fn()
      .mockResolvedValue(validatedSession);
    const result =
      await AuthenticationService.prototype.authenticateMemberIdentity.call(
        { authenticateAuthorization } as never,
        "Bearer session-token",
      );

    expect(authenticateAuthorization).toHaveBeenCalledWith(
      "Bearer session-token",
    );
    expect(result).toEqual({
      accountId: validatedSession.accountId,
      sessionId: validatedSession.id,
    });
    expect(Object.isFrozen(result)).toBe(true);
  });
});
