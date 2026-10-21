import {
  BadRequestException,
  ConflictException,
  HttpException,
  HttpStatus,
  Injectable,
  ServiceUnavailableException,
  UnauthorizedException,
} from "@nestjs/common";
import {
  createHash,
  randomBytes,
  randomInt,
  randomUUID,
  timingSafeEqual,
} from "node:crypto";
import type { Prisma } from "../generated/prisma/client.js";
import { PrismaService } from "../database/prisma.service.js";
import type {
  CreateProfileDto,
  RequestOtpDto,
  VerifyOtpDto,
} from "./auth.dto.js";

const OTP_TTL_MS = 5 * 60 * 1000;
const RESEND_COOLDOWN_MS = 30 * 1000;
const OTP_WINDOW_MS = 15 * 60 * 1000;
const OTP_MAX_REQUESTS_PER_WINDOW = 5;
const OTP_ATTEMPT_LIMIT = 5;
const SESSION_TTL_MS = 12 * 60 * 60 * 1000;

type Transaction = Prisma.TransactionClient;

class TooManyRequestsException extends HttpException {
  constructor(message: string) {
    super(message, HttpStatus.TOO_MANY_REQUESTS);
  }
}

type AccountState =
  "newAccount" | "existingAccount" | "pendingVerification" | "restricted";

@Injectable()
export class AuthenticationService {
  constructor(private readonly prisma: PrismaService) {}

  private stagingTestPhoneAllowlist(): string[] {
    return String(process.env.SAKHI_STAGING_TEST_PHONE_ALLOWLIST ?? "")
      .split(",")
      .map((phone) => phone.trim())
      .filter(Boolean);
  }

  private isStagingTestPhoneAllowed(phoneE164: string): boolean {
    const allowlist = this.stagingTestPhoneAllowlist();
    return (
      allowlist.includes(phoneE164) ||
      (allowlist.includes("+91*") && /^\+91[6-9]\d{9}$/.test(phoneE164))
    );
  }

  private isStagingTestModeEnabled(): boolean {
    const allowlist = this.stagingTestPhoneAllowlist();
    const code = String(process.env.SAKHI_STAGING_TEST_OTP_CODE ?? "");
    return (
      process.env.SAKHI_ENV === "staging" &&
      process.env.NODE_ENV === "production" &&
      (process.env.HOST ?? "0.0.0.0") === "0.0.0.0" &&
      process.env.SAKHI_OTP_MODE === "staging_test" &&
      /^\d{6}$/.test(code) &&
      process.env.SAKHI_STAGING_TEST_MINIMUM_AGE_YEARS === "18" &&
      allowlist.length > 0 &&
      (!allowlist.includes("+91*") || allowlist.length === 1) &&
      allowlist.every(
        (phone) => phone === "+91*" || /^\+[1-9]\d{7,14}$/.test(phone),
      ) &&
      new Set(allowlist).size === allowlist.length
    );
  }

  private isStagingTestApprovalFeatureEnabled(): boolean {
    return (
      this.isStagingTestModeEnabled() &&
      process.env.SAKHI_STAGING_TEST_ADMIN_ENABLED === "true" &&
      (process.env.SAKHI_STAGING_TEST_ADMIN_TOKEN?.trim().length ?? 0) >= 32
    );
  }

  async hasActiveStagingTestApproval(accountId: string): Promise<boolean> {
    if (!this.isStagingTestApprovalFeatureEnabled()) return false;
    const latest = await this.prisma.auditEvent.findFirst({
      where: {
        targetType: "member_account",
        targetId: accountId,
        action: {
          in: ["staging.test_access.approved", "staging.test_access.revoked"],
        },
      },
      orderBy: { createdAt: "desc" },
      select: { action: true },
    });
    return latest?.action === "staging.test_access.approved";
  }

  private assertOtpModeEnabled(): "development" | "staging_test" {
    const localEnvironment =
      process.env.SAKHI_ENV === "dev" || process.env.SAKHI_ENV === "test";
    if (
      process.env.NODE_ENV !== "production" &&
      localEnvironment &&
      process.env.SAKHI_OTP_MODE === "development" &&
      (process.env.HOST ?? "127.0.0.1") === "127.0.0.1"
    ) {
      return "development";
    }
    if (this.isStagingTestModeEnabled()) {
      return "staging_test";
    }
    throw new ServiceUnavailableException(
      "OTP delivery is not configured. No SMS was sent.",
    );
  }

  private assertStagingTestPhoneAllowed(
    phoneE164: string,
    mode: "development" | "staging_test",
  ): void {
    if (mode === "staging_test" && !this.isStagingTestPhoneAllowed(phoneE164)) {
      throw new UnauthorizedException(
        "This phone number is not enabled for Sakhi staging test access.",
      );
    }
  }

  private stagingTestCode(): string {
    const code = String(process.env.SAKHI_STAGING_TEST_OTP_CODE ?? "");
    if (!/^\d{6}$/.test(code)) {
      throw new ServiceUnavailableException(
        "Staging test login is not fully configured.",
      );
    }
    return code;
  }

  private phoneE164(countryCode: string, phoneNumber: string): string {
    const full = countryCode + phoneNumber;
    if (!/^\+[1-9]\d{7,14}$/.test(full)) {
      throw new BadRequestException(
        "Enter a valid international phone number.",
      );
    }
    return full;
  }

  private digestOtp(challengeId: string, code: string): string {
    // A per-challenge digest avoids storing the short OTP in plaintext.
    return createHash("sha256")
      .update(challengeId + ":" + code)
      .digest("hex");
  }

  private digestToken(token: string): string {
    return createHash("sha256").update(token).digest("hex");
  }

  private newOtp(): string {
    return randomInt(0, 1_000_000).toString().padStart(6, "0");
  }

  private assertOtpWindow(count: number): void {
    if (count >= OTP_MAX_REQUESTS_PER_WINDOW) {
      throw new TooManyRequestsException(
        "Too many development code requests. Wait before trying again.",
      );
    }
  }

  private async createChallenge(
    tx: Transaction,
    args: {
      phoneE164: string;
      purpose: "LOGIN" | "REGISTRATION";
      accountId: string | null;
      mode: "development" | "staging_test";
    },
  ): Promise<{
    challengeId: string;
    expiresAt: string;
    resendAvailableAt: string;
    developmentCode?: string;
  }> {
    const now = new Date();
    const id = randomUUID();
    const code = args.mode === "staging_test"
      ? this.stagingTestCode()
      : this.newOtp();
    const expiresAt = new Date(now.getTime() + OTP_TTL_MS);
    const resendAvailableAt = new Date(now.getTime() + RESEND_COOLDOWN_MS);

    await tx.otpChallenge.create({
      data: {
        id,
        accountId: args.accountId,
        phoneE164: args.phoneE164,
        purpose: args.purpose,
        codeDigest: this.digestOtp(id, code),
        attemptCount: 0,
        attemptLimit: OTP_ATTEMPT_LIMIT,
        expiresAt,
        resendAvailableAt,
      },
    });

    await tx.auditEvent.createMany({
      data: {
        actorType: "SYSTEM",
        action: "auth.otp.requested",
        targetType: "otp_challenge",
        targetId: id,
        outcome: "created",
        requestId: id,
        redactedMetadata: {
          purpose: args.purpose.toLowerCase(),
          deliveryMode: args.mode === "staging_test"
            ? "staging_test_shared_code"
            : "development_echo",
        },
      },
    });

    // The shared staging test code is never returned to the client. It is
    // configured as a protected host environment variable and only permitted
    // for the explicit phone-number allowlist.
    return {
      challengeId: id,
      expiresAt: expiresAt.toISOString(),
      resendAvailableAt: resendAvailableAt.toISOString(),
      ...(args.mode === "development" ? { developmentCode: code } : {}),
    };
  }

  async requestOtp(dto: RequestOtpDto) {
    const mode = this.assertOtpModeEnabled();
    const phoneE164 = this.phoneE164(dto.countryCode, dto.phoneNumber);
    this.assertStagingTestPhoneAllowed(phoneE164, mode);
    const now = new Date();
    const windowStart = new Date(now.getTime() - OTP_WINDOW_MS);

    return this.prisma.$transaction(async (tx) => {
      const requestCount = await tx.otpChallenge.count({
        where: { phoneE164, createdAt: { gte: windowStart } },
      });
      this.assertOtpWindow(requestCount);

      const account = await tx.memberAccount.findUnique({
        where: { phoneE164 },
        select: {
          id: true,
          profile: { select: { accountId: true } },
        },
      });

      const isRegistered = Boolean(
        account && (!("profile" in account) || account.profile !== null),
      );

      // A login request must not issue a challenge for a number without a
      // completed account+profile. New or incomplete numbers must use the
      // explicit registration flow instead.
      if (dto.purpose === "registration" && isRegistered) {
        throw new ConflictException(
          "A Sakhi account already exists for this number. Choose Sign in instead.",
        );
      }

      if (dto.purpose === "login" && !isRegistered) {
        throw new BadRequestException(
          "No Sakhi account was found for this number. Choose Create account to register.",
        );
      }

      const result = await this.createChallenge(tx, {
        phoneE164,
        purpose: dto.purpose === "login" ? "LOGIN" : "REGISTRATION",
        accountId: account?.id ?? null,
        mode,
      });

      return {
        ...result,
        deliveryMode: mode === "staging_test"
          ? ("staging_test_shared_code" as const)
          : ("development_echo" as const),
        isDemo: true,
        message: mode === "staging_test"
          ? "Staging test access only. No SMS was sent; this shared code does not verify phone ownership or eligibility."
          : "Development code only. No SMS was sent and the phone number has not been verified by a carrier.",
      };
    });
  }

  async resendOtp(challengeId: string) {
    const mode = this.assertOtpModeEnabled();
    const now = new Date();

    return this.prisma.$transaction(async (tx) => {
      const previous = await tx.otpChallenge.findUnique({
        where: { id: challengeId },
      });
      if (!previous || previous.consumedAt) {
        throw new BadRequestException(
          "This code request is no longer available. Request a new code.",
        );
      }
      this.assertStagingTestPhoneAllowed(previous.phoneE164, mode);
      if (previous.expiresAt <= now) {
        throw new BadRequestException(
          "This code request has expired. Request a new code.",
        );
      }
      if (previous.resendAvailableAt > now) {
        throw new TooManyRequestsException(
          "Please wait before requesting another development code.",
        );
      }

      const windowStart = new Date(now.getTime() - OTP_WINDOW_MS);
      const requestCount = await tx.otpChallenge.count({
        where: {
          phoneE164: previous.phoneE164,
          createdAt: { gte: windowStart },
        },
      });
      this.assertOtpWindow(requestCount);

      await tx.otpChallenge.update({
        where: { id: previous.id },
        data: { consumedAt: now },
      });

      const result = await this.createChallenge(tx, {
        phoneE164: previous.phoneE164,
        purpose: previous.purpose,
        accountId: previous.accountId,
        mode,
      });
      return {
        ...result,
        deliveryMode: mode === "staging_test"
          ? ("staging_test_shared_code" as const)
          : ("development_echo" as const),
        isDemo: true,
        message: mode === "staging_test"
          ? "Staging test access only. No SMS was sent; this shared code does not verify phone ownership or eligibility."
          : "New development code generated. No SMS was sent.",
      };
    });
  }

  private accountState(
    status: string,
    verificationStatus: string,
  ): AccountState {
    if (status === "RESTRICTED" || status === "SUSPENDED" || status === "DELETED") {
      return "restricted";
    }
    if (status === "ACTIVE" && verificationStatus === "VERIFIED") {
      return "existingAccount";
    }
    return "pendingVerification";
  }

  async verifyOtp(dto: VerifyOtpDto) {
    const mode = this.assertOtpModeEnabled();
    const now = new Date();

    return this.prisma.$transaction(async (tx) => {
      const challenge = await tx.otpChallenge.findUnique({
        where: { id: dto.challengeId },
      });
      if (!challenge) {
        return {
          status: "invalid" as const,
          message:
            "This code could not be verified. Request a new code and try again.",
        };
      }
      this.assertStagingTestPhoneAllowed(challenge.phoneE164, mode);
      if (challenge.consumedAt) {
        return {
          status: "expired" as const,
          message:
            "This code request has already been used. Request a new code.",
        };
      }
      if (challenge.expiresAt <= now) {
        await tx.otpChallenge.update({
          where: { id: challenge.id },
          data: { consumedAt: now },
        });
        return {
          status: "expired" as const,
          message: "This code has expired. Request a new development code.",
        };
      }
      if (challenge.attemptCount >= challenge.attemptLimit) {
        await tx.otpChallenge.update({
          where: { id: challenge.id },
          data: { consumedAt: now },
        });
        return {
          status: "tooManyAttempts" as const,
          message: "Too many attempts. Request a new development code later.",
        };
      }

      // The conditional update prevents simultaneous requests from bypassing
      // the per-challenge attempt limit.
      const attempt = await tx.otpChallenge.updateMany({
        where: {
          id: challenge.id,
          consumedAt: null,
          expiresAt: { gt: now },
          attemptCount: { lt: challenge.attemptLimit },
        },
        data: { attemptCount: { increment: 1 } },
      });
      if (attempt.count !== 1) {
        return {
          status: "tooManyAttempts" as const,
          message: "This code request is no longer valid. Request a new code.",
        };
      }

      const expectedDigest = challenge.codeDigest
        ? Buffer.from(challenge.codeDigest, "hex")
        : Buffer.alloc(0);
      const suppliedDigest = Buffer.from(
        this.digestOtp(challenge.id, dto.code),
        "hex",
      );
      const validDigest =
        expectedDigest.length === suppliedDigest.length &&
        expectedDigest.length > 0 &&
        timingSafeEqual(expectedDigest, suppliedDigest);
      if (!validDigest) {
        if (challenge.attemptCount + 1 >= challenge.attemptLimit) {
          await tx.otpChallenge.updateMany({
            where: { id: challenge.id, consumedAt: null },
            data: { consumedAt: now },
          });
          return {
            status: "tooManyAttempts" as const,
            message: "Too many attempts. Request a new development code later.",
          };
        }
        return {
          status: "invalid" as const,
          message: "That code is not correct. Try again.",
        };
      }

      let account = await tx.memberAccount.findUnique({
        where: { phoneE164: challenge.phoneE164 },
        include: { profile: { select: { accountId: true } } },
      });

      const isRegistered = Boolean(
        account && (!("profile" in account) || account.profile !== null),
      );

      if (challenge.purpose === "LOGIN" && !isRegistered) {
        await tx.otpChallenge.update({
          where: { id: challenge.id },
          data: { consumedAt: now },
        });
        return {
          status: "invalid" as const,
          message:
            "No Sakhi account was found for this number. Choose Create account to register.",
        };
      }

      if (challenge.purpose === "REGISTRATION" && isRegistered) {
        await tx.otpChallenge.update({
          where: { id: challenge.id },
          data: { consumedAt: now },
        });
        return {
          status: "invalid" as const,
          message:
            "A Sakhi account already exists for this number. Choose Sign in instead.",
        };
      }

      await tx.otpChallenge.update({
        where: { id: challenge.id },
        data: { consumedAt: now },
      });

      if (!account && challenge.purpose === "REGISTRATION") {
        const created = await tx.memberAccount.create({
          data: {
            phoneE164: challenge.phoneE164,
            // Shared staging test codes never prove phone ownership.
            phoneVerifiedAt: mode === "staging_test" ? null : now,
            status: "PENDING_VERIFICATION",
            verificationStatus: "UNVERIFIED",
          },
        });
        account = { ...created, profile: null };
      }

      if (!account) {
        return {
          status: "invalid" as const,
          message: "This code could not be verified. Request a new code.",
        };
      }

      if (
        account.status === "DELETED" ||
        account.status === "SUSPENDED" ||
        account.status === "RESTRICTED"
      ) {
        return {
          status: "verified" as const,
          accountState: "restricted" as const,
          message: "This account cannot sign in. Contact Sakhi support.",
        };
      }

      if (mode !== "staging_test") {
        await tx.memberAccount.update({
          where: { id: account.id },
          data: { phoneVerifiedAt: now },
        });
      }

      const token = randomBytes(32).toString("base64url");
      const expiresAt = new Date(now.getTime() + SESSION_TTL_MS);
      await tx.authSession.create({
        data: {
          accountId: account.id,
          tokenDigest: this.digestToken(token),
          expiresAt,
        },
      });

      const state: AccountState =
        mode === "staging_test"
          ? challenge.purpose === "REGISTRATION"
            ? "newAccount"
            : "existingAccount"
          : challenge.purpose === "REGISTRATION"
            ? "newAccount"
            : this.accountState(account.status, account.verificationStatus);

      await tx.auditEvent.createMany({
        data: {
          actorType: "MEMBER",
          actorId: account.id,
          action: mode === "staging_test"
            ? "auth.staging_test_code.accepted"
            : "auth.otp.verified",
          targetType: "member_account",
          targetId: account.id,
          outcome: "success",
          requestId: challenge.id,
          redactedMetadata: {
            purpose: challenge.purpose.toLowerCase(),
            authenticationMode: mode,
            phoneOwnershipVerified: mode !== "staging_test",
          },
        },
      });

      return {
        status: "verified" as const,
        accountState: state,
        accessToken: token,
        tokenType: "Bearer" as const,
        expiresAt: expiresAt.toISOString(),
        isDemo: true,
        message: mode === "staging_test"
          ? "Staging test access only. Phone ownership and eligibility remain unverified."
          : "Development authentication only. This session is local test access, not production identity verification.",
      };
    });
  }

  async authenticateAuthorization(authorization?: string) {
    if (!authorization?.startsWith("Bearer ")) {
      throw new UnauthorizedException("Sign in to continue.");
    }
    const token = authorization.slice("Bearer ".length).trim();
    if (token.length < 32 || token.length > 256) {
      throw new UnauthorizedException(
        "Your session is invalid. Sign in again.",
      );
    }

    const session = await this.prisma.authSession.findUnique({
      where: { tokenDigest: this.digestToken(token) },
      include: { account: true },
    });
    if (
      !session ||
      session.revokedAt ||
      session.expiresAt <= new Date() ||
      ["DELETED", "SUSPENDED", "RESTRICTED"].includes(session.account.status)
    ) {
      throw new UnauthorizedException(
        "Your session is expired or unavailable. Sign in again.",
      );
    }
    const testAccessApproved = await this.hasActiveStagingTestApproval(
      session.accountId,
    );
    return { ...session, testAccessApproved };
  }

  async createProfile(
    authorization: string | undefined,
    dto: CreateProfileDto,
  ) {
    const session = await this.authenticateAuthorization(authorization);
    const configuredAge = process.env.SAKHI_PREVIEW_MINIMUM_AGE_YEARS;
    const localDevelopmentMode =
      process.env.NODE_ENV !== "production" &&
      (process.env.SAKHI_ENV === "dev" || process.env.SAKHI_ENV === "test") &&
      configuredAge === "13";
    const stagingTestMode =
      this.isStagingTestModeEnabled() &&
      this.isStagingTestPhoneAllowed(session.account.phoneE164);
    if (!localDevelopmentMode && !stagingTestMode) {
      throw new ServiceUnavailableException(
        "The registration test policy is not configured for this environment. No profile was saved.",
      );
    }
    const minimumAge = stagingTestMode ? 18 : 13;

    const dob = new Date(dto.dateOfBirth + "T00:00:00.000Z");
    const acceptedAt = new Date(dto.acceptedAt);
    if (
      Number.isNaN(dob.getTime()) ||
      dob.toISOString().slice(0, 10) !== dto.dateOfBirth
    ) {
      throw new BadRequestException("Enter a valid date of birth.");
    }
    const today = new Date();
    let age = today.getUTCFullYear() - dob.getUTCFullYear();
    const monthDifference = today.getUTCMonth() - dob.getUTCMonth();
    if (
      monthDifference < 0 ||
      (monthDifference === 0 && today.getUTCDate() < dob.getUTCDate())
    ) {
      age--;
    }
    if (
      age < minimumAge ||
      dob >
        new Date(
          Date.UTC(
            today.getUTCFullYear(),
            today.getUTCMonth(),
            today.getUTCDate(),
          ),
        )
    ) {
      throw new BadRequestException(
        stagingTestMode
          ? "Staging test profiles must meet the temporary minimum age of 18."
          : "The profile does not meet the temporary development age rule.",
      );
    }
    if (Number.isNaN(acceptedAt.getTime())) {
      throw new BadRequestException(
        "The draft policy acknowledgement time is invalid.",
      );
    }

    return this.prisma.$transaction(async (tx) => {
      const existingProfile = await tx.memberProfile.findUnique({
        where: { accountId: session.accountId },
        select: { accountId: true },
      });
      if (existingProfile) {
        throw new ConflictException(
          "A profile already exists for this account. Use the profile-management flow to make changes.",
        );
      }

      const [terms, privacy] = await Promise.all([
        tx.policyDocumentVersion.findFirst({
          where: { documentType: "TERMS", status: "DRAFT" },
          orderBy: { createdAt: "desc" },
        }),
        tx.policyDocumentVersion.findFirst({
          where: { documentType: "PRIVACY", status: "DRAFT" },
          orderBy: { createdAt: "desc" },
        }),
      ]);
      if (!terms || !privacy) {
        throw new ServiceUnavailableException(
          "Draft policy metadata is missing. Apply the migration and run the safe development seed first.",
        );
      }

      const cleanDisplayName = dto.displayName.trim();
      const baseSlug = cleanDisplayName.toLowerCase().replace(/[^a-z0-9]+/g, "").slice(0, 18) || "member";
      const candidateUsername = `@${baseSlug}_${session.accountId.slice(0, 4).toLowerCase()}`;
      const chosenAvatar = dto.avatarAsset?.trim() || "assets/images/profile/avatar_ananya.webp";

      const profile = await tx.memberProfile.create({
        data: {
          accountId: session.accountId,
          displayName: cleanDisplayName,
          dateOfBirth: dob,
          email: dto.email?.trim().toLowerCase() || null,
          ...(process.env.SAKHI_ENV === "dev"
            ? {
                username: candidateUsername,
                avatarAsset: chosenAvatar,
              }
            : {}),
        },
      });

      if (process.env.SAKHI_ENV === "dev" && "communityDirectoryProfile" in tx && "eligibilitySubmission" in tx) {
        try {
          await tx.communityDirectoryProfile.upsert({
            where: { username: candidateUsername },
            update: {
              name: cleanDisplayName,
              avatarAsset: chosenAvatar,
              bio: "New Sakhi community member 💜",
            },
            create: {
              name: cleanDisplayName,
              username: candidateUsername,
              avatarAsset: chosenAvatar,
              bio: "New Sakhi community member 💜",
              defaultFollowing: false,
            },
          });
          const existingSub = await tx.eligibilitySubmission.findFirst({
            where: { accountId: session.accountId, status: "PENDING_MANUAL_REVIEW" },
            select: { id: true },
          });
          if (!existingSub) {
            await tx.eligibilitySubmission.create({
              data: {
                accountId: session.accountId,
                status: "PENDING_MANUAL_REVIEW",
                consentVersion: process.env.SAKHI_MANUAL_REVIEW_CONSENT_VERSION?.trim() || "dev-manual-review-v1",
                consentAcceptedAt: new Date(),
              },
            });
          }
        } catch {
          // Keep profile creation resilient if optional dev tables are mocked in unit tests.
        }
      }

      const priorConsent = await tx.memberConsent.findFirst({
        where: {
          accountId: session.accountId,
          termsVersionId: terms.id,
          privacyVersionId: privacy.id,
        },
      });
      if (!priorConsent) {
        await tx.memberConsent.create({
          data: {
            accountId: session.accountId,
            termsVersionId: terms.id,
            privacyVersionId: privacy.id,
            acceptedAt: new Date(),
            source: stagingTestMode
              ? "flutter_staging_test"
              : "flutter_dev_preview",
          },
        });
      }

      await tx.memberCommunicationPreference.upsert({
        where: { accountId: session.accountId },
        create: {
          accountId: session.accountId,
          productUpdatesAccepted: dto.optionalUpdatesAccepted,
        },
        update: { productUpdatesAccepted: dto.optionalUpdatesAccepted },
      });

      await tx.auditEvent.createMany({
        data: {
          actorType: "MEMBER",
          actorId: session.accountId,
          action: "member.profile.saved",
          targetType: "member_account",
          targetId: session.accountId,
          outcome: "success",
          requestId: randomUUID(),
          redactedMetadata: {
            consentDocumentState: "DRAFT",
            optionalUpdatesAccepted: dto.optionalUpdatesAccepted,
          },
        },
      });

      return {
        accountState: stagingTestMode
          ? ("existingAccount" as const)
          : ("pendingVerification" as const),
        testAccess: stagingTestMode,
        message: stagingTestMode
          ? "Staging test profile saved. This test session enables app navigation only; phone ownership and eligibility remain unverified."
          : "Profile and draft-policy acknowledgement saved in the development database. No production account or eligibility decision was created.",
        profile: {
          displayName: profile.displayName,
          dateOfBirth: profile.dateOfBirth.toISOString().slice(0, 10),
          email: profile.email,
        },
      };
    });
  }

  async getCurrentAccount(authorization?: string) {
    const session = await this.authenticateAuthorization(authorization);
    const profile = await this.prisma.memberProfile.findUnique({
      where: { accountId: session.accountId },
    });
    return {
      accountId: session.accountId,
      status: session.account.status,
      verificationStatus: session.account.verificationStatus,
      profile: profile
        ? {
            displayName: profile.displayName,
            dateOfBirth: profile.dateOfBirth.toISOString().slice(0, 10),
            email: profile.email,
          }
        : null,
      testAccess:
        this.isStagingTestModeEnabled() &&
        this.isStagingTestPhoneAllowed(session.account.phoneE164),
      testAccessApproved: session.testAccessApproved === true,
      isDemo: true,
    };
  }

  async logout(authorization?: string) {
    const session = await this.authenticateAuthorization(authorization);
    await this.prisma.authSession.update({
      where: { id: session.id },
      data: { revokedAt: new Date() },
    });
    await this.prisma.auditEvent.createMany({
      data: {
        actorType: "MEMBER",
        actorId: session.accountId,
        action: "auth.session.revoked",
        targetType: "auth_session",
        targetId: session.id,
        outcome: "success",
        requestId: randomUUID(),
        redactedMetadata: { reason: "member_logout" },
      },
    });
    return { status: "signed_out" as const };
  }
}
