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
import type { StagingTestAccessDecisionDto } from "./staging-test-admin.dto.js";

const APPROVED_ACTION = "staging.test_access.approved";
const REVOKED_ACTION = "staging.test_access.revoked";
const TEST_ACCESS_ACTIONS = [APPROVED_ACTION, REVOKED_ACTION];
const STAGING_ADMIN_SESSION_TTL_SECONDS = 8 * 60 * 60;

@Injectable()
export class StagingTestAdminService {
  constructor(private readonly prisma: PrismaService) {}

  private assertEnabled(): string {
    if (
      process.env.SAKHI_ENV !== "staging" ||
      process.env.NODE_ENV !== "production" ||
      process.env.SAKHI_STAGING_TEST_ADMIN_ENABLED !== "true"
    ) {
      throw new ServiceUnavailableException(
        "The staging test-access admin is not enabled in this environment.",
      );
    }
    const token = process.env.SAKHI_STAGING_TEST_ADMIN_TOKEN?.trim() ?? "";
    if (token.length < 32) {
      throw new ServiceUnavailableException(
        "Staging test-admin access is not configured. Set a random server-side token of at least 32 characters.",
      );
    }
    return token;
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

  private reviewerLabel(): string {
    const configured = process.env.SAKHI_STAGING_TEST_ADMIN_REVIEWER_LABEL?.trim();
    return configured && configured.length <= 80
      ? configured
      : "Sakhi Staging Test Reviewer";
  }

  private assertReviewer(provided?: string): string {
    const expected = this.assertEnabled();
    if (!provided) {
      throw new UnauthorizedException("A staging test-admin token is required.");
    }
    const expectedDigest = createHash("sha256").update(expected).digest();
    const providedDigest = createHash("sha256").update(provided.trim()).digest();
    if (!timingSafeEqual(expectedDigest, providedDigest)) {
      throw new UnauthorizedException("The staging test-admin token is invalid.");
    }
    return this.reviewerLabel();
  }

  session(token?: string) {
    const reviewerLabel = this.assertReviewer(token);
    return {
      authenticated: true as const,
      reviewerLabel,
      mode: "staging_test_access_only" as const,
      message:
        "This reviewer can grant app-feature access for staging tests only. It cannot certify phone ownership or real eligibility.",
    };
  }

  createSessionToken(token: string) {
    const reviewerLabel = this.assertReviewer(token);
    const expiresAt = Math.floor(Date.now() / 1000) + STAGING_ADMIN_SESSION_TTL_SECONDS;
    const nonce = randomUUID();
    const payload = `${expiresAt}.${nonce}`;
    const signature = createHmac("sha256", this.assertEnabled())
      .update("sakhi-staging-admin-session:" + payload)
      .digest("base64url");
    return {
      value: `${payload}.${signature}`,
      expiresAt: new Date(expiresAt * 1000),
      reviewerLabel,
    };
  }

  private assertSessionToken(sessionToken?: string): string {
    const secret = this.assertEnabled();
    const parts = sessionToken?.split(".") ?? [];
    if (
      parts.length !== 3 ||
      !(parts[0] ?? "").split("").every((character) => character >= "0" && character <= "9") ||
      !/^[0-9a-f-]{36}$/i.test(parts[1] ?? "")
    ) {
      throw new UnauthorizedException("The staging admin session is invalid. Sign in again.");
    }
    const expiresAt = Number(parts[0]);
    const now = Math.floor(Date.now() / 1000);
    if (
      !Number.isSafeInteger(expiresAt) ||
      expiresAt <= now ||
      expiresAt > now + STAGING_ADMIN_SESSION_TTL_SECONDS + 60
    ) {
      throw new UnauthorizedException("The staging admin session has expired. Sign in again.");
    }
    const payload = `${parts[0]}.${parts[1]}`;
    const expected = createHmac("sha256", secret)
      .update("sakhi-staging-admin-session:" + payload)
      .digest();
    const supplied = Buffer.from(parts[2] ?? "", "base64url");
    if (supplied.length !== expected.length || !timingSafeEqual(supplied, expected)) {
      throw new UnauthorizedException("The staging admin session is invalid. Sign in again.");
    }
    return this.reviewerLabel();
  }

  sessionFromToken(sessionToken?: string) {
    const reviewerLabel = this.assertSessionToken(sessionToken);
    return {
      authenticated: true as const,
      reviewerLabel,
      mode: "staging_test_access_only" as const,
      message:
        "This reviewer can grant app-feature access for staging tests only. It cannot certify phone ownership or real eligibility.",
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
    const reviewerLabel = this.assertSessionToken(sessionToken);
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
    const reviewerLabel = this.assertSessionToken(sessionToken);
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
