import "reflect-metadata";
import type { INestApplication } from "@nestjs/common";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { Test } from "@nestjs/testing";
import request from "supertest";
import { EligibilityController } from "../src/eligibility/eligibility.controller.js";
import { EligibilityService } from "../src/eligibility/eligibility.service.js";
import { DecentroKycService } from "../src/eligibility/decentro-kyc.service.js";

describe("eligibility API fail-closed contract", () => {
  let app: INestApplication | undefined;
  const service = {
    configuration: vi.fn(),
    status: vi.fn(),
    start: vi.fn(),
  };
  const decentro = {
    configuration: vi.fn(),
    status: vi.fn(),
    initiate: vi.fn(),
    simulateLocalResult: vi.fn(),
    completeBrowserCallback: vi.fn(),
    handleSignedCallback: vi.fn(),
  };

  beforeEach(() => {
    decentro.configuration.mockReturnValue({
      providerConfigured: false,
      providerDisplayName: null,
      policyApproved: false,
      canStartVerification: false,
      localSimulatorEnabled: false,
      mode: "development_preview",
    });
    decentro.completeBrowserCallback.mockResolvedValue({
      status: "already_processed",
      eligibilityStatus: "VERIFIED",
      isDemo: false,
    });
  });

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
      [EligibilityService, DecentroKycService],
      EligibilityController,
    );
    const module = await Test.createTestingModule({
      controllers: [EligibilityController],
      providers: [
        { provide: EligibilityService, useValue: service },
        { provide: DecentroKycService, useValue: decentro },
      ],
    }).compile();
    const testApp = module.createNestApplication();
    testApp.setGlobalPrefix("api/v1");
    await testApp.init();
    app = testApp;
    return testApp;
  }

  it("reports provider configuration as unavailable without inferring a decision", async () => {
    service.configuration.mockReturnValue({
      providerConfigured: false,
      policyApproved: false,
      manualReviewEnabled: false,
      canStartVerification: false,
      mode: "development_preview",
    });
    const testApp = await createApp();
    const response = await request(testApp.getHttpServer())
      .get("/api/v1/eligibility/configuration")
      .expect(200);

    expect(response.body).toMatchObject({
      providerConfigured: false,
      policyApproved: false,
      manualReviewEnabled: false,
      canStartVerification: false,
      mode: "development_preview",
    });
  }, 30_000);

  it("routes authenticated status lookups through the service boundary", async () => {
    service.status.mockResolvedValue({
      status: "providerUnavailable",
      eligibilityStatus: "UNVERIFIED",
      message: "No provider or manual-review policy is configured.",
      isDemo: true,
    });
    const testApp = await createApp();
    const response = await request(testApp.getHttpServer())
      .get("/api/v1/eligibility/status")
      .set("Authorization", "Bearer a-valid-looking-test-token")
      .expect(200);

    expect(response.body.eligibilityStatus).toBe("UNVERIFIED");
    expect(service.status).toHaveBeenCalledWith(
      "Bearer a-valid-looking-test-token",
    );
  });

  it("does not create a manual request when configuration is unavailable", async () => {
    const { ServiceUnavailableException } = await import("@nestjs/common");
    service.start.mockRejectedValue(
      new ServiceUnavailableException({
        statusCode: 503,
        code: "manual_review_not_configured",
        message: "No approved manual-review policy is configured.",
        isDemo: true,
      }),
    );
    const testApp = await createApp();
    const response = await request(testApp.getHttpServer())
      .post("/api/v1/eligibility/start")
      .set("Authorization", "Bearer a-valid-looking-test-token")
      .send({
        consentAccepted: true,
        consentVersion: "test-version",
        biometricProcessingConsented: false,
      })
      .expect(503);

    expect(response.body.code).toBe("manual_review_not_configured");
    expect(service.start).toHaveBeenCalledWith(
      "Bearer a-valid-looking-test-token",
      {
        consentAccepted: true,
        consentVersion: "test-version",
        biometricProcessingConsented: false,
      },
    );
  });

  it("does not expose a client-callable demographic verify-result endpoint", async () => {
    const testApp = await createApp();
    await request(testApp.getHttpServer())
      .post("/api/v1/eligibility/decentro/verify-result")
      .send({ gender: "F", dob: "1999-05-15" })
      .expect(404);
    await request(testApp.getHttpServer())
      .post("/api/v1/verification/verify-result")
      .send({ gender: "F", dob: "1999-05-15" })
      .expect(404);
    expect(decentro.completeBrowserCallback).not.toHaveBeenCalled();
  });

  it("browser callback uses only the Sakhi reference and ignores supplied demographics", async () => {
    const testApp = await createApp();
    const referenceId = "42d43dd8-7f49-41e5-9b1f-e7f26b9ec706";
    await request(testApp.getHttpServer())
      .get("/api/v1/eligibility/decentro/callback")
      .query({
        referenceId,
        gender: "F",
        dob: "1999-05-15",
        accountId: "caller-controlled",
      })
      .expect(200);

    expect(decentro.completeBrowserCallback).toHaveBeenCalledTimes(1);
    expect(decentro.completeBrowserCallback).toHaveBeenCalledWith(referenceId);
  });
});
