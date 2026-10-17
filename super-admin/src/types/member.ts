export type MemberAccountStatus = "active" | "restricted" | "suspended" | "banned";
export type MemberVerificationStatus = "verified" | "pending" | "in-progress" | "failed" | "not-verified";
export type MemberActionType = "warning" | "restrict" | "suspend" | "reinstate";
export type MemberSortField = "registeredAt" | "name" | "lastActiveAt";
export type RegistrationPeriod = "all" | "7" | "30" | "90";

export interface MemberRecord {
  id: string;
  reference: string;
  displayName: string;
  initials: string;
  emailMasked: string;
  phoneMasked: string;
  registeredAt: string;
  lastActiveAt: string | null;
  verificationStatus: MemberVerificationStatus;
  accountStatus: MemberAccountStatus;
  warningCount: number;
  restrictionReason?: string;
  restrictionExpiresAt?: string;
}

export interface MemberQuery {
  search: string;
  accountStatus: "all" | MemberAccountStatus;
  verificationStatus: "all" | MemberVerificationStatus;
  registrationPeriod: RegistrationPeriod;
  sortField: MemberSortField;
  sortDirection: "asc" | "desc";
  page: number;
  pageSize: number;
}

export interface MemberListResult {
  items: MemberRecord[];
  total: number;
}

export interface DemoMemberAction {
  memberId: string;
  type: MemberActionType;
  reason: string;
  durationHours?: number;
  performedAt: string;
  performedBy: "Demo Super Admin";
}

export interface MemberAuditEntry extends DemoMemberAction {
  id: string;
  memberReference: string;
  description: string;
  demoOnly: true;
}
