import {
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
  ServiceUnavailableException,
  UnauthorizedException,
} from "@nestjs/common";
import {
  createHash,
  randomBytes,
  randomUUID,
  timingSafeEqual,
} from "node:crypto";
import { PrismaService } from "../database/prisma.service.js";
import {
  runWithDatabaseRequestIdentity,
  setAdminDatabaseIdentity,
} from "../database/database-request-identity.context.js";
import { AdminMfaService } from "../admin-security/admin-mfa.service.js";
import { AdminSessionService } from "../admin-security/admin-session.service.js";
import {
  SakhiAdminRbacRegistry,
  type AuthenticatedAdminPrincipal,
} from "../admin-review/admin-rbac.helper.js";
import type { StagingTestAccessDecisionDto } from "./staging-test-admin.dto.js";

const APPROVED_ACTION = "staging.test_access.approved";
const REVOKED_ACTION = "staging.test_access.revoked";
const TEST_ACCESS_ACTIONS = [APPROVED_ACTION, REVOKED_ACTION];

function assertStagingEnvironment(): void {
  if (
    process.env.SAKHI_ENV !== "staging" ||
    process.env.NODE_ENV !== "production"
  ) {
    throw new ServiceUnavailableException(
      "The staging admin is not enabled in this environment.",
    );
  }
}

function assertAdminAuthEnvironment(): void {
  const staging =
    process.env.SAKHI_ENV === "staging" &&
    process.env.NODE_ENV === "production";
  const local =
    (process.env.SAKHI_ENV === "dev" || process.env.SAKHI_ENV === "test") &&
    process.env.NODE_ENV !== "production" &&
    (process.env.HOST ?? "127.0.0.1") === "127.0.0.1";
  if (!staging && !local) {
    throw new ServiceUnavailableException(
      "Individual staff MFA authentication is available only on the dedicated staging service or loopback development/test backend.",
    );
  }
}

export function getFullAdminSecret(): string | null {
  if (
    process.env.SAKHI_ENV !== "staging" ||
    process.env.NODE_ENV !== "production" ||
    process.env.SAKHI_STAGING_FULL_ADMIN_ENABLED !== "true"
  )
    return null;
  const secret = process.env.SAKHI_STAGING_FULL_ADMIN_TOKEN?.trim() ?? "";
  return secret.length >= 32 ? secret : null;
}

function requireStaffSessionSigningKey(): string {
  const encoded = process.env.SAKHI_ADMIN_STAFF_SESSION_SIGNING_KEY ?? "";
  const key = Buffer.from(encoded, "base64");
  if (key.length !== 32 || key.toString("base64") !== encoded) {
    throw new ServiceUnavailableException(
      "Configure SAKHI_ADMIN_STAFF_SESSION_SIGNING_KEY as a base64-encoded 32-byte random key before enabling staff sessions.",
    );
  }
  return encoded;
}

function reviewerLabelForScope(): string {
  const configured = process.env.SAKHI_STAGING_FULL_ADMIN_REVIEWER_LABEL?.trim();
  return configured && configured.length <= 80
    ? configured
    : "Sakhi Staging Super Admin";
}

function verifyStaffSession(sessionToken?: string): {
  scope: "full-admin";
  reviewerLabel: string;
  principal: AuthenticatedAdminPrincipal;
} {
  if (!sessionToken?.startsWith("staff-admin.")) {
    throw new UnauthorizedException(
      "Legacy shared and stateless staging admin sessions are disabled. Use an individual MFA-verified staff account.",
    );
  }
  const staff = SakhiAdminRbacRegistry.verifySignedStaffSessionToken(
    sessionToken,
    requireStaffSessionSigningKey(),
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

@Injectable()
export class StagingTestAdminService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly staffSessions: AdminSessionService,
    private readonly staffMfa: AdminMfaService,
  ) {}

  private assertMasterCredential(provided?: string): {
    scope: "full-admin";
    secret: string;
    reviewerLabel: string;
  } {
    assertStagingEnvironment();
    if (!provided?.trim()) {
      throw new UnauthorizedException("A staging bootstrap credential is required.");
    }
    const fullSecret = getFullAdminSecret();
    if (!fullSecret) {
      throw new ServiceUnavailableException(
        "The one-time staging Super Admin bootstrap credential is not configured.",
      );
    }
    const providedDigest = createHash("sha256")
      .update(provided.trim())
      .digest();
    const expectedDigest = createHash("sha256").update(fullSecret).digest();
    if (!timingSafeEqual(expectedDigest, providedDigest)) {
      throw new UnauthorizedException("The staging bootstrap credential is invalid.");
    }
    return {
      scope: "full-admin",
      secret: fullSecret,
      reviewerLabel: reviewerLabelForScope(),
    };
  }

  assertAdminOrigin(origin?: string): void {
    assertAdminAuthEnvironment();
    const configuredOrigins = String(process.env.SAKHI_ADMIN_CORS_ORIGIN ?? "")
      .split(",")
      .map((item) => item.trim())
      .filter(Boolean);
    const allowedOrigins =
      process.env.SAKHI_ENV === "staging"
        ? configuredOrigins
        : [
            ...configuredOrigins,
            "http://localhost:5173",
            "http://127.0.0.1:5173",
          ];
    if (!origin || !allowedOrigins.includes(origin)) {
      throw new ForbiddenException(
        "The staging test-admin request must come from the configured Super Admin origin.",
      );
    }
  }

  private async lookupRawStaffCredential(token?: string) {
    const clean = token?.trim() ?? "";
    if (!clean || clean.startsWith("staff-admin.")) return null;
    const digest = createHash("sha256").update(clean).digest("hex");
    const row = await this.prisma.adminStaffAccount.findFirst({
      where: { accessTokenDigest: digest, status: "ACTIVE", suspendedAt: null, deletedAt: null },
    });
    return row
      ? SakhiAdminRbacRegistry.refreshStaffRecordFromDatabase(
          row as unknown as Record<string, unknown>,
        )
      : null;
  }

  async loginWithToken(token?: string, mfaCode?: string) {
    assertAdminAuthEnvironment();
    const clean = token?.trim() ?? "";
    if (!clean || clean.startsWith("staff-admin.")) {
      throw new UnauthorizedException(
        "A staff credential is required for MFA login.",
      );
    }

    // The one-time bootstrap credential is not a staff login credential. It
    // may only reveal that protected first-Super-Admin setup is available.
    const bootstrapSecret = getFullAdminSecret();
    if (bootstrapSecret) {
      const suppliedDigest = createHash("sha256").update(clean).digest();
      const expectedDigest = createHash("sha256").update(bootstrapSecret).digest();
      if (timingSafeEqual(suppliedDigest, expectedDigest)) {
        const existingSuperAdmin = await this.prisma.adminStaffAccount.findFirst({
          where: { role: "SUPER_ADMIN" },
          select: { id: true },
        });
        if (existingSuperAdmin) {
          throw new UnauthorizedException(
            "Initial Super Admin bootstrap is permanently closed. Use an individual staff credential.",
          );
        }
        return {
          authenticated: false as const,
          bootstrapRequired: true as const,
          message: "The initial Super Admin account must be created and enrolled in MFA.",
        };
      }
    }

    const staffMatch = await this.lookupRawStaffCredential(clean);
    if (staffMatch) {
      // Policy B: the individual access token is accepted only while the
      // account is explicitly in first-time setup. Once a password is set,
      // the token cannot be used as a login factor again.
      const setupState = await this.prisma.adminStaffAccount.findUnique({
        where: { id: staffMatch.id },
        select: { mustResetPassword: true },
      });
      if (!setupState?.mustResetPassword) {
        throw new UnauthorizedException(
          "The initial staff access token is for first-time setup only. Sign in with username/email, password and TOTP.",
        );
      }
      setAdminDatabaseIdentity(staffMatch.id, staffMatch.role);
      const mfa = await this.prisma.adminStaffMfa.findUnique({
        where: { staffId: staffMatch.id },
        select: { enrollmentVerifiedAt: true, disabledAt: true },
      });
      if (!mfa?.enrollmentVerifiedAt || mfa.disabledAt) {
        return {
          authenticated: false as const,
          mfaEnrollmentRequired: true as const,
          staffId: staffMatch.id,
          staffCode: staffMatch.staffCode,
          message:
            "Enroll an authenticator before privileged staff access can be issued.",
        };
      }
      if (!mfaCode?.trim()) {
        return {
          authenticated: false as const,
          mfaRequired: true as const,
          staffId: staffMatch.id,
          staffCode: staffMatch.staffCode,
          message:
            "Enter the current six-digit authenticator code or a single-use backup code.",
        };
      }

      await this.staffMfa.verifyLoginFactor(staffMatch.id, mfaCode);
      const issued = await this.staffSessions.issueSession(staffMatch.id);
      staffMatch.lastLoginAt = new Date().toISOString();
      const principal = SakhiAdminRbacRegistry.principalFromStaff(staffMatch);
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
        mustResetPassword: Boolean(staffMatch.mustResetPassword),
        message: `Signed in as ${principal.roleTitle} (${principal.staffCode}). Staff MFA and persistent session controls are active.`,
        sessionToken: issued.value,
        sessionExpiresAt: issued.expiresAt.toISOString(),
      };
    }

    throw new UnauthorizedException(
      "A valid individual staff first-factor credential is required. Shared staging admin credentials cannot authenticate a staff session.",
    );
  }

  async bootstrapSuperAdmin(
    bootstrapToken: string | undefined,
    fullName: string,
    email: string,
  ) {
    const credential = this.assertMasterCredential(bootstrapToken);
    if (credential.scope !== "full-admin") {
      throw new UnauthorizedException(
        "The one-time Super Admin bootstrap credential is invalid.",
      );
    }
    const existingSuperAdmins = await this.prisma.adminStaffAccount.findMany({
      where: { role: "SUPER_ADMIN" },
      select: { id: true },
      take: 1,
    });
    if (existingSuperAdmins.length > 0) {
      throw new ConflictException(
        "A Super Admin account already exists; bootstrap is permanently closed.",
      );
    }
    let created: Awaited<ReturnType<typeof SakhiAdminRbacRegistry.createStaffAccount>>;
    // Bootstrap is unauthenticated; establish the new staff identity only for
    // this transaction so its matching ADMIN audit insert satisfies RLS.
    const bootstrapStaffId = randomUUID();
    try {
      created = await runWithDatabaseRequestIdentity(
        () =>
          SakhiAdminRbacRegistry.createStaffAccount(
            this.prisma,
            { fullName, email, role: "SUPER_ADMIN", mustResetPassword: true },
            "One-time protected Super Admin bootstrap",
            bootstrapStaffId,
            bootstrapStaffId,
          ),
        { adminStaffId: bootstrapStaffId, adminRole: "SUPER_ADMIN" },
      );
    } catch (error) {
      const errorRecord =
        error && typeof error === "object"
          ? (error as { code?: unknown; meta?: { target?: unknown }; message?: unknown })
          : null;
      const uniqueTarget = Array.isArray(errorRecord?.meta?.target)
        ? errorRecord.meta.target.join(",")
        : String(errorRecord?.meta?.target ?? "");
      const errorMessage = String(errorRecord?.message ?? "");
      if (
        errorRecord?.code === "P2002" &&
        (uniqueTarget.includes("created_by") ||
          errorMessage.includes("admin_staff_one_time_super_admin_bootstrap_unique"))
      ) {
        throw new ConflictException(
          "The one-time Super Admin bootstrap has already been completed.",
        );
      }
      throw error;
    }
    return {
      created: true as const,
      staffCode: created.staff.staffCode,
      accessToken: created.issuedAccessToken,
      mfaEnrollmentRequired: true as const,
    };
  }

  private async findRawStaffCredential(token?: string) {
    const staff = await this.lookupRawStaffCredential(token);
    if (!staff) {
      throw new UnauthorizedException("The staff credential is invalid.");
    }
    return staff;
  }

  async startStaffMfaEnrollment(token?: string) {
    assertAdminAuthEnvironment();
    const staff = await this.findRawStaffCredential(token);
    setAdminDatabaseIdentity(staff.id, staff.role);
    const enrollment = await this.staffMfa.beginEnrollment(staff.id);
    return { staffId: staff.id, ...enrollment };
  }

  async verifyStaffMfaEnrollment(token: string | undefined, code: string) {
    assertAdminAuthEnvironment();
    const staff = await this.findRawStaffCredential(token);
    setAdminDatabaseIdentity(staff.id, staff.role);
    return this.staffMfa.verifyEnrollment(staff.id, code);
  }

  async requestStaffMfaRecovery(token?: string) {
    assertAdminAuthEnvironment();
    const staff = await this.findRawStaffCredential(token);
    setAdminDatabaseIdentity(staff.id, staff.role);
    return this.staffMfa.requestRecovery(staff.id);
  }

  async listStaffMfaRecoveryRequests(approverSessionToken?: string) {
    assertAdminAuthEnvironment();
    const { staff } = await this.staffSessions.validateSession(approverSessionToken ?? "");
    const current = SakhiAdminRbacRegistry.refreshStaffRecordFromDatabase(
      staff as unknown as Record<string, unknown>,
    );
    const principal = SakhiAdminRbacRegistry.principalFromStaff(current);
    if (principal.role !== "SUPER_ADMIN" || !principal.permissions.approve) {
      throw new ForbiddenException("Only an MFA-verified Super Admin with approve permission may view recovery requests.");
    }
    return this.staffMfa.listPendingRecoveryRequests();
  }

  async rotateStaffMfaEncryptionKeys(approverSessionToken?: string) {
    assertAdminAuthEnvironment();
    const { staff } = await this.staffSessions.validateSession(approverSessionToken ?? "");
    const current = SakhiAdminRbacRegistry.refreshStaffRecordFromDatabase(
      staff as unknown as Record<string, unknown>,
    );
    const principal = SakhiAdminRbacRegistry.principalFromStaff(current);
    if (principal.role !== "SUPER_ADMIN" || !principal.permissions.approve) {
      throw new ForbiddenException("Only an MFA-verified Super Admin with approve permission may rotate stored MFA encryption keys.");
    }
    return this.staffMfa.rotateStoredEncryptionKeys(staff.id);
  }

  async approveStaffMfaRecovery(
    requestId: string,
    approverSessionToken?: string,
  ) {
    assertAdminAuthEnvironment();
    const { staff } = await this.staffSessions.validateSession(
      approverSessionToken ?? "",
    );
    const principal = SakhiAdminRbacRegistry.principalFromStaff(
      SakhiAdminRbacRegistry.refreshStaffRecordFromDatabase(
        staff as unknown as Record<string, unknown>,
      ),
    );
    if (staff.role !== "SUPER_ADMIN" || !principal.permissions.approve) {
      throw new ForbiddenException(
        "Only an independent MFA-verified Super Admin with approve permission may approve staff MFA recovery.",
      );
    }
    return this.staffMfa.approveRecoveryRequest(requestId, staff.id);
  }

  async completeStaffMfaRecovery(
    token: string | undefined,
    recoveryToken: string,
  ) {
    assertAdminAuthEnvironment();
    const staff = await this.findRawStaffCredential(token);
    setAdminDatabaseIdentity(staff.id, staff.role);
    return this.staffMfa.completeRecovery(staff.id, recoveryToken);
  }

  async rotateStaffSession(sessionToken?: string) {
    if (!sessionToken)
      throw new UnauthorizedException("A staff session is required.");
    const rotated = await this.staffSessions.rotateSession(sessionToken);
    return {
      sessionToken: rotated.value,
      sessionExpiresAt: rotated.expiresAt.toISOString(),
    };
  }

  async logout(sessionToken?: string) {
    if (sessionToken?.startsWith("staff-admin.")) {
      const result = await this.staffSessions.revokeSession(
        sessionToken,
        "LOGOUT",
      );
      return { signedOut: true, serverSessionRevoked: result.revoked };
    }
    return { signedOut: true, serverSessionRevoked: false };
  }


  private assertSessionToken(sessionToken?: string) {
    return verifyStaffSession(sessionToken);
  }

  private async assertTestAccessStaff(
    sessionToken: string | undefined,
    permission: "view" | "approve" | "suspend",
  ): Promise<AuthenticatedAdminPrincipal> {
    assertStagingEnvironment();
    const { staff } = await this.staffSessions.validateSession(sessionToken ?? "");
    const currentStaff = SakhiAdminRbacRegistry.refreshStaffRecordFromDatabase(
      staff as unknown as Record<string, unknown>,
    );
    const principal = SakhiAdminRbacRegistry.principalFromStaff(currentStaff);
    if (!["SUPER_ADMIN", "VERIFICATION_ADMIN"].includes(principal.role)) {
      throw new ForbiddenException(
        "Only an MFA-verified Super Admin or Verification Admin may administer staging test access.",
      );
    }
    if (!principal.permissions[permission]) {
      throw new ForbiddenException(
        "The " + permission + " permission is required to administer staging test access.",
      );
    }
    return principal;
  }


  static resolvePrincipalFromSessionToken(
    sessionToken?: string,
  ): AuthenticatedAdminPrincipal {
    assertAdminAuthEnvironment();
    const verified = verifyStaffSession(sessionToken);
    if (!verified.principal) {
      throw new UnauthorizedException(
        "An individual persistent staff session is required.",
      );
    }
    return verified.principal;
  }

  async sessionFromToken(sessionToken?: string) {
    await SakhiAdminRbacRegistry.ensureHydrated(this.prisma);
    const validated = await this.staffSessions.validateSession(sessionToken ?? "");
    const credential = this.assertSessionToken(sessionToken);
    const currentStaff = SakhiAdminRbacRegistry.refreshStaffRecordFromDatabase(
      validated.staff as unknown as Record<string, unknown>,
    );
    const principal = credential.principal;
    if (!principal) {
      throw new UnauthorizedException(
        "An individual persistent staff session is required.",
      );
    }
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
      mustResetPassword: Boolean(currentStaff.mustResetPassword),
      message: `Active ${principal.roleTitle} session.`,
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
    const latest = new Map<
      string,
      { approved: boolean; createdAt: string | null }
    >();
    for (const event of events) {
      if (!event.targetId || latest.has(event.targetId)) continue;
      latest.set(event.targetId, {
        approved: event.action === APPROVED_ACTION,
        createdAt: event.createdAt.toISOString(),
      });
    }
    return latest;
  }

  /**
   * Creates a disposable, unmistakably synthetic staging member fixture.
   * Requires an MFA-verified staff principal with approve permission.
   */
  async createSyntheticMemberFixture(
    dto: StagingTestAccessDecisionDto,
    sessionToken?: string,
  ) {
    const principal = await this.assertTestAccessStaff(sessionToken, "approve");
    if (principal.role !== "SUPER_ADMIN") {
      throw new ForbiddenException("Only an MFA-verified Super Admin may create synthetic member fixtures.");
    }
    const reason = this.assertDecision(dto);
    assertStagingEnvironment();
    if (process.env.SAKHI_SYNTHETIC_FIXTURE_ENABLED !== "true") {
      throw new ServiceUnavailableException("Synthetic staging fixtures are disabled.");
    }

    const fixtureId = randomUUID();
    const accountId = randomUUID();
    const opaque = fixtureId.replace(/-/g, "").slice(0, 12);
    const phoneE164 = "+999" + opaque;
    const username = "@synthetic_" + opaque;
    const email = "synthetic-" + fixtureId + "@example.invalid";
    const accessToken = randomBytes(32).toString("base64url");
    const now = new Date();
    const sessionExpiresAt = new Date(now.getTime() + 60 * 60 * 1000);
    const fixtureExpiresAt = new Date(now.getTime() + 24 * 60 * 60 * 1000);
    const tokenDigest = createHash("sha256").update(accessToken).digest("hex");

    await this.prisma.$transaction(async (tx) => {
      await tx.memberAccount.create({
        data: {
          id: accountId,
          phoneE164,
          phoneVerifiedAt: null,
          status: "ACTIVE",
          verificationStatus: "UNVERIFIED",
        },
      });
      await tx.memberProfile.create({
        data: {
          accountId,
          displayName: "Synthetic Sakhi Test " + opaque,
          username,
          email,
          dateOfBirth: new Date("1990-01-01T00:00:00.000Z"),
          bio: "Synthetic staging fixture only. No real person.",
          location: "",
          interests: [],
        },
      });
      await tx.authSession.create({
        data: {
          accountId,
          tokenDigest,
          expiresAt: sessionExpiresAt,
          deviceName: "Sakhi synthetic staging fixture",
        },
      });
      await tx.auditEvent.create({
        data: {
          actorType: "ADMIN",
          actorId: principal.staffId,
          action: "staging.synthetic_member.created",
          targetType: "synthetic_member_fixture",
          targetId: fixtureId,
          outcome: "created",
          requestId: fixtureId,
          redactedMetadata: {
            testOnly: true,
            syntheticFixture: true,
            fixtureId,
            accountId,
            phoneNamespace: "+999 synthetic-only; no SMS",
            reason,
            reviewerLabel: principal.reviewerLabel,
            expiresAt: fixtureExpiresAt.toISOString(),
          },
        },
      });
    });

    return {
      created: true as const,
      testOnly: true as const,
      fixtureId,
      accountId,
      displayName: "Synthetic Sakhi Test " + opaque,
      authorization: "Bearer " + accessToken,
      sessionExpiresAt: sessionExpiresAt.toISOString(),
      message: "Synthetic staging-only member created. Treat the returned bearer credential as a secret; never log or commit it.",
    };
  }

  async accounts(sessionToken?: string) {
    await this.assertTestAccessStaff(sessionToken, "view");
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
    const principal = await this.assertTestAccessStaff(sessionToken, "approve");
    const reviewerLabel = principal.reviewerLabel;
    const reason = this.assertDecision(dto);
    const account = await this.prisma.memberAccount.findUnique({
      where: { id: accountId },
      include: { profile: true },
    });
    if (!account || !account.profile) {
      throw new NotFoundException("A registered member profile was not found.");
    }
    if (["DELETED", "SUSPENDED", "RESTRICTED"].includes(account.status)) {
      throw new ConflictException(
        "Test access cannot override a restricted account.",
      );
    }
    if (account.verificationStatus === "REJECTED") {
      throw new ConflictException(
        "Test access cannot override a rejected eligibility decision.",
      );
    }
    const latest = await this.latestState(accountId);
    if (latest?.action === APPROVED_ACTION) {
      throw new ConflictException(
        "Staging test access is already enabled for this account.",
      );
    }

    const now = new Date();
    await this.prisma.$transaction(async (tx) => {
      await tx.auditEvent.create({
        data: {
          actorType: "ADMIN",
          actorId: principal.staffId,
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
    const principal = await this.assertTestAccessStaff(sessionToken, "suspend");
    const reviewerLabel = principal.reviewerLabel;
    const reason = this.assertDecision(dto);
    const account = await this.prisma.memberAccount.findUnique({
      where: { id: accountId },
      select: { id: true },
    });
    if (!account)
      throw new NotFoundException("The member account was not found.");
    const latest = await this.latestState(accountId);
    if (latest?.action !== APPROVED_ACTION) {
      throw new ConflictException(
        "Staging test access is not currently enabled.",
      );
    }

    const now = new Date();
    await this.prisma.$transaction(async (tx) => {
      await tx.auditEvent.create({
        data: {
          actorType: "ADMIN",
          actorId: principal.staffId,
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
