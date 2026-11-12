import { describe, expect, it } from "vitest";
import { GUARDS_METADATA, PATH_METADATA } from "@nestjs/common/constants";
import { AdminReviewController } from "../src/admin-review/admin-review.controller.js";
import { ComplaintsController } from "../src/complaints/complaints.controller.js";
import { StagingTestAdminController } from "../src/staging-test-admin/staging-test-admin.controller.js";
import { AdminStaffSessionGuard } from "../src/admin-security/admin-staff-session.guard.js";

function hasGuard(target: object): boolean {
  const guards = Reflect.getMetadata(GUARDS_METADATA, target) as unknown[] | undefined;
  return Boolean(guards?.includes(AdminStaffSessionGuard));
}

describe("Super Admin endpoint authentication coverage", () => {
  it("guards every Admin Review and staff-authentication route at controller scope", () => {
    expect(hasGuard(AdminReviewController)).toBe(true);
    expect(hasGuard(StagingTestAdminController)).toBe(true);
  });

  it("guards every complaints administration route individually", () => {
    const prototype = ComplaintsController.prototype;
    const adminRoutes: string[] = [];
    for (const name of Object.getOwnPropertyNames(prototype)) {
      if (name === "constructor") continue;
      const handler = (prototype as unknown as Record<string, unknown>)[name];
      if (typeof handler !== "function") continue;
      const routePath = Reflect.getMetadata(PATH_METADATA, handler);
      const paths = Array.isArray(routePath) ? routePath : [routePath];
      if (
        paths.some(
          (path) =>
            typeof path === "string" &&
            (path.startsWith("admin-review/") || path.startsWith("complaints/admin/")),
        )
      ) {
        adminRoutes.push(name);
        expect(hasGuard(handler)).toBe(true);
      }
    }
    expect(adminRoutes.length).toBeGreaterThanOrEqual(11);
  });
});
