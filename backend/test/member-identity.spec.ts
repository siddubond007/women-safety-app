import { describe, expect, it } from "vitest";
import { createAuthenticatedMemberIdentity } from "../src/auth/member-identity.js";

describe("authenticated member identity", () => {
  it("creates an immutable normalized identity from a validated session", () => {
    const identity = createAuthenticatedMemberIdentity({
      accountId: "A0B1C2D3-E4F5-4678-9123-456789ABCDEF",
      sessionId: "B0B1C2D3-E4F5-4678-9123-456789ABCDEF",
    });

    expect(identity).toEqual({
      accountId: "a0b1c2d3-e4f5-4678-9123-456789abcdef",
      sessionId: "b0b1c2d3-e4f5-4678-9123-456789abcdef",
    });
    expect(Object.isFrozen(identity)).toBe(true);
  });

  it.each([
    {
      accountId: "not-a-uuid",
      sessionId: "b0b1c2d3-e4f5-4678-9123-456789abcdef",
    },
    { accountId: "a0b1c2d3-e4f5-4678-9123-456789abcdef", sessionId: "" },
  ])("rejects invalid identity values", (input) => {
    expect(() => createAuthenticatedMemberIdentity(input)).toThrow(/UUID/);
  });
});
