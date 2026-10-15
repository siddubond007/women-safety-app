import { randomUUID } from "node:crypto";
import { Module } from "@nestjs/common";
import { ConfigModule } from "@nestjs/config";
import { LoggerModule } from "nestjs-pino";
import { ApiExceptionFilter } from "./common/filters/api-exception.filter.js";
import { validateRuntimeEnvironment } from "./config/database-target.js";
import { PrismaModule } from "./database/prisma.module.js";
import { HealthController } from "./health/health.controller.js";
import { HealthService } from "./health/health.service.js";

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      ignoreEnvFile: true,
      validate: validateRuntimeEnvironment,
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
            "req.body.password",
            "req.body.otp",
            "req.body.code",
            "req.body.phone",
            "req.body.phoneNumber",
            "req.body.email",
            "req.body.dateOfBirth",
            "req.body.accessToken",
            "req.body.refreshToken",
            'res.headers["set-cookie"]',
          ],
          censor: "[REDACTED]",
        },
        genReqId: (_request, response) => {
          // Do not trust a caller-supplied request ID as the server correlation ID.
          const requestId = randomUUID();
          response.setHeader("x-request-id", requestId);
          return requestId;
        },
        serializers: {
          req(request) {
            const rawUrl = typeof request.url === "string" ? request.url : "";
            return {
              id: request.id,
              method: request.method,
              path: rawUrl.split("?")[0] || "/",
            };
          },
          res(response) {
            return { statusCode: response.statusCode };
          },
        },
      },
    }),
    PrismaModule,
  ],
  controllers: [HealthController],
  providers: [HealthService, ApiExceptionFilter],
})
export class AppModule {}
