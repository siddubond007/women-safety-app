import { Pool } from "pg";
import { afterAll, beforeAll, describe, expect, it } from "vitest";

const enabled = process.env.SAKHI_DB_INTEGRATION === "true";

describe.skipIf(!enabled)("staff MFA database boundary", () => {
  let pool: Pool | undefined;

  beforeAll(async () => {
    if (process.env.SAKHI_ENV !== "test" || process.env.NODE_ENV !== "test") {
      throw new Error(
        "Local MFA role-boundary verification requires SAKHI_ENV=test and NODE_ENV=test.",
      );
    }
    const appUrl = new URL(process.env.SAKHI_APP_DATABASE_URL ?? "");
    const migratorUrl = new URL(process.env.SAKHI_MIGRATOR_DATABASE_URL ?? "");
    if (
      appUrl.hostname !== "127.0.0.1" ||
      appUrl.pathname !== "/sakhi_test" ||
      migratorUrl.hostname !== appUrl.hostname ||
      migratorUrl.pathname !== appUrl.pathname ||
      migratorUrl.port !== appUrl.port
    ) {
      throw new Error(
        "Refusing staff MFA role-boundary verification outside the same local sakhi_test database.",
      );
    }
    pool = new Pool({
      connectionString: process.env.SAKHI_MIGRATOR_DATABASE_URL,
    });
  });

  afterAll(async () => {
    await pool?.end();
  });

  it("forces RLS and verifies the isolated test and staging runtime policies", async () => {
    const result = await pool!.query<{
      table_name: string;
      rls_enabled: boolean;
      rls_forced: boolean;
      test_role_policy: boolean;
      staging_role_policy: boolean;
    }>(
      `
      SELECT
        c.relname AS table_name,
        c.relrowsecurity AS rls_enabled,
        c.relforcerowsecurity AS rls_forced,
        EXISTS (
          SELECT 1 FROM pg_policies p
          WHERE p.schemaname='public'
            AND p.tablename=c.relname
            AND 'sakhi_test_app'=ANY(p.roles)
        ) AS test_role_policy,
        EXISTS (
          SELECT 1 FROM pg_policies p
          WHERE p.schemaname='public'
            AND p.tablename=c.relname
            AND 'sakhi_staging_app'=ANY(p.roles)
        ) AS staging_role_policy
      FROM pg_class c
      WHERE c.relnamespace='public'::regnamespace
        AND c.relname = ANY($1::text[])
      ORDER BY c.relname
    `,
      [
        [
          "admin_staff_accounts",
          "admin_staff_sessions",
          "admin_staff_mfa",
          "admin_staff_backup_codes",
          "admin_staff_recovery_requests",
        ],
      ],
    );

    expect(result.rows).toHaveLength(5);
    for (const row of result.rows) {
      expect(row).toMatchObject({
        rls_enabled: true,
        rls_forced: true,
        // The isolated CI harness explicitly creates this test-only policy
        // so its non-production application role can exercise these tables.
        test_role_policy: true,
        staging_role_policy: true,
      });
    }
  });
});
