import "reflect-metadata";
import type { INestApplication } from "@nestjs/common";
import { afterEach, describe, expect, it, vi } from "vitest";
import { Test } from "@nestjs/testing";
import request from "supertest";
import { createGlobalValidationPipe } from "../src/common/validation/create-validation-pipe.js";
import { AuthController } from "../src/auth/auth.controller.js";
import {
  CreateProfileDto,
  RequestOtpDto,
  ResendOtpDto,
  VerifyOtpDto,
} from "../src/auth/auth.dto.js";
import { AuthenticationService } from "../src/auth/auth.service.js";

describe("development authentication API contract", () => {
  let app: INestApplication | undefined;
  const auth = {
    requestOtp: vi.fn(),
    resendOtp: vi.fn(),
    verifyOtp: vi.fn(),
    createProfile: vi.fn(),
    getCurrentAccount: vi.fn(),
    logout: vi.fn(),
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
      [AuthenticationService],
      AuthController,
    );
    // esbuild test transpilation does not emit the method metadata tsc emits.
    Reflect.defineMetadata(
      "design:paramtypes",
      [RequestOtpDto],
      AuthController.prototype,
      "requestOtp",
    );
    Reflect.defineMetadata(
      "design:paramtypes",
      [ResendOtpDto],
      AuthController.prototype,
      "resendOtp",
    );
    Reflect.defineMetadata(
      "design:paramtypes",
      [VerifyOtpDto],
      AuthController.prototype,
      "verifyOtp",
    );
    Reflect.defineMetadata(
      "design:paramtypes",
      [String, CreateProfileDto],
      AuthController.prototype,
      "createProfile",
    );
    Reflect.defineMetadata(
      "design:paramtypes",
      [String],
      AuthController.prototype,
      "me",
    );
    Reflect.defineMetadata(
      "design:paramtypes",
      [String],
      AuthController.prototype,
      "logout",
    );
    const module = await Test.createTestingModule({
      controllers: [AuthController],
      providers: [{ provide: AuthenticationService, useValue: auth }],
    }).compile();
    const testApp = module.createNestApplication();
    testApp.setGlobalPrefix("api/v1");
    testApp.useGlobalPipes(createGlobalValidationPipe());
    await testApp.init();
    app = testApp;
    return testApp;
  }

  it("accepts a valid development OTP request and returns the typed contract", async () => {
    auth.requestOtp.mockResolvedValue({
      challengeId: "6c12c04a-7a85-411b-9b8a-c2c5902bce00",
      expiresAt: "2026-10-15T11:00:00.000Z",
      resendAvailableAt: "2026-10-15T10:55:30.000Z",
      developmentCode: "043821",
      deliveryMode: "development_echo",
      isDemo: true,
      message: "No SMS was sent.",
    });
    const app = await createApp();

    const response = await request(app.getHttpServer())
      .post("/api/v1/auth/otp/request")
      .send({
        countryCode: "+91",
        phoneNumber: "9876543210",
        purpose: "registration",
      })
      .expect(200);

    expect(response.body).toMatchObject({
      deliveryMode: "development_echo",
      isDemo: true,
      developmentCode: "043821",
    });
    expect(auth.requestOtp).toHaveBeenCalledWith({
      countryCode: "+91",
      phoneNumber: "9876543210",
      purpose: "registration",
    });
  });

  it("rejects unknown DTO fields before reaching the service", async () => {
    const app = await createApp();
    await request(app.getHttpServer())
      .post("/api/v1/auth/otp/request")
      .send({
        countryCode: "+91",
        phoneNumber: "9876543210",
        purpose: "registration",
        accountState: "ACTIVE",
      })
      .expect(400);
    expect(auth.requestOtp).not.toHaveBeenCalled();
  });

  it("rejects malformed OTP requests and codes", async () => {
    const app = await createApp();
    await request(app.getHttpServer())
      .post("/api/v1/auth/otp/request")
      .send({
        countryCode: "91",
        phoneNumber: "not-a-number",
        purpose: "registration",
      })
      .expect(400);

    await request(app.getHttpServer())
      .post("/api/v1/auth/otp/verify")
      .send({
        challengeId: "6c12c04a-7a85-411b-9b8a-c2c5902bce00",
        code: "12x",
      })
      .expect(400);
    expect(auth.requestOtp).not.toHaveBeenCalled();
    expect(auth.verifyOtp).not.toHaveBeenCalled();
  });
});
