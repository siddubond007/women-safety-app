import type { DemoMemberAction, MemberRecord } from "../../../types/member";
import { mockMembers } from "../../mock/members/members";

export interface MemberRepository {
  list(): Promise<MemberRecord[]>;
  simulateAction(action: DemoMemberAction): Promise<MemberRecord>;
}

/**
 * Stage 2 mock adapter. Mutations affect only this in-memory fictional dataset.
 * There is no API, persistent storage, message delivery or production record.
 */
const mockMemberRepository: MemberRepository = {
  async list() {
    return mockMembers.map((member) => ({ ...member }));
  },

  async simulateAction(action) {
    const member = mockMembers.find((item) => item.id === action.memberId);
    if (!member) throw new Error("Demo member was not found.");

    switch (action.type) {
      case "warning":
        member.warningCount += 1;
        break;
      case "restrict":
        member.accountStatus = "restricted";
        member.restrictionReason = action.reason;
        member.restrictionExpiresAt = action.durationHours
          ? new Date(new Date(action.performedAt).getTime() + action.durationHours * 60 * 60 * 1000).toISOString()
          : undefined;
        break;
      case "suspend":
        member.accountStatus = "suspended";
        member.restrictionReason = action.reason;
        member.restrictionExpiresAt = action.durationHours
          ? new Date(new Date(action.performedAt).getTime() + action.durationHours * 60 * 60 * 1000).toISOString()
          : undefined;
        break;
      case "reinstate":
        member.accountStatus = "active";
        member.restrictionReason = undefined;
        member.restrictionExpiresAt = undefined;
        break;
    }

    return { ...member };
  },
};

export function getMemberRepository(): MemberRepository {
  return mockMemberRepository;
}
