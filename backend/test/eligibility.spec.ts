import "reflect-metadata";
import type { INestApplication } from "@nestjs/common";
import { afterEach, describe, expect, it, vi } from "vitest";
import { Test } from "@nestjs/testing";
import request from "supertest";
import { EligibilityController } from "../src/eligibility/eligibility.controller.js";
import { EligibilityService } from "../src/eligibility/eligibility.service.js";
import type { AuthenticationService } from "../src/auth/auth.service.js";
import {
  ELIGIBILITY_STATUS_API_VALUE,
  ELIGIBILITY_VERIFICATION_STATUS,
  canTransitionEligibilityStatus,
} from "../src/eligibility/eligibility-status.js";

describe("eligibility API fail-closed contract", () => {
  let app: INestApplication | undefined;
  const service = {
    configuration: vi.fn(),
    status: vi.fn(),
    start: vi.fn(),
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
    await testApp.init();
    app = testApp;
    return testApp;
  }

  it("reports the provider configuration as unavailable without inferring a decision", async () => {
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
      manualReviewDescription: null,
      consentVersion: null,
      canStartVerification: false,
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
      mode: "development_preview",
    });
  });

  it("routes authenticated status lookups through the service boundary", async () => {
    service.status.mockResolvedValue({
      status: "providerUnavailable",
      eligibilityStatus: "notVerified",
      providerConfigured: false,
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

  it("does not fabricate a verification session when starting is unavailable", async () => {
    const { ConflictException } = await import("@nestjs/common");
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
    expect(service.start).toHaveBeenCalledWith(
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
  ] as const)("returns the persisted state %s without claiming provider availability", async (storedStatus, apiStatus) => {
    const fakeAuth = {
      authenticateAuthorization: vi.fn().mockResolvedValue({
        account: { eligibilityStatus: storedStatus },
      }),
    };
    const realService = new EligibilityService(
      fakeAuth as unknown as AuthenticationService,
    );

    const response = await realService.status("Bearer synthetic-test-token");

    expect(response).toMatchObject({
      status: "providerUnavailable",
      eligibilityStatus: apiStatus,
      providerConfigured: false,
      isDemo: true,
    });
    expect(fakeAuth.authenticateAuthorization).toHaveBeenCalledWith(
      "Bearer synthetic-test-token",
    );
    expect(ELIGIBILITY_STATUS_API_VALUE[storedStatus]).toBe(apiStatus);
  });

  it("keeps provider startup fail-closed and does not change the stored state", async () => {
    const account = {
      eligibilityStatus: ELIGIBILITY_VERIFICATION_STATUS.NOT_VERIFIED,
    };
    const fakeAuth = {
      authenticateAuthorization: vi.fn().mockResolvedValue({ account }),
    };
    const realService = new EligibilityService(
      fakeAuth as unknown as AuthenticationService,
    );

    await expect(
      realService.start("Bearer synthetic-test-token"),
    ).rejects.toThrow(ConflictException);
    expect(account.eligibilityStatus).toBe("NOT_VERIFIED");
    expect(fakeAuth.authenticateAuthorization).toHaveBeenCalledOnce();
  });

  it("allows only explicitly defined status transitions and trusted authorities", () => {
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
        status.VERIFIED,
        status.NOT_VERIFIED,
        "REVIEWER",
      ),
    ).toBe(false);
  });
});
