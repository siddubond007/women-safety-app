import "reflect-metadata";
import type { INestApplication } from "@nestjs/common";
import { ConfigModule, ConfigService } from "@nestjs/config";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { Test } from "@nestjs/testing";
import request from "supertest";
import { AuthController } from "../src/auth/auth.controller.js";
import { AuthModule } from "../src/auth/auth.module.js";
import { AuthenticationService } from "../src/auth/auth.service.js";
import {
  CreateProfileDto,
  RequestOtpDto,
  ResendOtpDto,
  VerifyOtpDto,
} from "../src/auth/auth.dto.js";
import { PrismaService } from "../src/database/prisma.service.js";
import { createGlobalValidationPipe } from "../src/common/validation/create-validation-pipe.js";

describe.skipIf(process.env.SAKHI_DB_INTEGRATION !== "true")(
  "database-backed development authentication flow",
  () => {
    let app: INestApplication | undefined;

    beforeAll(async () => {
      if (process.env.SAKHI_ENV !== "test") {
        throw new Error("Integration tests require SAKHI_ENV=test.");
      }
      if (process.env.NODE_ENV !== "development") {
        throw new Error("Integration tests require NODE_ENV=development.");
      }
      if (process.env.SAKHI_OTP_MODE !== "development") {
        throw new Error(
          "Integration tests require the local development OTP provider.",
        );
      }
      if ((process.env.HOST ?? "127.0.0.1") !== "127.0.0.1") {
        throw new Error("Integration tests only support loopback.");
      }
      const databaseUrl = process.env.SAKHI_APP_DATABASE_URL;
      if (!databaseUrl) {
        throw new Error(
          "Missing SAKHI_APP_DATABASE_URL. Use the test integration runner.",
        );
      }
      const parsed = new URL(databaseUrl);
      if (
        parsed.hostname !== "127.0.0.1" ||
        parsed.pathname !== "/sakhi_test"
      ) {
        throw new Error(
          "Refusing integration test against any database except local sakhi_test.",
        );
      }

      // tsx/vitest uses esbuild and does not emit Nest design:paramtypes metadata.
      Reflect.defineMetadata(
        "design:paramtypes",
        [ConfigService],
        PrismaService,
      );
      Reflect.defineMetadata(
        "design:paramtypes",
        [PrismaService],
        AuthenticationService,
      );
      Reflect.defineMetadata(
        "design:paramtypes",
        [AuthenticationService],
        AuthController,
      );
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

      const testingModule = await Test.createTestingModule({
        imports: [
          ConfigModule.forRoot({ isGlobal: true, ignoreEnvFile: true }),
          AuthModule,
        ],
      }).compile();

      app = testingModule.createNestApplication();
      app.setGlobalPrefix("api/v1");
      app.useGlobalPipes(createGlobalValidationPipe());
      await app.init();
    });

    afterAll(async () => {
      await app?.close();
      app = undefined;
    });

    it("requests OTP, verifies it, saves profile, reads account, then revokes session", async () => {
      if (!app) throw new Error("Integration test app did not initialize.");
      // Regression guard: every app database session must use UTC.
      const timezoneRows = await app.get(PrismaService).$queryRaw<
        Array<{ timezone: string }>
      >`
        SELECT current_setting('TimeZone') AS timezone
      `;
      expect(timezoneRows[0]?.timezone).toBe("UTC");

      // Reserved-looking, fictional US test range; no SMS provider is configured.
      const suffix = String(Date.now() % 100).padStart(2, "0");
      const phoneNumber = `20255501${suffix}`;

      const otpResponse = await request(app.getHttpServer())
        .post("/api/v1/auth/otp/request")
        .send({ countryCode: "+1", phoneNumber, purpose: "registration" })
        .expect(200);

      expect(otpResponse.body).toMatchObject({
        deliveryMode: "development_echo",
        isDemo: true,
      });
      expect(otpResponse.body.challengeId).toMatch(
        /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i,
      );
      expect(otpResponse.body.developmentCode).toMatch(/^\d{6}$/);

      const verifyResponse = await request(app.getHttpServer())
        .post("/api/v1/auth/otp/verify")
        .send({
          challengeId: otpResponse.body.challengeId,
          code: otpResponse.body.developmentCode,
        })
        .expect(200);

      expect(verifyResponse.body).toMatchObject({
        status: "verified",
        accountState: "newAccount",
        tokenType: "Bearer",
        isDemo: true,
      });
      expect(verifyResponse.body.accessToken).toEqual(expect.any(String));
      const authorization = `Bearer ${verifyResponse.body.accessToken}`;

      const profileResponse = await request(app.getHttpServer())
        .post("/api/v1/auth/profile")
        .set("Authorization", authorization)
        .send({
          displayName: "Sakhi Integration Test",
          dateOfBirth: "1999-04-12",
          email: "integration-test@example.com",
          termsVersion: "draft",
          privacyVersion: "draft",
          acceptedAt: new Date().toISOString(),
          optionalUpdatesAccepted: false,
        })
        .expect(200);

      expect(profileResponse.body).toMatchObject({
        accountState: "pendingVerification",
        profile: {
          displayName: "Sakhi Integration Test",
          dateOfBirth: "1999-04-12",
          email: "integration-test@example.com",
        },
      });

      const meResponse = await request(app.getHttpServer())
        .get("/api/v1/auth/me")
        .set("Authorization", authorization)
        .expect(200);

      expect(meResponse.body).toMatchObject({
        status: "PENDING_VERIFICATION",
        verificationStatus: "UNVERIFIED",
        profile: {
          displayName: "Sakhi Integration Test",
          dateOfBirth: "1999-04-12",
          email: "integration-test@example.com",
        },
        isDemo: true,
      });

      await request(app.getHttpServer())
        .post("/api/v1/auth/logout")
        .set("Authorization", authorization)
        .expect(200)
        .expect(({ body }) =>
          expect(body).toMatchObject({ status: "signed_out" }),
        );

      await request(app.getHttpServer())
        .get("/api/v1/auth/me")
        .set("Authorization", authorization)
        .expect(401);
    });
  },
);
