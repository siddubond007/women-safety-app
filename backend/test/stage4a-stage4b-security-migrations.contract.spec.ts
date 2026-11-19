import { readFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

const roleMigration = readFileSync(
  new URL("../prisma/migrations/20261119140000_admin_staff_role_constraints/migration.sql", import.meta.url),
  "utf8",
);
const searchPathMigration = readFileSync(
  new URL("../prisma/migrations/20261119150000_secure_admin_bootstrap_function_search_path/migration.sql", import.meta.url),
  "utf8",
);
const apiRoleRevocationMigration = readFileSync(
  new URL("../prisma/migrations/20261119160000_revoke_data_api_roles_from_member_data/migration.sql", import.meta.url),
  "utf8",
);
const schema = readFileSync(
  new URL("../prisma/schema.prisma", import.meta.url),
  "utf8",
);
const stage4Runner = readFileSync(
  new URL("../scripts/staging-apply-stage4-reviewed.sh", import.meta.url),
  "utf8",
);
const stage4MigrationRunner = readFileSync(
  new URL("../scripts/staging-stage4-migration.cjs", import.meta.url),
  "utf8",
);
const reviewedMigrationRouter = readFileSync(
  new URL("../scripts/staging-migrate-reviewed.sh", import.meta.url),
  "utf8",
);
const prismaConfig = readFileSync(
  new URL("../prisma.config.ts", import.meta.url),
  "utf8",
);
const stage4Workflow = readFileSync(
  new URL("../../.github/workflows/sakhi-staging-stage4-migrations.yml", import.meta.url),
  "utf8",
);

describe("Stage 4A admin-role database constraints", () => {
  it("requires explicit staff role and status rather than privilege-bearing defaults", () => {
    const model = schema.match(/model AdminStaffAccount\s*\{([\s\S]*?)^\}/m)?.[1] ?? "";
    expect(model).toMatch(/^\s*role\s+String\s+@db\.VarChar\(40\)/m);
    expect(model).toMatch(/^\s*status\s+String\s+@db\.VarChar\(24\)/m);
    expect(model).not.toMatch(/^\s*role\s+String\s+@default/m);
    expect(model).not.toMatch(/^\s*status\s+String\s+@default/m);
    expect(roleMigration).toContain("ALTER COLUMN role DROP DEFAULT");
    expect(roleMigration).toContain("ALTER COLUMN status DROP DEFAULT");
    expect(roleMigration).toContain("admin_staff_accounts_role_allowed_check");
    expect(roleMigration).toContain("admin_staff_accounts_status_allowed_check");
    expect(roleMigration).toContain("admin_staff_accounts_reviewer_role_check");
    expect(roleMigration).toContain("RAISE EXCEPTION");
  });

  it("preflights existing role, status and reviewer-clearance data before changing defaults", () => {
    const preflight = roleMigration.indexOf("DO $$");
    const mutation = roleMigration.indexOf("ALTER TABLE public.admin_staff_accounts");
    expect(preflight).toBeGreaterThanOrEqual(0);
    expect(mutation).toBeGreaterThan(preflight);
    expect(roleMigration).toContain("'READ_ONLY_AUDITOR'");
    expect(roleMigration).toContain("is_authorised_complaint_reviewer IS TRUE");
  });
});

describe("Stage 4B database isolation hardening", () => {
  it("pins the bootstrap trigger function search_path and verifies the setting", () => {
    expect(searchPathMigration).toContain(
      "ALTER FUNCTION public.guard_admin_bootstrap_credential_consumption()",
    );
    expect(searchPathMigration).toContain("SET search_path = pg_catalog");
    expect(searchPathMigration).toContain("proconfig");
    expect(searchPathMigration).toContain("search_path=pg_catalog");
  });

  it("removes Data API default grants for future objects created by Sakhi table owners", () => {
    for (const owner of ["postgres", "sakhi_staging_migrator"]) {
      expect(apiRoleRevocationMigration).toContain(
        `ALTER DEFAULT PRIVILEGES FOR ROLE ${owner} IN SCHEMA public`,
      );
    }
    expect(apiRoleRevocationMigration).toContain(
      "REVOKE ALL ON TABLES FROM anon, authenticated, service_role",
    );
    expect(apiRoleRevocationMigration).toContain(
      "REVOKE ALL ON SEQUENCES FROM anon, authenticated, service_role",
    );
    expect(apiRoleRevocationMigration).toContain(
      "REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC, anon, authenticated, service_role",
    );
    expect(apiRoleRevocationMigration).toContain("Application table-owner default privileges still expose public objects");
  });

  it("syntax-checks the Stage 4 migration runner and reviewed shell entry points", () => {
    const nodeCheck = spawnSync(
      process.execPath,
      ["--check", fileURLToPath(new URL("../scripts/staging-stage4-migration.cjs", import.meta.url))],
      { encoding: "utf8" },
    );
    expect(nodeCheck.status, nodeCheck.stderr).toBe(0);

    if (process.platform !== "win32") {
      for (const script of [
        "../scripts/staging-apply-stage4-reviewed.sh",
        "../scripts/staging-migrate-reviewed.sh",
      ]) {
        const shellCheck = spawnSync(
          "bash",
          ["-n", fileURLToPath(new URL(script, import.meta.url))],
          { encoding: "utf8" },
        );
        expect(shellCheck.status, shellCheck.stderr).toBe(0);
      }
    }
  });

  it("routes Stage 4 through the two-role owner-aware migration gate, not generic migrate deploy", () => {
    expect(stage4Runner).toContain("SAKHI_STAGING_POSTGRES_DATABASE_URL");
    expect(stage4Runner).toContain("SAKHI_MIGRATOR_DATABASE_URL");
    expect(stage4Runner).toContain("staging-stage4-migration.cjs");
    expect(stage4MigrationRunner).toContain("SET LOCAL ROLE sakhi_staging_migrator");
    expect(stage4MigrationRunner).toContain("roleAndConnectionPreflight");
    expect(stage4MigrationRunner).toContain("verifyOwners");
    expect(stage4MigrationRunner).toContain('"prisma", "migrate", "resolve"');
    expect(reviewedMigrationRouter).toContain("never run through generic Prisma migrate deploy");
    expect(reviewedMigrationRouter).toContain("staging-apply-stage4-reviewed.sh");
    expect(prismaConfig).toContain("stage4MigrationResolveApproved");
    expect(prismaConfig).toContain("!stage3b2MigrationApproved");
    expect(stage4Workflow).toContain("workflow_dispatch");
    expect(stage4Workflow).toContain("environment: staging");
    expect(stage4Workflow).toContain("SAKHI_STAGING_POSTGRES_DATABASE_URL");
    expect(stage4Workflow).toContain("YES_APPLY_20261119_STAGE4_RBAC_RLS");
  });

  it("revokes all Data API role privileges from every protected member and admin table", () => {
    for (const table of [
      "member_accounts",
      "member_profiles",
      "member_consents",
      "auth_sessions",
      "otp_challenges",
      "community_posts",
      "direct_messages",
      "safety_sos_events",
      "menstrual_cycle_logs",
      "menstrual_daily_logs",
      "menstrual_tracker_preferences",
      "discreet_complaints",
      "audit_events",
      "admin_staff_accounts",
      "admin_staff_sessions",
      "admin_staff_mfa",
      "admin_auth_sessions",
      "admin_bootstrap_credentials",
    ]) {
      expect(apiRoleRevocationMigration).toContain(`'${table}'`);
    }
    expect(apiRoleRevocationMigration).toContain("FROM PUBLIC");
    expect(apiRoleRevocationMigration).toContain("FROM %I");
    for (const role of ["anon", "authenticated", "service_role"]) {
      expect(apiRoleRevocationMigration).toContain(`'${role}'`);
    }
    expect(apiRoleRevocationMigration).toContain("has_table_privilege");
    expect(apiRoleRevocationMigration).toContain("has_any_column_privilege");
    expect(apiRoleRevocationMigration).toContain("REVOKE ALL PRIVILEGES (%I) ON TABLE public.%I FROM %I");
    expect(apiRoleRevocationMigration).toContain("Dedicated Sakhi backend role lost required protected-table access");
  });
});
