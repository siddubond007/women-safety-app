/**
 * Trusted identity for an authenticated member request.
 * Instances are created only after AuthenticationService validates a persisted session.
 */
export interface AuthenticatedMemberIdentity {
  readonly accountId: string;
  readonly sessionId: string;
}

const POSTGRES_UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export function createAuthenticatedMemberIdentity(input: {
  accountId: string;
  sessionId: string;
}): AuthenticatedMemberIdentity {
  if (!POSTGRES_UUID_PATTERN.test(input.accountId)) {
    throw new Error("Authenticated member account ID must be a UUID.");
  }
  if (!POSTGRES_UUID_PATTERN.test(input.sessionId)) {
    throw new Error("Authenticated member session ID must be a UUID.");
  }

  return Object.freeze({
    accountId: input.accountId.toLowerCase(),
    sessionId: input.sessionId.toLowerCase(),
  });
}
