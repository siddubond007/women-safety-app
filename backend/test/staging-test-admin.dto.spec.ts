import { BadRequestException } from "@nestjs/common";
import { describe, expect, it } from "vitest";
import { createGlobalValidationPipe } from "../src/common/validation/create-validation-pipe.js";
import { StagingTestAdminLoginDto } from "../src/staging-test-admin/staging-test-admin.dto.js";

const validateLoginBody = (body: unknown) =>
  createGlobalValidationPipe().transform(body, {
    type: "body",
    metatype: StagingTestAdminLoginDto,
    data: undefined,
  });

describe("StagingTestAdminLoginDto", () => {
  it("accepts generated role-based staff tokens shorter than the master-secret length", async () => {
    const token = "SAKHI-VER-123-ABCDEF1234";
    expect(token.length).toBeLessThan(32);
    await expect(validateLoginBody({ token })).resolves.toMatchObject({ token });
  });

  it("rejects missing or trivially short tokens", async () => {
    await expect(validateLoginBody({ token: "short" })).rejects.toBeInstanceOf(
      BadRequestException,
    );
    await expect(validateLoginBody({})).rejects.toBeInstanceOf(BadRequestException);
  });
});