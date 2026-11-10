import { describe, expect, it, vi } from "vitest";
import { Module2Service } from "../src/module2/module2.service.js";

const memberId = "a0b1c2d3-e4f5-4678-9123-456789abcdef";
const sessionId = "b0b1c2d3-e4f5-4678-9123-456789abcdee";

describe("Module2Service menstrual tracker identity context", () => {
  it("runs all private tracker reads in one transaction with verified member context", async () => {
    const identity = Object.freeze({ accountId: memberId, sessionId });
    const tx = {
      menstrualCycleLog: { findMany: vi.fn().mockResolvedValue([]) },
      menstrualDailyLog: { findMany: vi.fn().mockResolvedValue([]) },
      menstrualTrackerPreference: {
        findUnique: vi.fn().mockResolvedValue(null),
      },
    };
    const withMemberIdentity = vi.fn(async (receivedIdentity, operation) => {
      expect(receivedIdentity).toBe(identity);
      return operation(tx);
    });
    const auth = {
      authenticateMemberIdentity: vi.fn().mockResolvedValue(identity),
    };
    const service = new Module2Service(
      auth as never,
      { withMemberIdentity } as never,
    );

    const result = await service.getMenstrualCycleTracker(
      "Bearer validated-token",
    );

    expect(auth.authenticateMemberIdentity).toHaveBeenCalledWith(
      "Bearer validated-token",
    );
    expect(withMemberIdentity).toHaveBeenCalledOnce();
    expect(tx.menstrualCycleLog.findMany).toHaveBeenCalledWith(
      expect.objectContaining({ where: { accountId: memberId } }),
    );
    expect(tx.menstrualDailyLog.findMany).toHaveBeenCalledWith(
      expect.objectContaining({ where: { accountId: memberId } }),
    );
    expect(tx.menstrualTrackerPreference.findUnique).toHaveBeenCalledWith({
      where: { accountId: memberId },
    });
    expect(result.cycleLogs).toEqual([]);
    expect(result.dailyLogs).toEqual([]);
  });
});
