/**
 * Canonical eligibility states and transition policy.
 *
 * These states are distinct from account lifecycle and phone authentication.
 * This module is a domain guard for trusted backend code; it is not an API for
 * members to set their own state. Any future status writer must validate a
 * trusted provider result or an authorized review action before persistence.
 */
export const ELIGIBILITY_VERIFICATION_STATUS = {
  NOT_VERIFIED: "NOT_VERIFIED",
  VERIFICATION_IN_PROGRESS: "VERIFICATION_IN_PROGRESS",
  PENDING_MANUAL_REVIEW: "PENDING_MANUAL_REVIEW",
  VERIFIED: "VERIFIED",
  VERIFICATION_FAILED: "VERIFICATION_FAILED",
  TEMPORARILY_RESTRICTED: "TEMPORARILY_RESTRICTED",
  REVERIFICATION_REQUIRED: "REVERIFICATION_REQUIRED",
} as const;

export type EligibilityVerificationStatus =
  (typeof ELIGIBILITY_VERIFICATION_STATUS)[keyof typeof ELIGIBILITY_VERIFICATION_STATUS];

export type EligibilityTransitionAuthority = "PROVIDER" | "REVIEWER" | "SYSTEM";

export const ELIGIBILITY_STATUS_API_VALUE: Record<EligibilityVerificationStatus, string> = {
  NOT_VERIFIED: "notVerified",
  VERIFICATION_IN_PROGRESS: "verificationInProgress",
  PENDING_MANUAL_REVIEW: "pendingManualReview",
  VERIFIED: "verified",
  VERIFICATION_FAILED: "verificationFailed",
  TEMPORARILY_RESTRICTED: "temporarilyRestricted",
  REVERIFICATION_REQUIRED: "reverificationRequired",
};

const ALLOWED_TRANSITIONS = {
  NOT_VERIFIED: ["VERIFICATION_IN_PROGRESS"],
  VERIFICATION_IN_PROGRESS: [
    "VERIFIED",
    "PENDING_MANUAL_REVIEW",
    "VERIFICATION_FAILED",
  ],
  PENDING_MANUAL_REVIEW: ["VERIFIED", "VERIFICATION_FAILED"],
  VERIFIED: ["TEMPORARILY_RESTRICTED", "REVERIFICATION_REQUIRED"],
  VERIFICATION_FAILED: ["VERIFICATION_IN_PROGRESS"],
  TEMPORARILY_RESTRICTED: ["REVERIFICATION_REQUIRED"],
  REVERIFICATION_REQUIRED: ["VERIFICATION_IN_PROGRESS"],
} as const satisfies Record<
  EligibilityVerificationStatus,
  readonly EligibilityVerificationStatus[]
>;

/**
 * Validates an intended transition before a trusted backend writer persists it.
 * Manual-review decisions require a reviewer, VERIFIED requires a provider or
 * reviewer, and clients have no authority value in this type.
 */
export function canTransitionEligibilityStatus(
  from: EligibilityVerificationStatus,
  to: EligibilityVerificationStatus,
  authority: EligibilityTransitionAuthority,
): boolean {
  if (from === to || !ALLOWED_TRANSITIONS[from].includes(to as never)) {
    return false;
  }

  if (from === "PENDING_MANUAL_REVIEW") {
    return authority === "REVIEWER";
  }

  if (to === "VERIFIED") {
    return authority === "PROVIDER" || authority === "REVIEWER";
  }

  if (to === "PENDING_MANUAL_REVIEW" || to === "VERIFICATION_FAILED") {
    return authority === "PROVIDER" || authority === "SYSTEM";
  }

  if (to === "TEMPORARILY_RESTRICTED" || to === "REVERIFICATION_REQUIRED") {
    return authority === "REVIEWER" || authority === "SYSTEM";
  }

  // Starting or retrying is always performed by a trusted backend operation
  // after it has validated consent, session ownership, and policy.
  return to === "VERIFICATION_IN_PROGRESS" && authority === "SYSTEM";
}
