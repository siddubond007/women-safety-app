import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";

const read = (relativePath: string) =>
  readFileSync(new URL(relativePath, import.meta.url), "utf8");

const authAuditMigration = read(
  "../prisma/migrations/20261113130000_allow_scoped_system_auth_audit/migration.sql",
);
const retentionMigration = read(
  "../prisma/migrations/20261113140000_retention_deletion_runtime_grants/migration.sql",
);
const lifecycleIntegration = read(
  "./retention-deletion.database.integration.spec.ts",
);
const module2Service = read("../src/module2/module2.service.ts");

describe("PR #40 Stage 1B security remediation contracts", () => {
  it("keeps both policy/grant migrations atomic", () => {
    for (const migration of [authAuditMigration, retentionMigration]) {
      expect(migration.trimStart()).toMatch(/^BEGIN;\s/);
      expect(migration.trimEnd()).toMatch(/COMMIT;$/);
    }
  });

  it("binds audit actor type and ID to the matching transaction identity", () => {
    expect(authAuditMigration).toContain(
      "actor_id=NULLIF(current_setting('app.admin_staff_id',true),'')::uuid",
    );
    expect(authAuditMigration).toMatch(
      /actor_type='SYSTEM'[\s\S]*actor_id IS NULL/s,
    );
    expect(read("../src/auth/auth.service.ts")).toContain("actorId: null");
    expect(authAuditMigration).toMatch(/action='auth\.otp\.requested'/);
    expect(authAuditMigration).toMatch(/target_type='otp_challenge'/);
    expect(authAuditMigration).toMatch(/request_id=target_id/);
  });

  it("postflights forced RLS and expected policies for all eight lifecycle tables", () => {
    for (const table of [
      "discreet_complaints",
      "member_communication_preferences",
      "eligibility_submissions",
      "business_directory_listings",
      "business_enquiries",
      "direct_messages",
      "safety_location_shares",
      "business_reports",
    ]) {
      expect(retentionMigration).toContain(`'${table}'`);
    }
    expect(retentionMigration).toContain("c.relrowsecurity");
    expect(retentionMigration).toContain("c.relforcerowsecurity");
    expect(retentionMigration).toContain(
      "One or more required lifecycle RLS policies are missing",
    );
  });

  it("refuses broad fixture cleanup and requires the same local database port", () => {
    expect(lifecycleIntegration).toContain("migratorUrl.port !== appUrl.port");
    expect(lifecycleIntegration).not.toMatch(
      /DELETE FROM public\.discreet_complaints WHERE reference_number LIKE/i,
    );
    expect(lifecycleIntegration).not.toMatch(
      /SELECT account_id FROM public\.member_profiles WHERE display_name/i,
    );
  });

  it("retains the directory bio in public discovery and profile projection paths", () => {
    expect(module2Service).toContain('bio: profile.bio ?? ""');
    expect(module2Service).toContain('bio: targetDir.bio ?? ""');
  });
});
