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
const retentionAuditMigration = read(
  "../prisma/migrations/20261114110000_scope_retention_system_audit/migration.sql",
);
const prismaService = read("../src/database/prisma.service.ts");
const mfaDatabaseIntegration = read("./admin-mfa.database.integration.spec.ts");
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

  it("allows only exact retention SYSTEM audit shapes under the internal system-job context", () => {
    expect(retentionAuditMigration).toContain("current_setting('app.system_job',true)='true'");
    expect(retentionAuditMigration).toContain("action='module2.account.deletion_completed'");
    expect(retentionAuditMigration).toContain("target_type='account_deletion_request'");
    expect(retentionAuditMigration).toContain("request_id=target_id");
    expect(retentionAuditMigration).toContain("redacted_metadata->>'externalMediaPurged'='true'");
    expect(retentionAuditMigration).toContain("action='module5.complaint.evidence.retention_purged'");
    expect(retentionAuditMigration).toContain("target_type='module5_complaint'");
    expect(retentionAuditMigration).toContain("target_id LIKE '#SKH-ANON-%'");
    expect(retentionAuditMigration).toContain("redacted_metadata->>'retentionPurge'='true'");
    expect(retentionAuditMigration).toMatch(/actor_type='SYSTEM'[\s\S]*actor_id IS NULL/s);
    expect(retentionAuditMigration).toContain("action='auth.otp.requested'");
    expect(prismaService).toContain("set_config('app.system_job', 'true', true)");
    expect(prismaService).toContain("set_config('app.system_job', 'false', true)");
    expect(lifecycleIntegration).toContain("system.unapproved.integration_event");
  });

  it("keeps full staff MFA lifecycle verification staging-only", () => {
    expect(mfaDatabaseIntegration).toContain(
      'process.env.SAKHI_STAGING_MFA_DB_INTEGRATION === "true"',
    );
    expect(mfaDatabaseIntegration).toContain('process.env.SAKHI_ENV !== "staging"');
    expect(mfaDatabaseIntegration).toContain('process.env.NODE_ENV !== "production"');
    expect(mfaDatabaseIntegration).toContain('assertSakhiDatabaseTarget(appUrl, "app", "staging")');
    expect(mfaDatabaseIntegration).toContain('expect(principal[0]?.role).toBe("sakhi_staging_app")');
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
      "required USING predicate token",
    );
    expect(retentionMigration).toContain("md5(lower(regexp_replace(COALESCE(actual_policy.qual");
    expect(retentionMigration).toContain("expected.qual_hash");
    expect(retentionMigration).toContain("expected.check_hash");
    expect(retentionMigration).toContain("Unexpected permissive lifecycle RLS policy may broaden runtime access");
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


describe("retention SYSTEM audit remediation contract", () => {
  it("keeps SYSTEM retention audit writes scoped to exact job event shapes", () => {
    const migration = readFileSync(new URL("../prisma/migrations/20261114110000_scope_retention_system_audit/migration.sql", import.meta.url), "utf8");
    expect(migration).toContain("current_setting('app.system_job',true)='true'");
    expect(migration).toContain("action='module2.account.deletion_completed'");
    expect(migration).toContain("action='module5.complaint.evidence.retention_purged'");
    expect(migration).toContain("target_type='account_deletion_request'");
    expect(migration).toContain("target_type='module5_complaint'");
    expect(migration).toContain("request_id=target_id");
    expect(migration).toContain("action='auth.otp.requested'");
  });
});
