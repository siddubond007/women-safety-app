import "reflect-metadata";
import { json, urlencoded } from "express";
import type { NextFunction, Request, Response } from "express";
import helmet from "helmet";
import { NestFactory } from "@nestjs/core";
import { DocumentBuilder, SwaggerModule } from "@nestjs/swagger";
import { Logger } from "nestjs-pino";
import { AppModule } from "./app.module.js";
import { createGlobalValidationPipe } from "./common/validation/create-validation-pipe.js";
import { ApiExceptionFilter } from "./common/filters/api-exception.filter.js";
import { AnonymousEvidenceUploadRateLimitMiddleware } from "./common/middleware/anonymous-evidence-upload-rate-limit.middleware.js";
import { AdminAuthRateLimitMiddleware } from "./common/middleware/admin-auth-rate-limit.middleware.js";
import { runWithDatabaseRequestIdentity } from "./database/database-request-identity.context.js";

async function bootstrap(): Promise<void> {
  const app = await NestFactory.create(AppModule, {
    bufferLogs: true,
    bodyParser: false,
  });

  app.useLogger(app.get(Logger));
  // Render terminates TLS at one trusted proxy; use the client address supplied
  // by that proxy for the narrowly scoped anonymous upload limiter.
  app.getHttpAdapter().getInstance().set("trust proxy", 1);
  app.use((request: Request, _response: Response, next: NextFunction) => {
    const path =
      String(request.originalUrl ?? request.url ?? "").split("?")[0] ?? "";
    const authLookup =
      request.method === "POST" &&
      /\/auth\/otp\/(request|resend|verify)$/.test(path);
    const usernameLookup =
      request.method === "GET" && /\/auth\/username-availability$/.test(path);
    runWithDatabaseRequestIdentity(next, { authLookup, usernameLookup });
  });
  // Swagger is enabled only for the local development/test foundation; production
  // startup is rejected by environment validation.
  app.use(helmet({ contentSecurityPolicy: false }));
  // Local Super Admin Vite origins only. CORS is not authorization; each
  // admin endpoint independently validates the server-side reviewer token.
  const isStaging = process.env.SAKHI_ENV === "staging";
  const defaultAdminCorsOrigins = isStaging
    ? ""
    : "http://127.0.0.1:5173,http://localhost:5173";
  const adminCorsOrigins = (
    process.env.SAKHI_ADMIN_CORS_ORIGIN ?? defaultAdminCorsOrigins
  )
    .split(",")
    .map((origin) => origin.trim())
    .filter(Boolean);
  for (const origin of adminCorsOrigins) {
    let parsed: URL;
    try {
      parsed = new URL(origin);
    } catch {
      throw new Error("SAKHI_ADMIN_CORS_ORIGIN contains an invalid origin.");
    }
    const validOrigin = isStaging
      ? parsed.protocol === "https:" && parsed.origin === origin
      : parsed.protocol === "http:" &&
        ["localhost", "127.0.0.1"].includes(parsed.hostname) &&
        parsed.origin === origin;
    if (!validOrigin) {
      throw new Error(
        isStaging
          ? "Staging admin CORS origins must be exact HTTPS origins."
          : "Local admin CORS origins must be exact localhost/127.0.0.1 HTTP origins.",
      );
    }
  }
  app.enableCors({
    origin: adminCorsOrigins,
    methods: ["GET", "POST", "PATCH", "PUT", "DELETE", "OPTIONS"],
    allowedHeaders: [
      "Content-Type",
      "Authorization",
      "X-Sakhi-Staging-Admin-Session",
      "X-Sakhi-CSRF",
    ],
    credentials: true,
    maxAge: 600,
  });
  const adminAuthRateLimiter = new AdminAuthRateLimitMiddleware();
  app.use((request: Request, response: Response, next: NextFunction) => {
    adminAuthRateLimiter.use(request, response, next);
  });
  const evidenceUploadLimiter =
    new AnonymousEvidenceUploadRateLimitMiddleware();
  app.use((request: Request, response: Response, next: NextFunction) => {
    const path = request.path.endsWith("/")
      ? request.path.slice(0, -1)
      : request.path;
    if (
      request.method === "POST" &&
      [
        "/api/v1/complaints/evidence-upload",
        "/api/v1/module2/complaints/evidence-upload",
      ].includes(path)
    ) {
      evidenceUploadLimiter.use(request, response, next);
      return;
    }
    next();
  });

  app.use(
    json({
      limit: "64kb",
      strict: true,
      verify: (request, _response, buffer) => {
        (request as unknown as { rawBody?: Buffer }).rawBody =
          Buffer.from(buffer);
      },
    }),
  );
  app.use(urlencoded({ extended: false, limit: "64kb", parameterLimit: 100 }));

  app.setGlobalPrefix("api/v1");
  app.useGlobalPipes(createGlobalValidationPipe());
  app.useGlobalFilters(app.get(ApiExceptionFilter));
  app.enableShutdownHooks();

  const openApi = new DocumentBuilder()
    .setTitle("Sakhi Backend API")
    .setDescription(
      "Sakhi development/test backend. OTP codes are locally echoed only when explicitly enabled; no SMS or real eligibility provider is connected.",
    )
    .setVersion("0.1.0")
    .addTag("health")
    .addTag("authentication")
    .addTag("eligibility")
    .build();
  if (process.env.NODE_ENV !== "production") {
    const document = SwaggerModule.createDocument(app, openApi);
    SwaggerModule.setup("api/docs", app, document, {
      swaggerOptions: { persistAuthorization: false },
    });
  }

  const port = Number(process.env.PORT ?? 3000);
  const host = process.env.HOST ?? "127.0.0.1";
  await app.listen(port, host);
}

bootstrap().catch((error: unknown) => {
  // Do not print configuration objects or connection strings during a startup failure.
  const message =
    error instanceof Error ? error.message : "Unknown startup failure";
  process.stderr.write("Sakhi backend failed to start: " + message + "\n");
  process.exitCode = 1;
});
