import "reflect-metadata";
import type { INestApplication } from "@nestjs/common";
import { afterEach, describe, expect, it, vi } from "vitest";
import { Test } from "@nestjs/testing";
import { PinoLogger } from "nestjs-pino";
import request from "supertest";
import { ApiExceptionFilter } from "../src/common/filters/api-exception.filter.js";
import { PrismaService } from "../src/database/prisma.service.js";
import { HealthController } from "../src/health/health.controller.js";
import { HealthService } from "../src/health/health.service.js";

describe("health endpoints", () => {
  let app: INestApplication | undefined;

  afterEach(async () => {
    if (app) {
      await app.close();
      app = undefined;
    }
  });

  async function createHealthApp(databaseResponds = true) {
    const queryRaw = vi.fn();
    if (databaseResponds) {
      queryRaw.mockResolvedValue([{ "?column?": 1 }]);
    } else {
      queryRaw.mockRejectedValue(new Error("private database driver detail"));
    }

    const fakePrisma = { $queryRaw: queryRaw } as unknown as PrismaService;
    // Vitest transpiles TypeScript via esbuild, which does not emit Nest's
    // design:paramtypes metadata. Provide the same constructor metadata that
    // tsc emits so the HTTP test module resolves real controller/service wiring.
    Reflect.defineMetadata("design:paramtypes", [PrismaService], HealthService);
    Reflect.defineMetadata(
      "design:paramtypes",
      [HealthService],
      HealthController,
    );
    const fakeLogger = {
      setContext: vi.fn(),
      error: vi.fn(),
    } as unknown as PinoLogger;

    const module = await Test.createTestingModule({
      controllers: [HealthController],
      providers: [
        HealthService,
        {
          provide: ApiExceptionFilter,
          useFactory: () => new ApiExceptionFilter(fakeLogger),
        },
        { provide: PrismaService, useValue: fakePrisma },
      ],
    }).compile();

    const testApp = module.createNestApplication();
    testApp.setGlobalPrefix("api/v1");
    testApp.useGlobalFilters(testApp.get(ApiExceptionFilter));
    await testApp.init();
    app = testApp;
    return { testApp, queryRaw };
  }

  it("returns process liveness without querying PostgreSQL", async () => {
    const { testApp, queryRaw } = await createHealthApp();
    await request(testApp.getHttpServer())
      .get("/api/v1/health/live")
      .expect(200)
      .expect({ status: "ok" });
    expect(queryRaw).not.toHaveBeenCalled();
  });

  it("returns ready only when the database probe succeeds", async () => {
    const { testApp, queryRaw } = await createHealthApp();
    await request(testApp.getHttpServer())
      .get("/api/v1/health/ready")
      .expect(200)
      .expect({ status: "ready", dependencies: { database: "ok" } });
    expect(queryRaw).toHaveBeenCalledTimes(1);
  });

  it("returns a sanitized 503 if PostgreSQL is unavailable", async () => {
    const { testApp } = await createHealthApp(false);
    const response = await request(testApp.getHttpServer())
      .get("/api/v1/health/ready")
      .expect(503);
    expect(response.body).toMatchObject({
      statusCode: 503,
      error: "Service Unavailable",
      message: "Service temporarily unavailable",
      requestId: null,
    });
    expect(JSON.stringify(response.body)).not.toContain(
      "private database driver detail",
    );
  });
});
