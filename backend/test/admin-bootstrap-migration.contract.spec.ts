import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";

const migration = readFileSync(
  new URL(
    "../prisma/migrations/20261117140000_single_use_admin_bootstrap_credential/migration.sql",
    import.meta.url,
  ),
  "utf8",
);

describe("single-use initial Super Admin bootstrap migration contract", () => {
  it("stores only a singleton SHA-256 digest with an expiry and consumption timestamp", () => {
    expect(migration).toContain("CREATE TABLE public.admin_bootstrap_credentials");
    expect(migration).toContain("token_digest varchar(64) NOT NULL");
    expect(migration).toContain("expires_at timestamptz(6) NOT NULL");
    expect(migration).toContain("consumed_at timestamptz(6)");
    expect(migration).toContain("token_digest ~ '^[0-9a-f]{64}$'");
    expect(migration).toContain("id = 'initial-super-admin'");
  });

  it("enables and forces RLS and grants no access to public client roles or service_role", () => {
    expect(migration).toContain("ENABLE ROW LEVEL SECURITY");
    expect(migration).toContain("FORCE ROW LEVEL SECURITY");
    expect(migration).toContain(
      "FROM PUBLIC, anon, authenticated, service_role",
    );
    expect(migration).toContain(
      "GRANT SELECT, INSERT, UPDATE ON TABLE public.admin_bootstrap_credentials TO sakhi_staging_app",
    );
    expect(migration).toContain(
      "has_table_privilege('service_role', 'public.admin_bootstrap_credentials', 'DELETE')",
    );
  });

  it("permits only an unconsumed, unexpired credential to be inserted or consumed", () => {
    expect(migration).toContain("consumed_at IS NULL");
    expect(migration).toContain("expires_at > now()");
    expect(migration).toContain("consumed_at IS NOT NULL");
    expect(migration).toContain("FOR UPDATE TO sakhi_staging_app");
  });

  it("makes credential digest, expiry and consumption immutable after the first use", () => {
    expect(migration).toContain(
      "guard_admin_bootstrap_credential_consumption",
    );
    expect(migration).toContain(
      "OLD.token_digest IS DISTINCT FROM NEW.token_digest",
    );
    expect(migration).toContain(
      "OLD.expires_at IS DISTINCT FROM NEW.expires_at",
    );
    expect(migration).toContain("OLD.consumed_at IS NOT NULL");
    expect(migration).toContain(
      "admin_bootstrap_credentials_one_way_consumption",
    );
  });
});
