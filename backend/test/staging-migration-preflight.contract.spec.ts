import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";

const preflight = readFileSync(
  new URL("../scripts/staging-preflight.cjs", import.meta.url),
  "utf8",
);
const runner = readFileSync(
  new URL("../scripts/staging-migrate-reviewed.sh", import.meta.url),
  "utf8",
);
const stage4Runner = readFileSync(
  new URL("../scripts/staging-apply-stage4-reviewed.sh", import.meta.url),
  "utf8",
);
const stage4Executor = readFileSync(
  new URL("../scripts/staging-stage4-migration.cjs", import.meta.url),
  "utf8",
);
const prismaConfig = readFileSync(
  new URL("../prisma.config.ts", import.meta.url),
  "utf8",
);
const runtimeGrants = readFileSync(
  new URL("../prisma/staging/runtime-grants.sql", import.meta.url),
  "utf8",
);

const reviewedMigrationSets = [
  {
    migrations: [
      "20261113130000_allow_scoped_system_auth_audit",
      "20261113140000_retention_deletion_runtime_grants",
      "20261114110000_scope_retention_system_audit",
    ],
    approval: "YES_APPLY_20261113_14_STAGE3B2",
  },
  {
    migrations: [
      "20261119140000_admin_staff_role_constraints",
      "20261119150000_secure_admin_bootstrap_function_search_path",
      "20261119160000_revoke_data_api_roles_from_member_data",
    ],
    approval: "YES_APPLY_20261119_STAGE4_RBAC_RLS",
  },
];
const reviewedMigrations = reviewedMigrationSets.flatMap((set) => set.migrations);

describe("Reviewed staging migration contract", () => {
  it("requires one exact ordered reviewed migration target and its matching approval phrase", () => {
    for (const migration of reviewedMigrations) {
      expect(preflight).toContain(`"${migration}"`);
      expect(runner).toContain(migration);
    }
    expect(preflight).toContain("const REVIEWED_MIGRATION_SETS = [");
    expect(preflight).toContain('candidate.migrations.join(",") === process.env.SAKHI_MIGRATION_TARGET');
    expect(preflight).toContain("selectedMigrationSet.approvalPhrase");
    expect(runner).toContain('STAGE3B2_APPROVAL="YES_APPLY_20261113_14_STAGE3B2"');
    expect(runner).toContain('STAGE4_APPROVAL="YES_APPLY_20261119_STAGE4_RBAC_RLS"');
    expect(runner).toContain("case \"${SAKHI_MIGRATION_TARGET:-}\" in");
    expect(prismaConfig).toContain(
      '"20261113130000_allow_scoped_system_auth_audit,20261113140000_retention_deletion_runtime_grants,20261114110000_scope_retention_system_audit"',
    );
    expect(prismaConfig).toContain(
      '"20261119140000_admin_staff_role_constraints,20261119150000_secure_admin_bootstrap_function_search_path,20261119160000_revoke_data_api_roles_from_member_data"',
    );
    expect(prismaConfig).toContain('"YES_APPLY_20261113_14_STAGE3B2"');
    expect(prismaConfig).toContain('"YES_APPLY_20261119_STAGE4_RBAC_RLS"');
    expect(prismaConfig).not.toContain("YES_APPLY_20261106010000_MODULES8_12");
    expect(prismaConfig).not.toContain("20261106010000_modules8_9_10_11_12_complete");
    expect(preflight).not.toContain("YES_APPLY_20261106010000_MODULES8_12");
    expect(runner).not.toContain("20261106010000_modules8_9_10_11_12_complete");
  });

  it("rejects every pending migration outside the exact selected reviewed set", () => {
    expect(preflight).toContain(
      "const unexpectedPending = pending.filter((name) => !expectedMigrations.includes(name))",
    );
    expect(preflight).toContain("if (unknownApplied.length > 0)");
    expect(preflight).toContain("if (unexpectedPending.length > 0)");
    expect(preflight).toContain("if (failed.length > 0)");
    expect(runner).toContain("node scripts/staging-preflight.cjs migrations");
    expect(runner).toContain("npm run db:migrate:deploy");
  });

  it("routes Stage 4 through the owner-aware runner instead of generic Prisma migrate deploy", () => {
    expect(stage4Runner).toContain('EXPECTED_TARGET="20261119140000_admin_staff_role_constraints,20261119150000_secure_admin_bootstrap_function_search_path,20261119160000_revoke_data_api_roles_from_member_data"');
    expect(stage4Runner).toContain('APPROVAL_PHRASE="YES_APPLY_20261119_STAGE4_RBAC_RLS"');
    expect(stage4Runner).toContain('SAKHI_STAGING_POSTGRES_DATABASE_URL');
    expect(stage4Executor).toContain('prod-ca-2021.crt');
    expect(stage4Runner).toContain("node scripts/staging-preflight.cjs migrations");
    expect(stage4Runner).toContain("node scripts/staging-stage4-migration.cjs");
    expect(stage4Runner).not.toContain("npm run db:migrate:deploy");
    expect(stage4Executor).toContain('const EXPECTED_HOST = "aws-0-ap-south-1.pooler.supabase.com"');
    expect(stage4Executor).toContain('const PROJECT_REF = "wmlpokholjfadyohdlgo"');
    expect(stage4Executor).toContain("MIGRATOR_OWNED_TABLES");
    expect(stage4Executor).toContain("POSTGRES_OWNED_TABLES");
    expect(stage4Executor).toContain("PROTECTED_TABLES");
    expect(stage4Executor).toContain("SET LOCAL ROLE sakhi_staging_migrator");
    expect(stage4Executor).toContain("has_any_column_privilege");
    expect(stage4Executor).toContain("rejectUnauthorized: true");
    expect(stage4Executor).toContain('"migrate", "resolve", "--applied", migration');
    expect(stage4Executor).toContain("default_acl_hardened");
  });

  it("keeps the exact Supabase project, host, migrator identity and TLS checks", () => {
    expect(preflight).toContain('const EXPECTED_HOST = "aws-0-ap-south-1.pooler.supabase.com"');
    expect(preflight).toContain('const PROJECT_REF = "wmlpokholjfadyohdlgo"');
    expect(preflight).toContain("sakhi_staging_migrator.${PROJECT_REF}");
    expect(preflight).toContain('url.searchParams.get("sslmode") !== "verify-full"');
    expect(preflight).toContain("rejectUnauthorized: true");
    expect(preflight).toContain('rows[0]?.database_user !== "sakhi_staging_migrator"');
  });

  it("allows only the exact non-inheritable managed postgres-to-runtime membership", () => {
    expect(runtimeGrants).toContain("JOIN pg_roles member_role ON member_role.oid = m.member");
    expect(runtimeGrants).toContain("m.roleid = runtime_role_oid");
    expect(runtimeGrants).toContain("member_role.rolname = 'postgres'");
    expect(runtimeGrants).toContain("m.admin_option IS TRUE");
    expect(runtimeGrants).toContain("m.inherit_option IS FALSE");
    expect(runtimeGrants).toContain("m.set_option IS FALSE");
    expect(runtimeGrants).toContain("AND NOT (");
    expect(runtimeGrants).toContain("sakhi_staging_app has an unexpected incoming or outgoing PostgreSQL role membership");
  });

  it("does not grant membership, role escalation, public access, or ownership to the runtime role", () => {
    expect(runtimeGrants).not.toMatch(/\bGRANT\s+sakhi_staging_app\s+TO\s+postgres\b/i);
    expect(runtimeGrants).not.toMatch(/\bALTER\s+ROLE\s+sakhi_staging_app\b/i);
    expect(runtimeGrants).toContain("rolsuper OR rolbypassrls OR rolcreatedb OR rolcreaterole OR rolreplication");
    expect(runtimeGrants).toContain("sakhi_staging_app must not own P0 staff-security tables");
    expect(runtimeGrants).toContain("REVOKE ALL ON TABLE public._prisma_migrations FROM sakhi_staging_app");
  });
});
