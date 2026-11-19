import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";

const schema = readFileSync(
  new URL("../prisma/schema.prisma", import.meta.url),
  "utf8",
);
const migration = readFileSync(
  new URL(
    "../prisma/migrations/20261118130000_remove_legacy_admin_mfa_flag/migration.sql",
    import.meta.url,
  ),
  "utf8",
);
const mfaService = readFileSync(
  new URL("../src/admin-security/admin-mfa.service.ts", import.meta.url),
  "utf8",
);
const sessionService = readFileSync(
  new URL("../src/admin-security/admin-session.service.ts", import.meta.url),
  "utf8",
);

describe("authoritative admin MFA state migration contract", () => {
  it("removes the redundant account-level flag from the Prisma model", () => {
    const accountModel = schema.match(
      /model AdminStaffAccount \{([\s\S]*?)\n\}/,
    )?.[1];

    expect(accountModel).toBeTruthy();
    expect(accountModel).not.toMatch(/\bmfaEnabled\b|mfa_enabled/);
    expect(schema).toContain("model AdminStaffMfa {");
    expect(schema).toMatch(
      /enrollmentVerifiedAt\s+DateTime\?\s+@map\("enrollment_verified_at"\)/,
    );
    expect(schema).toMatch(/disabledAt\s+DateTime\?\s+@map\("disabled_at"\)/);
  });

  it("checks the authoritative MFA columns before dropping only the legacy flag", () => {
    expect(migration).toContain("public.admin_staff_accounts");
    expect(migration).toContain("public.admin_staff_mfa");
    expect(migration).toContain("enrollment_verified_at");
    expect(migration).toContain("disabled_at");
    expect(migration).toMatch(
      /ALTER TABLE public\.admin_staff_accounts\s+DROP COLUMN IF EXISTS mfa_enabled;/,
    );
    expect(migration).not.toMatch(
      /DROP COLUMN IF EXISTS mfa_enabled\s+CASCADE/i,
    );
    expect(migration).not.toMatch(/\bUPDATE\s+public\.admin_staff_mfa\b/i);
    expect(migration).not.toMatch(
      /\bDELETE\s+FROM\s+public\.admin_staff_(mfa|backup_codes)/i,
    );
  });

  it("leaves TOTP enrollment, replay prevention, recovery codes, and audit records as the authoritative path", () => {
    expect(schema).toContain("model AdminStaffMfa {");
    expect(schema).toContain("lastAcceptedTimeStep");
    expect(schema).toContain("model AdminStaffBackupCode {");
    expect(schema).toContain("model AuditEvent {");
    expect(migration).not.toMatch(/DROP\s+TABLE|TRUNCATE|DELETE\s+FROM/i);
  });

  it("continues to enforce MFA through the verified MFA record, not the removed legacy flag", () => {
    expect(mfaService).toContain("enrollmentVerifiedAt: new Date()");
    expect(mfaService).toContain(
      "!record.enrollmentVerifiedAt || record.disabledAt",
    );
    expect(sessionService).toContain(
      "!mfa?.enrollmentVerifiedAt || mfa.disabledAt",
    );
    expect(mfaService).not.toMatch(/\bmfaEnabled\b|mfa_enabled/);
    expect(sessionService).not.toMatch(/\bmfaEnabled\b|mfa_enabled/);
  });
});
