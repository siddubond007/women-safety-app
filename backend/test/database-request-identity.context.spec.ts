import { describe, expect, it } from "vitest";
import {
  databaseRequestIdentityStorage,
  runWithDatabaseRequestIdentity,
  setAdminDatabaseIdentity,
  setMemberDatabaseIdentity,
} from "../src/database/database-request-identity.context.js";

describe("database request identity context", () => {
  it("keeps member identity scoped to one request and clears it afterwards", async () => {
    await runWithDatabaseRequestIdentity(async () => {
      setMemberDatabaseIdentity("2f6f7fa1-8c5c-4bb0-ae1a-0f7e3a2e5a41", "4b1f7f84-2f0d-4f39-8bd9-73ac2a7763a1");
      expect(databaseRequestIdentityStorage.getStore()).toMatchObject({
        accountId: "2f6f7fa1-8c5c-4bb0-ae1a-0f7e3a2e5a41",
        sessionId: "4b1f7f84-2f0d-4f39-8bd9-73ac2a7763a1",
      });
    });
    expect(databaseRequestIdentityStorage.getStore()).toBeUndefined();
  });

  it("isolates concurrent requests for different synthetic members", async () => {
    const [first, second] = await Promise.all([
      runWithDatabaseRequestIdentity(async () => {
        setMemberDatabaseIdentity("11111111-1111-4111-8111-111111111111", "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa");
        await Promise.resolve();
        return databaseRequestIdentityStorage.getStore()?.accountId;
      }),
      runWithDatabaseRequestIdentity(async () => {
        setMemberDatabaseIdentity("22222222-2222-4222-8222-222222222222", "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb");
        await Promise.resolve();
        return databaseRequestIdentityStorage.getStore()?.accountId;
      }),
    ]);
    expect(first).toBe("11111111-1111-4111-8111-111111111111");
    expect(second).toBe("22222222-2222-4222-8222-222222222222");
  });

  it("replaces member identity with the validated admin identity", async () => {
    await runWithDatabaseRequestIdentity(() => {
      setMemberDatabaseIdentity("11111111-1111-4111-8111-111111111111", "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa");
      setAdminDatabaseIdentity("33333333-3333-4333-8333-333333333333", "CONTENT_MODERATOR");
      expect(databaseRequestIdentityStorage.getStore()).toMatchObject({
        adminStaffId: "33333333-3333-4333-8333-333333333333",
        adminRole: "CONTENT_MODERATOR",
        accountId: undefined,
        sessionId: undefined,
      });
    });
  });
});
