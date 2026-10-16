import "reflect-metadata";
import {
  BadRequestException,
  ConflictException,
  type INestApplication,
  HttpException,
  ServiceUnavailableException,
  UnauthorizedException,
} from "@nestjs/common";
import { afterEach, describe, expect, it, vi } from "vitest";
import { Test } from "@nestjs/testing";
import request from "supertest";
import { EligibilityController } from "../src/eligibility/eligibility.controller.js";
import { EligibilityService } from "../src/eligibility/eligibility.service.js";
import type { AuthenticationService } from "../src/auth/auth.service.js";
import { PrismaService } from "../src/database/prisma.service.js";
import { createGlobalValidationPipe } from "../src/common/validation/create-validation-pipe.js";
import {
  ELIGIBILITY_STATUS_API_VALUE,
  ELIGIBILITY_VERIFICATION_STATUS,
  canTransitionEligibilityStatus,
} from "../src/eligibility/eligibility-status.js";
import type {
  EligibilityProviderAdapter,
  EligibilityProviderConfiguration,
  NormalizedEligibilityProviderCallback,
} from "../src/eligibility/eligibility-provider.js";

const providerUnavailableConfiguration: EligibilityProviderConfiguration = {
  providerConfigured: false,
  policyApproved: false,
  providerKey: null,
  redirectHosts: [],
  providerDisplayName: null,
  methodDescription: null,
  attributesCheckedDescription: null,
  biometricProcessingSupported: false,
  biometricProcessingRequired: false,
  dataHandlingDescription: null,
  retentionAndDeletionDescription: null,
  declineOrFailureDescription: null,
  manualReviewDescription: "Review decisions are not enabled.",
  consentVersion: null,
};

function providerStub(
  configuration: EligibilityProviderConfiguration = providerUnavailableConfiguration,
  startSession = vi.fn(),
  verifyAndNormalizeCallback = vi
    .fn()
    .mockRejectedValue(
      new ServiceUnavailableException("No callback verifier configured in test adapter."),
    ),
): EligibilityProviderAdapter {
  return {
    configuration: () => configuration,
    startSession,
    verifyAndNormalizeCallback,
  };
}

describe("eligibility API fail-closed contract", () => {
  let app: INestApplication | undefined;
  const service = {
    configuration: vi.fn(),
    status: vi.fn(),
    start: vi.fn(),
    processProviderCallback: vi.fn(),
    createSupportRequest: vi.fn(),
    listSupportRequests: vi.fn(),
  };

  afterEach(async () => {
    if (app) {
      await app.close();
      app = undefined;
    }
    vi.resetAllMocks();
  });

  async function createApp() {
    Reflect.defineMetadata(
      "design:paramtypes",
      [EligibilityService],
      EligibilityController,
    );
    const module = await Test.createTestingModule({
      controllers: [EligibilityController],
      providers: [{ provide: EligibilityService, useValue: service }],
    }).compile();
    const testApp = module.createNestApplication();
    testApp.setGlobalPrefix("api/v1");
    testApp.useGlobalPipes(createGlobalValidationPipe());
    await testApp.init();
    app = testApp;
    return testApp;
  }

  it("reports provider and policy as unconfigured", async () => {
    service.configuration.mockReturnValue({
      providerConfigured: false,
      policyApproved: false,
      providerDisplayName: null,
      methodDescription: null,
      attributesCheckedDescription: null,
      selfieOrLivenessDescription: null,
      dataHandlingDescription: null,
      retentionAndDeletionDescription: null,
      declineOrFailureDescription: null,
      manualReviewDescription: "Review decisions are not enabled.",
      consentVersion: null,
      canStartVerification: false,
      supportRequestsAvailable: true,
      reviewDecisionsEnabled: false,
      rawIdentityDataCollectedBySakhi: false,
      mode: "development_preview",
    });
    const app = await createApp();
    const response = await request(app.getHttpServer())
      .get("/api/v1/eligibility/configuration")
      .expect(200);

    expect(response.body).toMatchObject({
      providerConfigured: false,
      policyApproved: false,
      canStartVerification: false,
      supportRequestsAvailable: true,
      reviewDecisionsEnabled: false,
      rawIdentityDataCollectedBySakhi: false,
    });
  });

  it("routes authenticated status lookups through the service boundary", async () => {
    service.status.mockResolvedValue({
      status: "providerUnavailable",
      eligibilityStatus: "notVerified",
      providerConfigured: false,
      canStartVerification: false,
      supportRequestsAvailable: true,
      message: "No approved provider is configured.",
      isDemo: true,
    });
    const app = await createApp();
    const response = await request(app.getHttpServer())
      .get("/api/v1/eligibility/status")
      .set("Authorization", "Bearer a-valid-looking-test-token")
      .expect(200);

    expect(response.body.status).toBe("providerUnavailable");
    expect(response.body.eligibilityStatus).toBe("notVerified");
    expect(response.body.providerConfigured).toBe(false);
    expect(service.status).toHaveBeenCalledWith(
      "Bearer a-valid-looking-test-token",
    );
  });

  it("preserves the provider-unavailable start response for the existing no-body client", async () => {
    service.start.mockRejectedValue(
      new ConflictException({
        statusCode: 409,
        code: "eligibility_provider_unavailable",
        status: "providerUnavailable",
        message: "No verification session was created.",
        isDemo: true,
      }),
    );
    const app = await createApp();
    const response = await request(app.getHttpServer())
      .post("/api/v1/eligibility/start")
      .set("Authorization", "Bearer a-valid-looking-test-token")
      .expect(409);

    expect(response.body.code).toBe("eligibility_provider_unavailable");
    expect(service.start).toHaveBeenCalled();
    expect(service.start.mock.calls[0]?.[0]).toBe(
      "Bearer a-valid-looking-test-token",
    );
  });

  it("routes provider callbacks through the adapter-backed service boundary", async () => {
    service.processProviderCallback.mockResolvedValue({
      accepted: true,
      duplicate: false,
    });
    const app = await createApp();
    const response = await request(app.getHttpServer())
      .post("/api/v1/eligibility/provider-callback")
      .set("x-synthetic-signature", "signature-fixture")
      .send({ result: "not trusted by the route" })
      .expect(202);

    expect(response.body).toEqual({ accepted: true, duplicate: false });
    expect(service.processProviderCallback).toHaveBeenCalledWith(
      undefined,
      expect.objectContaining({
        "x-synthetic-signature": "signature-fixture",
      }),
    );
  });

  it("validates support-request category and never accepts free-text identity evidence", async () => {
    service.createSupportRequest.mockResolvedValue({
      requestId: "support-1",
      category: "manualReviewRequest",
      status: "open",
      isDemo: true,
    });
    const app = await createApp();

    await request(app.getHttpServer())
      .post("/api/v1/eligibility/support-requests")
      .set("Authorization", "Bearer a-valid-looking-test-token")
      .send({ category: "arbitrary" })
      .expect(400);

    await request(app.getHttpServer())
      .post("/api/v1/eligibility/support-requests")
      .set("Authorization", "Bearer a-valid-looking-test-token")
      .send({ category: "manualReviewRequest", identityDocument: "not-a-real-document" })
      .expect(400);

    const response = await request(app.getHttpServer())
      .post("/api/v1/eligibility/support-requests")
      .set("Authorization", "Bearer a-valid-looking-test-token")
      .send({ category: "manualReviewRequest" })
      .expect(201);

    expect(response.body.category).toBe("manualReviewRequest");
    expect(service.createSupportRequest).toHaveBeenCalledWith(
      "Bearer a-valid-looking-test-token",
      { category: "manualReviewRequest" },
    );
  });

  it("lists only through the authenticated service boundary", async () => {
    service.listSupportRequests.mockResolvedValue({ requests: [], isDemo: true });
    const app = await createApp();
    await request(app.getHttpServer())
      .get("/api/v1/eligibility/support-requests")
      .set("Authorization", "Bearer a-valid-looking-test-token")
      .expect(200);
    expect(service.listSupportRequests).toHaveBeenCalledWith(
      "Bearer a-valid-looking-test-token",
    );
  });
});

describe("canonical eligibility state", () => {
  it.each([
    ["NOT_VERIFIED", "notVerified"],
    ["VERIFICATION_IN_PROGRESS", "verificationInProgress"],
    ["PENDING_MANUAL_REVIEW", "pendingManualReview"],
    ["VERIFIED", "verified"],
    ["VERIFICATION_FAILED", "verificationFailed"],
    ["TEMPORARILY_RESTRICTED", "temporarilyRestricted"],
    ["REVERIFICATION_REQUIRED", "reverificationRequired"],
  ] as const)(
    "returns the persisted state %s without claiming provider availability",
    async (storedStatus, apiStatus) => {
      const fakeAuth = {
        authenticateAuthorization: vi.fn().mockResolvedValue({
          accountId: "account-id",
          account: { eligibilityStatus: storedStatus },
        }),
      };
      const realService = new EligibilityService(
        fakeAuth as unknown as AuthenticationService,
        {} as PrismaService,
        providerStub(),
      );

      const response = await realService.status("Bearer synthetic-test-token");

      expect(response).toMatchObject({
        status: "providerUnavailable",
        eligibilityStatus: apiStatus,
        providerConfigured: false,
        supportRequestsAvailable: true,
        isDemo: true,
      });
      expect(fakeAuth.authenticateAuthorization).toHaveBeenCalledWith(
        "Bearer synthetic-test-token",
      );
      expect(ELIGIBILITY_STATUS_API_VALUE[storedStatus]).toBe(apiStatus);
    },
  );

  it("does not create a session or consent when the provider is unconfigured", async () => {
    const fakeAuth = {
      authenticateAuthorization: vi.fn().mockResolvedValue({
        accountId: "account-id",
        account: {
          eligibilityStatus: ELIGIBILITY_VERIFICATION_STATUS.NOT_VERIFIED,
        },
      }),
    };
    const startSession = vi.fn();
    const fakePrisma = {
      $transaction: vi.fn(),
    } as unknown as PrismaService;
    const realService = new EligibilityService(
      fakeAuth as unknown as AuthenticationService,
      fakePrisma,
      providerStub(providerUnavailableConfiguration, startSession),
    );

    await expect(
      realService.start("Bearer synthetic-test-token"),
    ).rejects.toThrow(ConflictException);
    expect(startSession).not.toHaveBeenCalled();
    expect(fakePrisma.$transaction).not.toHaveBeenCalled();
  });

  it("requires explicit accepted notice/version before calling an enabled provider", async () => {
    const fakeAuth = {
      authenticateAuthorization: vi.fn().mockResolvedValue({
        accountId: "account-id",
        account: {
          eligibilityStatus: ELIGIBILITY_VERIFICATION_STATUS.NOT_VERIFIED,
        },
      }),
    };
    const config = {
      ...providerUnavailableConfiguration,
      providerConfigured: true,
      policyApproved: true,
      providerKey: "synthetic-provider",
      redirectHosts: ["verify.example.test"],
      providerDisplayName: "Synthetic Test Provider",
      consentVersion: "notice-v1",
    };
    const startSession = vi.fn();
    const realService = new EligibilityService(
      fakeAuth as unknown as AuthenticationService,
      {} as PrismaService,
      providerStub(config, startSession),
    );

    await expect(
      realService.start("Bearer synthetic-test-token", {
        consentAccepted: false,
        consentVersion: "notice-v1",
        biometricProcessingConsented: false,
      }),
    ).rejects.toThrow(BadRequestException);
    expect(startSession).not.toHaveBeenCalled();
  });

  it("allows the provider-neutral flow to return a hosted HTTPS session only after consent", async () => {
    const accountId = "account-id";
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000);
    const fakeAuth = {
      authenticateAuthorization: vi.fn().mockResolvedValue({
        accountId,
        account: {
          eligibilityStatus: ELIGIBILITY_VERIFICATION_STATUS.NOT_VERIFIED,
        },
      }),
    };
    const tx = {
      eligibilityConsent: {
        create: vi.fn().mockResolvedValue({ id: "consent-id" }),
      },
      eligibilityVerificationSession: {
        create: vi.fn().mockResolvedValue({ id: "session-id" }),
        update: vi.fn().mockResolvedValue({ id: "session-id" }),
      },
      memberAccount: {
        updateMany: vi.fn().mockResolvedValue({ count: 1 }),
      },
      auditEvent: {
        create: vi.fn().mockResolvedValue({ id: "audit-id" }),
      },
    };
    const fakePrisma = {
      memberProfile: {
        findUnique: vi.fn().mockResolvedValue({ accountId }),
      },
      eligibilityVerificationSession: {
        findFirst: vi.fn().mockResolvedValue(null),
      },
      $transaction: vi.fn(async (callback: (value: unknown) => Promise<unknown>) =>
        callback(tx),
      ),
    } as unknown as PrismaService;
    const providerSession = {
      providerReference: "synthetic-provider-reference",
      redirectUrl: "https://verify.example.test/session/opaque",
      expiresAt,
    };
    const startSession = vi.fn().mockResolvedValue(providerSession);
    const config: EligibilityProviderConfiguration = {
      ...providerUnavailableConfiguration,
      providerConfigured: true,
      policyApproved: true,
      providerKey: "synthetic-provider",
      redirectHosts: ["verify.example.test"],
      providerDisplayName: "Synthetic Test Provider",
      methodDescription: "Synthetic provider fixture for unit testing.",
      attributesCheckedDescription: "No real attributes; synthetic fixture only.",
      consentVersion: "notice-v1",
    };
    const realService = new EligibilityService(
      fakeAuth as unknown as AuthenticationService,
      fakePrisma,
      providerStub(config, startSession),
    );

    const response = await realService.start("Bearer synthetic-test-token", {
      consentAccepted: true,
      consentVersion: "notice-v1",
      biometricProcessingConsented: false,
    });

    expect(response).toMatchObject({
      status: "verificationInProgress",
      eligibilityStatus: "verificationInProgress",
      redirectUrl: providerSession.redirectUrl,
      providerConfigured: true,
      isDemo: false,
    });
    expect(tx.eligibilityConsent.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          accountId,
          noticeVersion: "notice-v1",
          biometricProcessingConsented: false,
        }),
        select: { id: true },
      }),
    );
    expect(tx.memberAccount.updateMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: {
          id: accountId,
          eligibilityStatus: "NOT_VERIFIED",
        },
        data: { eligibilityStatus: "VERIFICATION_IN_PROGRESS" },
      }),
    );
    expect(tx.auditEvent.create).toHaveBeenCalled();
  });

  it("requires a reviewer or trusted provider for sensitive status transitions", () => {
    const status = ELIGIBILITY_VERIFICATION_STATUS;

    expect(
      canTransitionEligibilityStatus(
        status.NOT_VERIFIED,
        status.VERIFICATION_IN_PROGRESS,
        "SYSTEM",
      ),
    ).toBe(true);
    expect(
      canTransitionEligibilityStatus(
        status.VERIFICATION_IN_PROGRESS,
        status.VERIFIED,
        "SYSTEM",
      ),
    ).toBe(false);
    expect(
      canTransitionEligibilityStatus(
        status.VERIFICATION_IN_PROGRESS,
        status.VERIFIED,
        "PROVIDER",
      ),
    ).toBe(true);
    expect(
      canTransitionEligibilityStatus(
        status.PENDING_MANUAL_REVIEW,
        status.VERIFIED,
        "PROVIDER",
      ),
    ).toBe(false);
    expect(
      canTransitionEligibilityStatus(
        status.PENDING_MANUAL_REVIEW,
        status.VERIFIED,
        "REVIEWER",
      ),
    ).toBe(true);
    expect(
      canTransitionEligibilityStatus(
        status.VERIFICATION_IN_PROGRESS,
        status.NOT_VERIFIED,
        "SYSTEM",
      ),
    ).toBe(true);
    expect(
      canTransitionEligibilityStatus(
        status.VERIFIED,
        status.NOT_VERIFIED,
        "REVIEWER",
      ),
    ).toBe(false);
  });
});

describe("eligibility support request persistence", () => {
  it("stores category-only requests under the authenticated account and audits creation", async () => {
    const accountId = "account-id";
    const createdAt = new Date("2026-10-16T08:00:00.000Z");
    const tx = {
      eligibilitySupportRequest: {
        create: vi.fn().mockImplementation(
          (input: {
            data: { id: string; category: string; status: string };
          }) =>
            Promise.resolve({
              id: input.data.id,
              category: input.data.category,
              status: input.data.status,
              createdAt,
            }),
        ),
      },
      auditEvent: {
        create: vi.fn().mockResolvedValue({ id: "audit-id" }),
      },
    };
    const fakePrisma = {
      eligibilitySupportRequest: {
        count: vi.fn().mockResolvedValue(0),
      },
      $transaction: vi.fn(async (callback: (value: unknown) => Promise<unknown>) =>
        callback(tx),
      ),
    } as unknown as PrismaService;
    const fakeAuth = {
      authenticateAuthorization: vi.fn().mockResolvedValue({
        accountId,
        account: { eligibilityStatus: "NOT_VERIFIED" },
      }),
    };
    const realService = new EligibilityService(
      fakeAuth as unknown as AuthenticationService,
      fakePrisma,
      providerStub(),
    );

    const result = await realService.createSupportRequest(
      "Bearer synthetic-test-token",
      { category: "manualReviewRequest" },
    );

    expect(result).toMatchObject({
      requestId: expect.any(String),
      category: "manualReviewRequest",
      status: "open",
      eligibilityStatus: "notVerified",
      isDemo: true,
    });
    expect(tx.eligibilitySupportRequest.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: {
          id: expect.any(String),
          accountId,
          category: "MANUAL_REVIEW_REQUEST",
          status: "OPEN",
        },
        select: {
          id: true,
          category: true,
          status: true,
          createdAt: true,
        },
      }),
    );
    expect(tx.auditEvent.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          action: "eligibility.support_request.created",
          targetId: result.requestId,
          requestId: result.requestId,
          redactedMetadata: { category: "MANUAL_REVIEW_REQUEST" },
        }),
        select: { id: true },
      }),
    );
  });

  it("rate-limits support requests per authenticated account", async () => {
    const tx = {
      eligibilitySupportRequest: {
        create: vi.fn(),
      },
      auditEvent: {
        create: vi.fn(),
      },
    };
    const fakePrisma = {
      eligibilitySupportRequest: {
        count: vi.fn().mockResolvedValue(5),
      },
      $transaction: vi.fn(async (callback: (value: unknown) => Promise<unknown>) =>
        callback(tx),
      ),
    } as unknown as PrismaService;
    const fakeAuth = {
      authenticateAuthorization: vi.fn().mockResolvedValue({
        accountId: "account-id",
        account: { eligibilityStatus: "NOT_VERIFIED" },
      }),
    };
    const realService = new EligibilityService(
      fakeAuth as unknown as AuthenticationService,
      fakePrisma,
      providerStub(),
    );

    await expect(
      realService.createSupportRequest("Bearer synthetic-test-token", {
        category: "verificationHelp",
      }),
    ).rejects.toThrow(HttpException);
    expect(tx.eligibilitySupportRequest.create).not.toHaveBeenCalled();
  });
});


describe("eligibility provider callback processing", () => {
  const configured = {
    ...providerUnavailableConfiguration,
    providerConfigured: true,
    policyApproved: true,
    providerKey: "synthetic-provider",
    redirectHosts: ["verify.example.test"],
    providerDisplayName: "Synthetic Test Provider",
    consentVersion: "notice-v1",
  } satisfies EligibilityProviderConfiguration;

  const rawBody = Buffer.from('{"synthetic":"signed-fixture"}');
  const headers = { "x-synthetic-signature": "valid-fixture" };
  const verifiedEvent: NormalizedEligibilityProviderCallback = {
    eventId: "synthetic-event-001",
    providerReference: "synthetic-provider-reference",
    outcome: "VERIFIED",
  };

  function fakeTransaction(sessionOverrides: Record<string, unknown> = {}) {
    const tx = {
      eligibilityProviderCallbackEvent: {
        findUnique: vi.fn().mockResolvedValue(null),
        createMany: vi.fn().mockResolvedValue({ count: 1 }),
      },
      eligibilityVerificationSession: {
        findUnique: vi.fn().mockResolvedValue({
          id: "local-session-id",
          accountId: "account-id",
          status: "REDIRECT_READY",
          expiresAt: new Date(Date.now() + 60_000),
          account: {
            eligibilityStatus: ELIGIBILITY_VERIFICATION_STATUS.VERIFICATION_IN_PROGRESS,
          },
          ...sessionOverrides,
        }),
        updateMany: vi.fn().mockResolvedValue({ count: 1 }),
      },
      memberAccount: {
        updateMany: vi.fn().mockResolvedValue({ count: 1 }),
      },
      auditEvent: {
        create: vi.fn().mockResolvedValue({ id: "audit-id" }),
      },
    };
    const prisma = {
      $transaction: vi.fn(async (callback: (value: unknown) => Promise<unknown>) =>
        callback(tx),
      ),
    } as unknown as PrismaService;
    return { tx, prisma };
  }

  it("fails closed while the provider is unconfigured", async () => {
    const verifier = vi.fn();
    const prisma = { $transaction: vi.fn() } as unknown as PrismaService;
    const service = new EligibilityService(
      {} as AuthenticationService,
      prisma,
      providerStub(providerUnavailableConfiguration, vi.fn(), verifier),
    );

    await expect(service.processProviderCallback(rawBody, headers)).rejects.toThrow(
      ServiceUnavailableException,
    );
    expect(verifier).not.toHaveBeenCalled();
    expect(prisma.$transaction).not.toHaveBeenCalled();
  });

  it("does not touch persistence when provider signature verification fails", async () => {
    const verifier = vi.fn().mockRejectedValue(
      new UnauthorizedException("Synthetic signature rejected."),
    );
    const { prisma } = fakeTransaction();
    const service = new EligibilityService(
      {} as AuthenticationService,
      prisma,
      providerStub(configured, vi.fn(), verifier),
    );

    await expect(service.processProviderCallback(rawBody, headers)).rejects.toThrow(
      UnauthorizedException,
    );
    expect(verifier).toHaveBeenCalledWith({ rawBody, headers });
    expect(prisma.$transaction).not.toHaveBeenCalled();
  });

  it("atomically maps a trusted synthetic result and records only redacted audit metadata", async () => {
    const verifier = vi.fn().mockResolvedValue(verifiedEvent);
    const { tx, prisma } = fakeTransaction();
    const service = new EligibilityService(
      {} as AuthenticationService,
      prisma,
      providerStub(configured, vi.fn(), verifier),
    );

    await expect(
      service.processProviderCallback(rawBody, headers),
    ).resolves.toEqual({ accepted: true, duplicate: false });

    expect(tx.eligibilityProviderCallbackEvent.createMany).toHaveBeenCalledWith({
      data: [
        {
          id: expect.any(String),
          providerKey: "synthetic-provider",
          providerEventId: "synthetic-event-001",
          sessionId: "local-session-id",
          outcome: "VERIFIED",
        },
      ],
      skipDuplicates: true,
    });
    expect(tx.memberAccount.updateMany).toHaveBeenCalledWith({
      where: {
        id: "account-id",
        eligibilityStatus: "VERIFICATION_IN_PROGRESS",
      },
      data: { eligibilityStatus: "VERIFIED" },
    });
    expect(tx.eligibilityVerificationSession.updateMany).toHaveBeenCalledWith({
      where: {
        id: "local-session-id",
        status: "REDIRECT_READY",
        expiresAt: { gt: expect.any(Date) },
      },
      data: {
        status: "COMPLETED",
        completedAt: expect.any(Date),
      },
    });
    expect(tx.auditEvent.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          actorType: "PROVIDER",
          action: "eligibility.provider_result.applied",
          targetId: "local-session-id",
          redactedMetadata: {
            providerKey: "synthetic-provider",
            providerOutcome: "VERIFIED",
            from: "VERIFICATION_IN_PROGRESS",
            to: "VERIFIED",
          },
        }),
      }),
    );
  });

  it("acknowledges duplicate events without applying the result twice", async () => {
    const verifier = vi.fn().mockResolvedValue(verifiedEvent);
    const { tx, prisma } = fakeTransaction();
    tx.eligibilityProviderCallbackEvent.findUnique.mockResolvedValue({ id: "existing-event" });
    const service = new EligibilityService(
      {} as AuthenticationService,
      prisma,
      providerStub(configured, vi.fn(), verifier),
    );

    await expect(
      service.processProviderCallback(rawBody, headers),
    ).resolves.toEqual({ accepted: true, duplicate: true });
    expect(tx.eligibilityProviderCallbackEvent.createMany).not.toHaveBeenCalled();
    expect(tx.memberAccount.updateMany).not.toHaveBeenCalled();
    expect(tx.eligibilityVerificationSession.updateMany).not.toHaveBeenCalled();
  });

  it("rejects a callback whose provider session has expired", async () => {
    const verifier = vi.fn().mockResolvedValue(verifiedEvent);
    const { tx, prisma } = fakeTransaction({
      expiresAt: new Date(Date.now() - 1_000),
    });
    const service = new EligibilityService(
      {} as AuthenticationService,
      prisma,
      providerStub(configured, vi.fn(), verifier),
    );

    await expect(service.processProviderCallback(rawBody, headers)).rejects.toThrow(
      ConflictException,
    );
    expect(tx.eligibilityProviderCallbackEvent.createMany).not.toHaveBeenCalled();
    expect(tx.memberAccount.updateMany).not.toHaveBeenCalled();
  });
});
