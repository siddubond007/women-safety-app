import { BadRequestException } from "@nestjs/common";
import { IsString } from "class-validator";
import { describe, expect, it } from "vitest";
import { createGlobalValidationPipe } from "../src/common/validation/create-validation-pipe.js";

class TestBody {
  @IsString()
  name!: string;
}

describe("global request validation policy", () => {
  it("rejects properties that are not defined on the request DTO", async () => {
    const pipe = createGlobalValidationPipe();
    await expect(
      pipe.transform(
        { name: "Sakhi", unexpected: "not allowed" },
        { type: "body", metatype: TestBody, data: undefined },
      ),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it("rejects incorrect DTO property types", async () => {
    const pipe = createGlobalValidationPipe();
    await expect(
      pipe.transform(
        { name: 123 },
        { type: "body", metatype: TestBody, data: undefined },
      ),
    ).rejects.toBeInstanceOf(BadRequestException);
  });
});
