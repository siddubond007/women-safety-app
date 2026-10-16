import {
  BadRequestException,
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

  private assertDevelopmentOtpEnabled(): void {
    const localEnvironment =
      process.env.SAKHI_ENV === "dev" || process.env.SAKHI_ENV === "test";
    if (
      process.env.NODE_ENV === "production" ||
      !localEnvironment ||
      process.env.SAKHI_OTP_MODE !== "development" ||
      (process.env.HOST ?? "127.0.0.1") !== "127.0.0.1"
    ) {
      throw new ServiceUnavailableException(
        "OTP delivery is not configured. No SMS was sent.",
      );
    }
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
    },
  ): Promise<{
    challengeId: string;
    expiresAt: string;
    resendAvailableAt: string;
    developmentCode: string;
  }> {
    const now = new Date();
    const id = randomUUID();
    const code = this.newOtp();
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

    // The runtime role may insert audit records but must not read the
    // audit log. Returning only the generated ID keeps its SELECT privilege
    // limited to the ID column.
    await tx.auditEvent.create({
      data: {
        actorType: "SYSTEM",
        action: "auth.otp.requested",
        targetType: "otp_challenge",
        targetId: id,
        outcome: "created",
        requestId: id,
        redactedMetadata: {
          purpose: args.purpose.toLowerCase(),
          deliveryMode: "development_echo",
        },
      },
      select: { id: true },
    });

    // This code is deliberately echoed only by the explicit local dev/test
    // provider. This service refuses to start in production mode.
    return {
      challengeId: id,
      expiresAt: expiresAt.toISOString(),
      resendAvailableAt: resendAvailableAt.toISOString(),
      developmentCode: code,
    };
  }

  async requestOtp(dto: RequestOtpDto) {
    this.assertDevelopmentOtpEnabled();
    const phoneE164 = this.phoneE164(dto.countryCode, dto.phoneNumber);
    const now = new Date();
    const windowStart = new Date(now.getTime() - OTP_WINDOW_MS);

    return this.prisma.$transaction(async (tx) => {
      const requestCount = await tx.otpChallenge.count({
        where: { phoneE164, createdAt: { gte: windowStart } },
      });
      this.assertOtpWindow(requestCount);

      const account = await tx.memberAccount.findUnique({
        where: { phoneE164 },
        select: { id: true },
      });

      const result = await this.createChallenge(tx, {
        phoneE164,
        purpose: dto.purpose === "login" ? "LOGIN" : "REGISTRATION",
        accountId: account?.id ?? null,
      });

      return {
        ...result,
        deliveryMode: "development_echo" as const,
        isDemo: true,
        message:
          "Development code only. No SMS was sent and the phone number has not been verified by a carrier.",
      };
    });
  }

  async resendOtp(challengeId: string) {
    this.assertDevelopmentOtpEnabled();
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
      });
      return {
        ...result,
        deliveryMode: "development_echo" as const,
        isDemo: true,
        message: "New development code generated. No SMS was sent.",
      };
    });
  }

  private accountState(status: string): AccountState {
    if (status === "ACTIVE") return "existingAccount";
    if (status === "PENDING_VERIFICATION") return "pendingVerification";
    return "restricted";
  }

  async verifyOtp(dto: VerifyOtpDto) {
    this.assertDevelopmentOtpEnabled();
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

      await tx.otpChallenge.update({
        where: { id: challenge.id },
        data: { consumedAt: now },
      });

      let account = await tx.memberAccount.findUnique({
        where: { phoneE164: challenge.phoneE164 },
      });

      if (challenge.purpose === "LOGIN" && !account) {
        return {
          status: "invalid" as const,
          message:
            "This number could not be signed in. Check it and try again.",
        };
      }

      if (!account && challenge.purpose === "REGISTRATION") {
        account = await tx.memberAccount.create({
          data: {
            phoneE164: challenge.phoneE164,
            phoneVerifiedAt: now,
            status: "PENDING_VERIFICATION",
            verificationStatus: "UNVERIFIED",
          },
        });
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

      await tx.memberAccount.update({
        where: { id: account.id },
        data: { phoneVerifiedAt: now },
      });

      const token = randomBytes(32).toString("base64url");
      const expiresAt = new Date(now.getTime() + SESSION_TTL_MS);
      await tx.authSession.create({
        data: {
          accountId: account.id,
          tokenDigest: this.digestToken(token),
          expiresAt,
        },
      });

      const profile = await tx.memberProfile.findUnique({
        where: { accountId: account.id },
        select: { accountId: true },
      });
      // An OTP-verified account without a profile must be allowed to resume
      // registration even if the user returns through the login route.
      const state: AccountState = !profile
        ? "newAccount"
        : this.accountState(account.status);

      await tx.auditEvent.create({
        data: {
          actorType: "MEMBER",
          actorId: account.id,
          action: "auth.otp.verified",
          targetType: "member_account",
          targetId: account.id,
          outcome: "success",
          requestId: challenge.id,
          redactedMetadata: { purpose: challenge.purpose.toLowerCase() },
        },
      });

      return {
        status: "verified" as const,
        accountState: state,
        accessToken: token,
        tokenType: "Bearer" as const,
        expiresAt: expiresAt.toISOString(),
        isDemo: true,
        message:
          "Development authentication only. This session is local test access, not production identity verification.",
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
    return session;
  }

  async createProfile(
    authorization: string | undefined,
    dto: CreateProfileDto,
  ) {
    const session = await this.authenticateAuthorization(authorization);
    const configuredAge = process.env.SAKHI_PREVIEW_MINIMUM_AGE_YEARS;
    if (
      process.env.NODE_ENV === "production" ||
      (process.env.SAKHI_ENV !== "dev" && process.env.SAKHI_ENV !== "test") ||
      configuredAge !== "13"
    ) {
      throw new ServiceUnavailableException(
        "The development registration-age policy is not configured. No profile was saved.",
      );
    }

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
      age < 13 ||
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
        "The profile does not meet the temporary development age rule.",
      );
    }
    if (Number.isNaN(acceptedAt.getTime()) || acceptedAt > new Date()) {
      throw new BadRequestException(
        "The draft policy acknowledgement time is invalid.",
      );
    }

    return this.prisma.$transaction(async (tx) => {
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

      const profile = await tx.memberProfile.upsert({
        where: { accountId: session.accountId },
        create: {
          accountId: session.accountId,
          displayName: dto.displayName.trim(),
          dateOfBirth: dob,
          email: dto.email?.trim().toLowerCase() || null,
        },
        update: {
          displayName: dto.displayName.trim(),
          dateOfBirth: dob,
          email: dto.email?.trim().toLowerCase() || null,
        },
      });

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
            // Record server receipt time; never trust a client clock for the
            // persisted policy-acknowledgement timestamp.
            acceptedAt: new Date(),
            source: "flutter_dev_preview",
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

      await tx.auditEvent.create({
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
        select: { id: true },
      });

      return {
        accountState: "pendingVerification" as const,
        message:
          "Profile and draft-policy acknowledgement saved in the development database. No production account or eligibility decision was created.",
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
      isDemo: true,
    };
  }

  async logout(authorization?: string) {
    const session = await this.authenticateAuthorization(authorization);
    await this.prisma.authSession.update({
      where: { id: session.id },
      data: { revokedAt: new Date() },
    });
    await this.prisma.auditEvent.create({
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
      select: { id: true },
    });
    return { status: "signed_out" as const };
  }
}
