import {
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
  ServiceUnavailableException,
  UnauthorizedException,
} from "@nestjs/common";
import { createHash, createHmac, randomUUID, timingSafeEqual } from "node:crypto";
import { PrismaService } from "../database/prisma.service.js";
import {
  ADMIN_ROLE_DEFINITIONS,
  SakhiAdminRbacRegistry,
  type AuthenticatedAdminPrincipal,
} from "../admin-review/admin-rbac.helper.js";
import type { StagingTestAccessDecisionDto } from "./staging-test-admin.dto.js";

const APPROVED_ACTION = "staging.test_access.approved";
const REVOKED_ACTION = "staging.test_access.revoked";
const TEST_ACCESS_ACTIONS = [APPROVED_ACTION, REVOKED_ACTION];
const STAGING_ADMIN_SESSION_TTL_SECONDS = 8 * 60 * 60;

type StagingAdminScope = "test-access" | "full-admin";

function assertStagingEnvironment(): void {
  if (process.env.SAKHI_ENV !== "staging" || process.env.NODE_ENV !== "production") {
    throw new ServiceUnavailableException("The staging admin is not enabled in this environment.");
  }
}

function requireTestAdminSecret(): string {
  assertStagingEnvironment();
  if (process.env.SAKHI_STAGING_TEST_ADMIN_ENABLED !== "true") {
    throw new ServiceUnavailableException("The staging test-access admin is not enabled.");
  }
  const secret = process.env.SAKHI_STAGING_TEST_ADMIN_TOKEN?.trim() ?? "";
  if (secret.length < 32) {
    throw new ServiceUnavailableException("Configure a random staging test-admin token of at least 32 characters.");
  }
  return secret;
}

export function getFullAdminSecret(): string | null {
  if (
    process.env.SAKHI_ENV !== "staging" ||
    process.env.NODE_ENV !== "production" ||
    process.env.SAKHI_STAGING_FULL_ADMIN_ENABLED !== "true"
  ) return null;
  const secret = process.env.SAKHI_STAGING_FULL_ADMIN_TOKEN?.trim() ?? "";
  return secret.length >= 32 ? secret : null;
}

function reviewerLabelForScope(scope: StagingAdminScope): string {
  const key = scope === "full-admin"
    ? "SAKHI_STAGING_FULL_ADMIN_REVIEWER_LABEL"
    : "SAKHI_STAGING_TEST_ADMIN_REVIEWER_LABEL";
  const configured = process.env[key]?.trim();
  if (configured && configured.length <= 80) return configured;
  return scope === "full-admin" ? "Sakhi Staging Super Admin" : "Sakhi Staging Test Reviewer";
}

function verifyStagingSession(
  sessionToken?: string,
  requiredScope?: StagingAdminScope,
): {
  scope: StagingAdminScope;
  reviewerLabel: string;
  principal?: AuthenticatedAdminPrincipal;
} {
  assertStagingEnvironment();
  const fullSecret = getFullAdminSecret() ?? "sakhi-rbac-default-secret";
  if (sessionToken?.startsWith("staff-admin.")) {
    const staff = SakhiAdminRbacRegistry.verifySignedStaffSessionToken(
      sessionToken,
      fullSecret,
    );
    if (!staff) {
      throw new UnauthorizedException(
        "The staging staff admin session is invalid or expired. Sign in again.",
      );
    }
    const principal = SakhiAdminRbacRegistry.principalFromStaff(staff);
    return {
      scope: "full-admin",
      reviewerLabel: principal.reviewerLabel,
      principal,
    };
  }

  const parts = sessionToken?.split(".") ?? [];
  const scope = parts[0];
  if (
    parts.length !== 4 ||
    (scope !== "test-access" && scope !== "full-admin") ||
    !(parts[1] ?? "").split("").every((character) => character >= "0" && character <= "9") ||
    !/^[0-9a-f-]{36}$/i.test(parts[2] ?? "")
  ) {
    throw new UnauthorizedException("The staging admin session is invalid. Sign in again.");
  }
  if (requiredScope === "full-admin" && scope !== "full-admin") {
    throw new UnauthorizedException("Full staging-admin access is required for this action.");
  }
  const expiresAt = Number(parts[1]);
  const now = Math.floor(Date.now() / 1000);
  if (
    !Number.isSafeInteger(expiresAt) ||
    expiresAt <= now ||
    expiresAt > now + STAGING_ADMIN_SESSION_TTL_SECONDS + 60
  ) {
    throw new UnauthorizedException("The staging admin session has expired. Sign in again.");
  }

  const testSecret = process.env.SAKHI_STAGING_TEST_ADMIN_TOKEN?.trim() ?? "";
  const rawFullSecret = getFullAdminSecret() ?? "";
  const secret = scope === "test-access" ? testSecret : rawFullSecret;
  if (
    secret.length < 32 ||
    (scope === "test-access" && process.env.SAKHI_STAGING_TEST_ADMIN_ENABLED !== "true") ||
    (scope === "full-admin" && process.env.SAKHI_STAGING_FULL_ADMIN_ENABLED !== "true")
  ) {
    throw new UnauthorizedException("The staging admin session is invalid. Sign in again.");
  }

  const payload = `${parts[0]}.${parts[1]}.${parts[2]}`;
  const expected = createHmac("sha256", secret)
    .update("sakhi-staging-admin-session:" + payload)
    .digest();
  const supplied = Buffer.from(parts[3] ?? "", "base64url");
  if (supplied.length !== expected.length || !timingSafeEqual(supplied, expected)) {
    throw new UnauthorizedException("The staging admin session is invalid. Sign in again.");
  }
  const label = reviewerLabelForScope(scope);
  return {
    scope,
    reviewerLabel: label,
    principal:
      scope === "full-admin"
        ? SakhiAdminRbacRegistry.getSuperAdminPrincipal(label)
        : undefined,
  };
}

@Injectable()
export class StagingTestAdminService {
  constructor(private readonly prisma: PrismaService) {}

  private assertEnabled(): string {
    return requireTestAdminSecret();
  }

  private assertMasterCredential(provided?: string): {
    scope: StagingAdminScope;
    secret: string;
    reviewerLabel: string;
  } {
    const testSecret = this.assertEnabled();
    if (!provided?.trim()) {
      throw new UnauthorizedException("A staging admin token is required.");
    }
    const providedDigest = createHash("sha256").update(provided.trim()).digest();
    const matches = (secret: string) => {
      const expectedDigest = createHash("sha256").update(secret).digest();
      return timingSafeEqual(expectedDigest, providedDigest);
    };
    if (matches(testSecret)) {
      return { scope: "test-access", secret: testSecret, reviewerLabel: reviewerLabelForScope("test-access") };
    }
    const fullSecret = getFullAdminSecret();
    if (fullSecret && matches(fullSecret)) {
      return { scope: "full-admin", secret: fullSecret, reviewerLabel: reviewerLabelForScope("full-admin") };
    }
    throw new UnauthorizedException("The staging admin token is invalid.");
  }

  assertAdminOrigin(origin?: string): void {
    this.assertEnabled();
    const allowedOrigins = String(process.env.SAKHI_ADMIN_CORS_ORIGIN ?? "")
      .split(",")
      .map((item) => item.trim())
      .filter(Boolean);
    if (!origin || !allowedOrigins.includes(origin)) {
      throw new ForbiddenException(
        "The staging test-admin request must come from the configured Super Admin origin.",
      );
    }
  }

  async loginWithToken(token?: string) {
    await SakhiAdminRbacRegistry.ensureHydrated(this.prisma);
    const clean = token?.trim() ?? "";
    if (!clean) {
      throw new UnauthorizedException("A staging admin or staff token is required.");
    }
    const fullSecret = getFullAdminSecret() ?? "sakhi-rbac-default-secret";
    const staffMatch = SakhiAdminRbacRegistry.findStaffByToken(clean, fullSecret);
    if (staffMatch) {
      staffMatch.lastLoginAt = new Date().toISOString();
      const principal = SakhiAdminRbacRegistry.principalFromStaff(staffMatch);
      const signed = SakhiAdminRbacRegistry.createSignedStaffSessionToken(
        staffMatch,
        fullSecret,
      );
      return {
        authenticated: true as const,
        reviewerLabel: principal.reviewerLabel,
        staffId: principal.staffId,
        staffCode: principal.staffCode,
        fullName: principal.fullName,
        email: principal.email,
        role: principal.role,
        roleTitle: principal.roleTitle,
        badgeLabel: principal.badgeLabel,
        clearanceLevel: principal.clearanceLevel,
        isAuthorisedComplaintReviewer: principal.isAuthorisedComplaintReviewer,
        permissions: principal.permissions,
        allowedRoutes: principal.allowedRoutes,
        mode: "staging_full_admin" as const,
        message: `Signed in as ${principal.roleTitle} (${principal.staffCode}). Role-based workspace permissions are active.`,
        sessionToken: signed.value,
        sessionExpiresAt: signed.expiresAt.toISOString(),
      };
    }

    const session = this.session(clean);
    const sessionToken = this.createSessionToken(clean);
    const superPrincipal = SakhiAdminRbacRegistry.getSuperAdminPrincipal(
      session.reviewerLabel,
    );
    return {
      ...session,
      ...(session.mode === "staging_full_admin"
        ? {
            staffId: superPrincipal.staffId,
            staffCode: superPrincipal.staffCode,
            fullName: superPrincipal.fullName,
            email: superPrincipal.email,
            role: superPrincipal.role,
            roleTitle: superPrincipal.roleTitle,
            badgeLabel: superPrincipal.badgeLabel,
            clearanceLevel: superPrincipal.clearanceLevel,
            isAuthorisedComplaintReviewer: true,
            permissions: superPrincipal.permissions,
            allowedRoutes: superPrincipal.allowedRoutes,
          }
        : {
            role: "VERIFICATION_ADMIN" as const,
            roleTitle: "Staging Test Access Reviewer",
            badgeLabel: "Test Access Only",
            allowedRoutes: ["/test-access"],
            permissions: ADMIN_ROLE_DEFINITIONS.VERIFICATION_ADMIN.defaultPermissions,
          }),
      sessionToken: sessionToken.value,
      sessionExpiresAt: sessionToken.expiresAt.toISOString(),
    };
  }

  session(token?: string) {
    const credential = this.assertMasterCredential(token);
    const fullAdmin = credential.scope === "full-admin";
    return {
      authenticated: true as const,
      reviewerLabel: credential.reviewerLabel,
      mode: fullAdmin ? ("staging_full_admin" as const) : ("staging_test_access_only" as const),
      message: fullAdmin
        ? "Full staging-admin session. Administrative actions affect the hosted staging environment only; test-access grants remain separate from real eligibility decisions."
        : "This reviewer can grant app-feature access for staging tests only. It cannot certify phone ownership or real eligibility.",
    };
  }

  createSessionToken(token: string) {
    const credential = this.assertMasterCredential(token);
    const expiresAt = Math.floor(Date.now() / 1000) + STAGING_ADMIN_SESSION_TTL_SECONDS;
    const nonce = randomUUID();
    const payload = `${credential.scope}.${expiresAt}.${nonce}`;
    const signature = createHmac("sha256", credential.secret)
      .update("sakhi-staging-admin-session:" + payload)
      .digest("base64url");
    return {
      value: `${payload}.${signature}`,
      expiresAt: new Date(expiresAt * 1000),
      reviewerLabel: credential.reviewerLabel,
      mode: credential.scope === "full-admin"
        ? ("staging_full_admin" as const)
        : ("staging_test_access_only" as const),
    };
  }

  private assertSessionToken(sessionToken?: string) {
    return verifyStagingSession(sessionToken);
  }

  static assertFullAdminSessionToken(sessionToken?: string): string {
    return verifyStagingSession(sessionToken, "full-admin").reviewerLabel;
  }

  static resolvePrincipalFromSessionToken(
    sessionToken?: string,
  ): AuthenticatedAdminPrincipal {
    const verified = verifyStagingSession(sessionToken, "full-admin");
    return (
      verified.principal ??
      SakhiAdminRbacRegistry.getSuperAdminPrincipal(verified.reviewerLabel)
    );
  }

  async sessionFromToken(sessionToken?: string) {
    await SakhiAdminRbacRegistry.ensureHydrated(this.prisma);
    const credential = this.assertSessionToken(sessionToken);
    const fullAdmin = credential.scope === "full-admin";
    const principal =
      credential.principal ??
      SakhiAdminRbacRegistry.getSuperAdminPrincipal(credential.reviewerLabel);
    return {
      authenticated: true as const,
      reviewerLabel: credential.reviewerLabel,
      ...(fullAdmin
        ? {
            staffId: principal.staffId,
            staffCode: principal.staffCode,
            fullName: principal.fullName,
            email: principal.email,
            role: principal.role,
            roleTitle: principal.roleTitle,
            badgeLabel: principal.badgeLabel,
            clearanceLevel: principal.clearanceLevel,
            isAuthorisedComplaintReviewer:
              principal.isAuthorisedComplaintReviewer,
            permissions: principal.permissions,
            allowedRoutes: principal.allowedRoutes,
          }
        : {
            role: "VERIFICATION_ADMIN" as const,
            roleTitle: "Staging Test Access Reviewer",
            badgeLabel: "Test Access Only",
            allowedRoutes: ["/test-access"],
            permissions:
              ADMIN_ROLE_DEFINITIONS.VERIFICATION_ADMIN.defaultPermissions,
          }),
      mode: fullAdmin ? ("staging_full_admin" as const) : ("staging_test_access_only" as const),
      message: fullAdmin
        ? `Active ${principal.roleTitle} session.`
        : "This reviewer can grant app-feature access for staging tests only. It cannot certify phone ownership or real eligibility.",
    };
  }

  private async latestStates(accountIds: string[]) {
    if (accountIds.length === 0) {
      return new Map<string, { approved: boolean; createdAt: string | null }>();
    }
    const events = await this.prisma.auditEvent.findMany({
      where: {
        targetType: "member_account",
        targetId: { in: accountIds },
        action: { in: TEST_ACCESS_ACTIONS },
      },
      orderBy: { createdAt: "desc" },
      take: 2000,
      select: { targetId: true, action: true, createdAt: true },
    });
    const latest = new Map<string, { approved: boolean; createdAt: string | null }>();
    for (const event of events) {
      if (!event.targetId || latest.has(event.targetId)) continue;
      latest.set(event.targetId, {
        approved: event.action === APPROVED_ACTION,
        createdAt: event.createdAt.toISOString(),
      });
    }
    return latest;
  }

  async accounts(sessionToken?: string) {
    this.assertSessionToken(sessionToken);
    const records = await this.prisma.memberAccount.findMany({
      include: { profile: true },
      orderBy: { createdAt: "desc" },
      take: 200,
    });
    const accounts = records.filter(
      (item) =>
        item.profile !== null &&
        !["DELETED", "SUSPENDED", "RESTRICTED"].includes(item.status),
    );
    const states = await this.latestStates(accounts.map((item) => item.id));
    return accounts.map((account) => {
      const state = states.get(account.id);
      const phone = account.phoneE164;
      return {
        id: account.id,
        reference: `SK-${account.id.slice(0, 8).toUpperCase()}`,
        displayName: account.profile!.displayName,
        phoneMasked:
          phone.length <= 4
            ? "****"
            : `${"*".repeat(Math.max(0, phone.length - 4))}${phone.slice(-4)}`,
        registeredAt: account.createdAt.toISOString(),
        accountStatus: account.status,
        verificationStatus: account.verificationStatus,
        testAccessApproved: state?.approved ?? false,
        testAccessChangedAt: state?.createdAt ?? null,
        canGrantTestAccess: account.verificationStatus !== "REJECTED",
      };
    });
  }

  private assertDecision(dto: StagingTestAccessDecisionDto): string {
    if (dto.acknowledgedTestOnly !== true) {
      throw new ConflictException(
        "Explicit acknowledgement that this is test-only access is required.",
      );
    }
    const reason = dto.reason?.trim();
    if (!reason || reason.length < 10 || reason.length > 500) {
      throw new ConflictException(
        "Enter a non-sensitive reason of 10 to 500 characters.",
      );
    }
    return reason;
  }

  private async latestState(accountId: string) {
    return this.prisma.auditEvent.findFirst({
      where: {
        targetType: "member_account",
        targetId: accountId,
        action: { in: TEST_ACCESS_ACTIONS },
      },
      orderBy: { createdAt: "desc" },
      select: { action: true, createdAt: true },
    });
  }

  async approve(
    accountId: string,
    dto: StagingTestAccessDecisionDto,
    sessionToken?: string,
  ) {
    const { reviewerLabel } = this.assertSessionToken(sessionToken);
    const reason = this.assertDecision(dto);
    const account = await this.prisma.memberAccount.findUnique({
      where: { id: accountId },
      include: { profile: true },
    });
    if (!account || !account.profile) {
      throw new NotFoundException("A registered member profile was not found.");
    }
    if (["DELETED", "SUSPENDED", "RESTRICTED"].includes(account.status)) {
      throw new ConflictException("Test access cannot override a restricted account.");
    }
    if (account.verificationStatus === "REJECTED") {
      throw new ConflictException(
        "Test access cannot override a rejected eligibility decision.",
      );
    }
    const latest = await this.latestState(accountId);
    if (latest?.action === APPROVED_ACTION) {
      throw new ConflictException("Staging test access is already enabled for this account.");
    }

    const now = new Date();
    await this.prisma.$transaction(async (tx) => {
      await tx.auditEvent.create({
        data: {
          actorType: "ADMIN",
          action: APPROVED_ACTION,
          targetType: "member_account",
          targetId: accountId,
          outcome: "test_approved",
          requestId: randomUUID(),
          redactedMetadata: {
            testOnly: true,
            reviewerLabel,
            reason,
            actualEligibilityUnchanged: true,
          },
        },
      });
    });

    return {
      accountId,
      testAccessApproved: true,
      status: "test_access_enabled" as const,
      changedAt: now.toISOString(),
      reviewerLabel,
      message:
        "Staging test access enabled. Account and eligibility verification statuses were not changed.",
    };
  }

  async revoke(
    accountId: string,
    dto: StagingTestAccessDecisionDto,
    sessionToken?: string,
  ) {
    const { reviewerLabel } = this.assertSessionToken(sessionToken);
    const reason = this.assertDecision(dto);
    const account = await this.prisma.memberAccount.findUnique({
      where: { id: accountId },
      select: { id: true },
    });
    if (!account) throw new NotFoundException("The member account was not found.");
    const latest = await this.latestState(accountId);
    if (latest?.action !== APPROVED_ACTION) {
      throw new ConflictException("Staging test access is not currently enabled.");
    }

    const now = new Date();
    await this.prisma.$transaction(async (tx) => {
      await tx.auditEvent.create({
        data: {
          actorType: "ADMIN",
          action: REVOKED_ACTION,
          targetType: "member_account",
          targetId: accountId,
          outcome: "revoked",
          requestId: randomUUID(),
          redactedMetadata: {
            testOnly: true,
            reviewerLabel,
            reason,
            actualEligibilityUnchanged: true,
          },
        },
      });
    });

    return {
      accountId,
      testAccessApproved: false,
      status: "test_access_revoked" as const,
      changedAt: now.toISOString(),
      reviewerLabel,
      message:
        "Staging test access revoked. The account's actual verification status was not changed.",
    };
  }
}
