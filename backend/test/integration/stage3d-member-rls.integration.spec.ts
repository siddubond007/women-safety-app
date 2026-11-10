import { describe, expect, it } from "vitest";
import { Client } from "pg";

const connectionString = process.env.SAKHI_STAGE3D_RLS_TEST_URL;
const enabled = Boolean(connectionString);
const accountA = "11111111-1111-4111-8111-111111111111";
const accountB = "22222222-2222-4222-8222-222222222222";

const protectedTables = [
  {
    name: "menstrual_cycle_logs",
    insert:
      "insert into public.menstrual_cycle_logs(id,account_id,start_date) values ('cccccccc-cccc-4ccc-8ccc-cccccccccccc',$1,'2026-03-01')",
    update:
      "update public.menstrual_cycle_logs set flow_intensity='LIGHT' where account_id=$1",
  },
  {
    name: "menstrual_daily_logs",
    insert:
      "insert into public.menstrual_daily_logs(id,account_id,log_date) values ('dddddddd-dddd-4ddd-8ddd-dddddddddddd',$1,'2026-03-01')",
    update:
      "update public.menstrual_daily_logs set cramps_severity='MILD' where account_id=$1",
  },
  {
    name: "menstrual_tracker_preferences",
    insert:
      "insert into public.menstrual_tracker_preferences(account_id) values ($1)",
    update:
      "update public.menstrual_tracker_preferences set default_cycle_length=30 where account_id=$1",
  },
] as const;

describe.skipIf(!enabled)("Stage 3D PostgreSQL member RLS contract", () => {
  it("enforces the applied migration across all three protected tables and resets transaction identity", async () => {
    const client = new Client({ connectionString });
    await client.connect();
    try {
      const who = await client.query<{ current_user: string }>(
        "select current_user",
      );
      expect(who.rows[0]?.current_user).toBe("sakhi_test_app");

      for (const table of protectedTables) {
        await client.query("begin");
        await client.query("select set_config('app.account_id', $1, true)", [
          accountA,
        ]);
        const own = await client.query(
          `select account_id from public.${table.name}`,
        );
        expect(own.rows.map((row) => row.account_id)).toEqual([accountA]);

        await client.query("savepoint before_cross_account_insert");
        await expect(
          client.query(table.insert, [accountB]),
        ).rejects.toMatchObject({ code: "42501" });
        await client.query("rollback to savepoint before_cross_account_insert");

        await client.query(table.update, [accountB]);
        const bAfterUpdate = await client.query(
          `select 1 from public.${table.name} where account_id=$1`,
          [accountB],
        );
        expect(bAfterUpdate.rowCount).toBe(0);
        await client.query(
          `delete from public.${table.name} where account_id=$1`,
          [accountB],
        );
        const bAfterDelete = await client.query(
          `select 1 from public.${table.name} where account_id=$1`,
          [accountB],
        );
        expect(bAfterDelete.rowCount).toBe(0);
        await client.query("commit");

        await client.query("begin");
        const missing = await client.query(
          `select account_id from public.${table.name}`,
        );
        expect(missing.rowCount).toBe(0);
        await client.query("rollback");

        await client.query("begin");
        await client.query("select set_config('app.account_id', $1, true)", [
          accountB,
        ]);
        const onlyB = await client.query(
          `select account_id from public.${table.name}`,
        );
        expect(onlyB.rows.map((row) => row.account_id)).toEqual([accountB]);
        await client.query("rollback");
      }
    } finally {
      await client.end();
    }
  });
});
