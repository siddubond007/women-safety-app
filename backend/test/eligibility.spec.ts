import "reflect-metadata";
import type { INestApplication } from "@nestjs/common";
import { afterEach, describe, expect, it, vi } from "vitest";
import { Test } from "@nestjs/testing";
import request from "supertest";
import { EligibilityController } from "../src/eligibility/eligibility.controller.js";
import { EligibilityService } from "../src/eligibility/eligibility.service.js";

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
      message: "No approved provider is configured.",
      isDemo: true,
    });
    const app = await createApp();
    const response = await request(app.getHttpServer())
      .get("/api/v1/eligibility/status")
      .set("Authorization", "Bearer a-valid-looking-test-token")
      .expect(200);

    expect(response.body.status).toBe("providerUnavailable");
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
