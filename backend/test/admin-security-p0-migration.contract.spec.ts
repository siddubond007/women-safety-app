import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";

const migration = readFileSync(
  new URL(
    "../prisma/migrations/20261109230000_admin_security_baseline_p0/migration.sql",
    import.meta.url,
  ),
  "utf8",
);
const runtimeGrants = readFileSync(
  new URL("../prisma/staging/runtime-grants.sql", import.meta.url),
  "utf8",
);

describe("P0 managed staging role security contract", () => {
  it("preflights the staging role before the first schema mutation", () => {
    const preflight = migration.indexOf(
      "Validate the dedicated managed runtime principal before any schema changes.",
    );
    const firstSchemaMutation = migration.indexOf(
      "ALTER TABLE public.discreet_complaints",
    );
    expect(preflight).toBeGreaterThanOrEqual(0);
    expect(firstSchemaMutation).toBeGreaterThan(preflight);
    expect(migration).toContain("pg_auth_members");
    expect(migration).toContain("rolbypassrls");
    expect(migration).toContain("rolcreaterole");
  });

  it("does not attempt to alter the managed role in either migration path", () => {
    expect(migration).not.toMatch(/\bALTER\s+ROLE\s+sakhi_staging_app\b/i);
    expect(runtimeGrants).not.toMatch(/\bALTER\s+ROLE\s+sakhi_staging_app\b/i);
    expect(runtimeGrants).toContain("pg_auth_members");
  });

  it("validates the complete permissive runtime RLS policy definition", () => {
    for (const source of [migration, runtimeGrants]) {
      expect(source).toContain("permissive IS DISTINCT FROM 'PERMISSIVE'");
      expect(source).toContain("cmd IS DISTINCT FROM 'ALL'");
      expect(source).toContain(
        "roles IS DISTINCT FROM ARRAY['sakhi_staging_app']::name[]",
      );
      expect(source).toContain("COALESCE(qual, '') <> 'true'");
      expect(source).toContain("COALESCE(with_check, '') <> 'true'");
    }
  });

  it("rejects additional policies that apply to the runtime role or PUBLIC", () => {
    for (const source of [migration, runtimeGrants]) {
      expect(source).toContain(
        "roles && ARRAY['sakhi_staging_app', 'public']::name[]",
      );
    }
  });

  it("expires stale MFA recovery requests before applying the active-request unique index", () => {
    const expiryTransition = migration.indexOf("SET status = 'EXPIRED'");
    const duplicatePreflight = migration.indexOf("Multiple active MFA recovery requests exist");
    const activeIndex = migration.indexOf("CREATE UNIQUE INDEX IF NOT EXISTS admin_staff_recovery_one_active_per_staff_unique");
    expect(expiryTransition).toBeGreaterThan(0);
    expect(duplicatePreflight).toBeGreaterThan(expiryTransition);
    expect(activeIndex).toBeGreaterThan(duplicatePreflight);
    expect(migration).toContain("AND expires_at <= CURRENT_TIMESTAMP");
    expect(migration).toContain("WHERE status IN ('PENDING', 'APPROVED')");
  });

  it("revokes and postflights effective column-level service_role privileges", () => {
    expect(migration).toContain("REVOKE ALL PRIVILEGES (%s) ON TABLE public.%I FROM service_role");
    expect(migration).toContain("has_column_privilege('service_role', c.oid, a.attnum, 'SELECT')");
    expect(migration).toContain("has_column_privilege('service_role', c.oid, a.attnum, 'INSERT')");
    expect(migration).toContain("has_column_privilege('service_role', c.oid, a.attnum, 'UPDATE')");
    expect(migration).toContain("has_column_privilege('service_role', c.oid, a.attnum, 'REFERENCES')");
    for (const privilege of ["SELECT", "INSERT", "UPDATE", "DELETE", "TRUNCATE", "REFERENCES", "TRIGGER"]) {
      expect(migration).toContain(`has_table_privilege('service_role','public.admin_staff_mfa','${privilege}')`);
    }
  });

  it("accepts READ_ONLY_AUDITOR during existing-data preflight", () => {
    expect(migration).toContain("'BUSINESS_ADMIN','READ_ONLY_AUDITOR'");
    expect(migration).toContain("role IS NULL OR role NOT IN");
  });

  it("scopes actor/session foreign-key checks to the owning relation", () => {
    expect(migration).toContain(
      "conname = 'admin_staff_accounts_suspended_by_fkey'\n        AND conrelid = 'public.admin_staff_accounts'::regclass",
    );
    expect(migration).toContain(
      "conname = 'admin_staff_sessions_replaced_by_session_fkey'\n        AND conrelid = 'public.admin_staff_sessions'::regclass",
    );
  });
});
