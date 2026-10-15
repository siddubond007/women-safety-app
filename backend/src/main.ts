import "reflect-metadata";
import { json, urlencoded } from "express";
import helmet from "helmet";
import { NestFactory } from "@nestjs/core";
import { DocumentBuilder, SwaggerModule } from "@nestjs/swagger";
import { Logger } from "nestjs-pino";
import { AppModule } from "./app.module.js";
import { createGlobalValidationPipe } from "./common/validation/create-validation-pipe.js";
import { ApiExceptionFilter } from "./common/filters/api-exception.filter.js";

async function bootstrap(): Promise<void> {
  const app = await NestFactory.create(AppModule, {
    bufferLogs: true,
    bodyParser: false,
  });

  app.useLogger(app.get(Logger));
  // Swagger is enabled only for the local development/test foundation; production
  // startup is rejected by environment validation.
  app.use(helmet({ contentSecurityPolicy: false }));
  app.use(json({ limit: "64kb", strict: true }));
  app.use(urlencoded({ extended: false, limit: "64kb", parameterLimit: 100 }));

  app.setGlobalPrefix("api/v1");
  app.useGlobalPipes(createGlobalValidationPipe());
  app.useGlobalFilters(app.get(ApiExceptionFilter));
  app.enableShutdownHooks();

  const openApi = new DocumentBuilder()
    .setTitle("Sakhi Backend API")
    .setDescription(
      "Stage 1 development/test foundation. Only liveness and readiness endpoints are implemented.",
    )
    .setVersion("0.1.0")
    .addTag("health")
    .build();
  const document = SwaggerModule.createDocument(app, openApi);
  SwaggerModule.setup("api/docs", app, document, {
    swaggerOptions: { persistAuthorization: false },
  });

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
