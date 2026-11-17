import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";

const migration = readFileSync(
  new URL(
    "../prisma/migrations/20261117150000_staging_mfa_fixture_cleanup_role/migration.sql",
    import.meta.url,
  ),
  "utf8",
);

describe("staging synthetic MFA fixture-cleanup role migration contract", () => {
  it("requires a restricted login role with no role memberships or object ownership", () => {
    expect(migration).toContain("sakhi_staging_fixture_cleanup");
    expect(migration).toContain("rolcanlogin");
    expect(migration).toContain("NOT rolsuper");
    expect(migration).toContain("NOT rolbypassrls");
    expect(migration).toContain("NOT rolcreatedb");
    expect(migration).toContain("NOT rolcreaterole");
    expect(migration).toContain("NOT rolreplication");
    expect(migration).toContain("WHERE member = cleanup_role OR roleid = cleanup_role");
    expect(migration).toContain("c.relowner = cleanup_role");
  });

  it("grants only fixture-cleanup column reads and row-filtered deletes", () => {
    expect(migration).toContain(
      "GRANT SELECT (id, email, staff_code)",
    );
    expect(migration).toContain("GRANT SELECT (staff_id)");
    expect(migration).toContain("GRANT DELETE ON TABLE");
    expect(migration).toContain("mfa-%@example.test");
    expect(migration).toContain("SYN-MFA-%");
    expect(migration).toContain("FOR SELECT TO sakhi_staging_fixture_cleanup");
    expect(migration).toContain("FOR DELETE TO sakhi_staging_fixture_cleanup");
    expect(migration).not.toMatch(/GRANT\s+TRUNCATE/i);
    expect(migration).not.toMatch(/GRANT\s+SELECT\s+ON\s+TABLE\s+public\.admin_staff_(sessions|mfa|backup_codes|recovery_requests)/i);
  });

  it("fails closed if the cleanup role can own or truncate protected staff tables", () => {
    expect(migration).toContain(
      "has_table_privilege(cleanup_role,c.oid,'TRUNCATE')",
    );
    expect(migration).toContain("must not own or truncate P0 staff-security tables");
    expect(migration).toContain("NOT c.relrowsecurity OR NOT c.relforcerowsecurity");
  });
});
