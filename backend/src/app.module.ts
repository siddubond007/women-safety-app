import { randomUUID } from "node:crypto";
import type { IncomingMessage, ServerResponse } from "node:http";
import { Module } from "@nestjs/common";
import { ConfigModule } from "@nestjs/config";
import { LoggerModule } from "nestjs-pino";
import { validateEnvironment } from "./config/env.schema.js";
import { AuthModule } from "./auth/auth.module.js";
import { EligibilityModule } from "./eligibility/eligibility.module.js";
import { AdminReviewModule } from "./admin-review/admin-review.module.js";
import { StagingTestAdminModule } from "./staging-test-admin/staging-test-admin.module.js";
import { Module2Module } from "./module2/module2.module.js";
import { PrismaModule } from "./database/prisma.module.js";
import { HealthController } from "./health/health.controller.js";
import { HealthService } from "./health/health.service.js";

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      cache: true,
      validate: validateEnvironment,
    }),
    LoggerModule.forRoot({
      pinoHttp: {
        level: process.env.LOG_LEVEL ?? "info",
        redact: {
          paths: [
            "req.headers.authorization",
            "req.headers.cookie",
            'req.headers["x-api-key"]',
            'req.headers["x-auth-token"]',
            'req.headers["x-sakhi-staging-test-admin-token"]',
            'req.headers["x-sakhi-staging-admin-session"]',
            'req.headers["x-sakhi-admin-token"]',
            'req.headers["x-sakhi-admin-review-token"]',
            "req.body.password",
            "req.body.token",
            "req.body.otp",
            "req.body.code",
            "req.body.phone",
            "req.body.phoneNumber",
            "req.body.countryCode",
            "req.body.displayName",
            "req.body.dateOfBirth",
            "req.body.email",
            "req.body.selfie",
            "req.body.livenessPayload",
            "req.body.governmentId",
            "req.body.emergencyContacts",
            "req.body.cycleData",
            "req.body.healthNotes",
          ],
          censor: "[REDACTED]",
        },
        genReqId: (req: IncomingMessage, res: ServerResponse) => {
          const existing = req.headers["x-request-id"];
          const requestId =
            typeof existing === "string" &&
            /^[a-zA-Z0-9._-]{8,64}$/.test(existing)
              ? existing
              : randomUUID();
          res.setHeader("x-request-id", requestId);
          return requestId;
        },
      },
    }),
    PrismaModule,
    AuthModule,
    EligibilityModule,
    AdminReviewModule,
    StagingTestAdminModule,
    Module2Module,
  ],
  controllers: [HealthController],
  providers: [HealthService],
})
export class AppModule {}
