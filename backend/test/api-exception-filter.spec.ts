import "reflect-metadata";
import { afterEach, describe, expect, it } from "vitest";
import { Test } from "@nestjs/testing";
import { LoggerModule } from "nestjs-pino";
import { ApiExceptionFilter } from "../src/common/filters/api-exception.filter.js";

describe("API exception filter dependency injection", () => {
  let moduleRef: Awaited<ReturnType<typeof createTestModule>> | undefined;

  async function createTestModule() {
    return Test.createTestingModule({
      imports: [LoggerModule.forRoot()],
      providers: [ApiExceptionFilter],
    }).compile();
  }

  afterEach(async () => {
    if (moduleRef) {
      await moduleRef.close();
      moduleRef = undefined;
    }
  });

  it("resolves its scoped Pino logger when the Nest module starts", async () => {
    moduleRef = await createTestModule();
    expect(moduleRef.get(ApiExceptionFilter)).toBeInstanceOf(
      ApiExceptionFilter,
    );
  });
});
