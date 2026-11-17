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
    const migratorUrl = new URL(
      process.env.SAKHI_STAGING_MIGRATOR_DATABASE_URL ??
        process.env.SAKHI_MIGRATOR_DATABASE_URL ??
        "",
    );
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
      connectionString:
        process.env.SAKHI_STAGING_MIGRATOR_DATABASE_URL ??
        process.env.SAKHI_MIGRATOR_DATABASE_URL,
    });
  });

  afterAll(async () => {
    await pool?.end();
  });

  it("forces RLS, preserves app no-DELETE, and limits migrator cleanup to synthetic fixture rows", async () => {
    const result = await pool!.query<{
      table_name: string;
      rls_enabled: boolean;
      rls_forced: boolean;
      test_role_policy: boolean;
      staging_role_policy: boolean;
      migrator_cleanup_policy: boolean;
      app_can_delete: boolean;
      migrator_can_delete: boolean;
      migrator_can_select_whole_child_table: boolean;
      migrator_fixture_column_select: boolean;
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
        ) AS staging_role_policy,
        EXISTS (
          SELECT 1 FROM pg_policies p
          WHERE p.schemaname='public'
            AND p.tablename=c.relname
            AND 'sakhi_staging_migrator'=ANY(p.roles)
            AND p.cmd='DELETE'
            AND p.qual LIKE '%mfa-%@example.test%'
            AND p.qual LIKE '%SYN-MFA-%'
        ) AS migrator_cleanup_policy,
        has_table_privilege('sakhi_staging_app', c.oid, 'DELETE') AS app_can_delete,
        has_table_privilege('sakhi_staging_migrator', c.oid, 'DELETE') AS migrator_can_delete,
        CASE
          WHEN c.relname='admin_staff_accounts' THEN false
          ELSE has_table_privilege('sakhi_staging_migrator', c.oid, 'SELECT')
        END AS migrator_can_select_whole_child_table,
        CASE
          WHEN c.relname='admin_staff_accounts' THEN
            has_column_privilege('sakhi_staging_migrator', c.oid, 'id', 'SELECT')
            AND has_column_privilege('sakhi_staging_migrator', c.oid, 'email', 'SELECT')
            AND has_column_privilege('sakhi_staging_migrator', c.oid, 'staff_code', 'SELECT')
          ELSE has_column_privilege('sakhi_staging_migrator', c.oid, 'staff_id', 'SELECT')
        END AS migrator_fixture_column_select
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
        test_role_policy: true,
        staging_role_policy: true,
        migrator_cleanup_policy: true,
        app_can_delete: false,
        migrator_can_delete: true,
        migrator_fixture_column_select: true,
      });
      if (row.table_name !== "admin_staff_accounts") {
        expect(row.migrator_can_select_whole_child_table).toBe(false);
      }
    }

    const role = await pool!.query<{ rolsuper: boolean; rolbypassrls: boolean }>(
      "SELECT rolsuper, rolbypassrls FROM pg_roles WHERE rolname='sakhi_staging_migrator'",
    );
    expect(role.rows).toEqual([{ rolsuper: false, rolbypassrls: false }]);

    const policyCount = await pool!.query<{ count: number }>(
      `
      SELECT count(*)::int AS count
      FROM pg_policies
      WHERE schemaname='public'
        AND tablename = ANY($1::text[])
        AND 'sakhi_staging_migrator'=ANY(roles)
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
    // Two narrowly scoped account policies (SELECT + DELETE), plus one
    // synthetic-fixture-only DELETE policy for each child table.
    expect(policyCount.rows[0]?.count).toBe(6);
  });
});
