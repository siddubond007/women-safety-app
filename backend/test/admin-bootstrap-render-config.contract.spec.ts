import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";

const renderBlueprint = readFileSync(
  new URL("../../render.yaml", import.meta.url),
  "utf8",
);

describe("staging Super Admin bootstrap Render configuration", () => {
  it("keeps bootstrap disabled until a digest and absolute expiry are explicitly configured", () => {
    expect(renderBlueprint).toContain(
      'key: SAKHI_STAGING_FULL_ADMIN_ENABLED\n        value: "false"',
    );
    expect(renderBlueprint).toContain(
      "key: SAKHI_STAGING_FULL_ADMIN_TOKEN_SHA256\n        sync: false",
    );
    expect(renderBlueprint).toContain(
      "key: SAKHI_STAGING_FULL_ADMIN_TOKEN_EXPIRES_AT\n        sync: false",
    );
  });

  it("does not configure the legacy plaintext bootstrap token", () => {
    expect(renderBlueprint).not.toMatch(
      /^\s*- key: SAKHI_STAGING_FULL_ADMIN_TOKEN\s*$/m,
    );
    expect(renderBlueprint).not.toContain("generateValue: true");
  });
});
