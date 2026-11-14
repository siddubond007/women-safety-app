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
const runtimeGrants = readFileSync(
  new URL("../prisma/staging/runtime-grants.sql", import.meta.url),
  "utf8",
);

const reviewedMigrations = [
  "20261113130000_allow_scoped_system_auth_audit",
  "20261113140000_retention_deletion_runtime_grants",
  "20261114110000_scope_retention_system_audit",
];

describe("Stage 3B2 reviewed staging migration contract", () => {
  it("requires the exact ordered three-migration target and explicit approval", () => {
    for (const migration of reviewedMigrations) {
      expect(preflight).toContain(`"${migration}"`);
      expect(runner).toContain(migration);
    }
    expect(preflight).toContain(
      'const EXPECTED_MIGRATION_TARGET = EXPECTED_MIGRATIONS.join(",")',
    );
    expect(preflight).toContain(
      'const APPROVAL_PHRASE = "YES_APPLY_20261113_14_STAGE3B2"',
    );
    expect(runner).toContain(
      'APPROVAL_PHRASE="YES_APPLY_20261113_14_STAGE3B2"',
    );
    expect(preflight).not.toContain("YES_APPLY_20261106010000_MODULES8_12");
    expect(runner).not.toContain("20261106010000_modules8_9_10_11_12_complete");
  });

  it("rejects every pending migration outside the reviewed Stage 3B2 set", () => {
    expect(preflight).toContain(
      "const unexpectedPending = pending.filter((name) => !EXPECTED_MIGRATIONS.includes(name))",
    );
    expect(preflight).toContain("if (unknownApplied.length > 0)");
    expect(preflight).toContain("if (unexpectedPending.length > 0)");
    expect(preflight).toContain("if (failed.length > 0)");
    expect(runner).toContain("node scripts/staging-preflight.cjs migrations");
    expect(runner).toContain("npm run db:migrate:deploy");
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
