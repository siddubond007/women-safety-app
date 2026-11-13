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
