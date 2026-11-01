import { describe, expect, it, vi } from "vitest";
import { AuthenticationService } from "../src/auth/auth.service.js";
import { PrismaService } from "../src/database/prisma.service.js";
import { Module2Service } from "../src/module2/module2.service.js";

function createService(
  accountId: string,
  events: Array<{ redactedMetadata: Record<string, unknown> | null }>,
  username = "@viewer",
) {
  const auth = {
    authenticateAuthorization: vi.fn().mockResolvedValue({
      accountId,
      account: { status: "ACTIVE", verificationStatus: "VERIFIED" },
    }),
  };
  const prisma = {
    auditEvent: {
      findMany: vi.fn().mockResolvedValue(events),
    },
    memberProfile: {
      findUnique: vi.fn().mockResolvedValue({ username }),
    },
  };
  return new Module2Service(
    auth as unknown as AuthenticationService,
    prisma as unknown as PrismaService,
  );
}

describe("Module 2 direct-message participant access", () => {
  it("does not reveal a conversation merely because peerId matches one participant", async () => {
    const service = createService("unrelated-viewer", [
      {
        redactedMetadata: {
          id: "dm-private-1",
          senderAccountId: "sender-1",
          recipientId: "target-peer",
          recipientHandle: "",
          body: "Private conversation",
        },
      },
    ]);

    const result = await service.listDirectMessages(
      "Bearer viewer-token",
      "target-peer",
    );

    expect(result.items).toEqual([]);
    expect(result.messages).toEqual([]);
  });

  it("returns only the authenticated member's messages with the requested peer", async () => {
    const service = createService("viewer-account", [
      {
        redactedMetadata: {
          id: "dm-owned-1",
          senderAccountId: "viewer-account",
          recipientId: "peer-account",
          recipientHandle: "@peer",
          body: "Visible to viewer",
        },
      },
      {
        redactedMetadata: {
          id: "dm-not-owned-1",
          senderAccountId: "other-account",
          recipientId: "peer-account",
          recipientHandle: "@peer",
          body: "Not visible to viewer",
        },
      },
    ]);

    const result = await service.listDirectMessages(
      "Bearer viewer-token",
      "peer-account",
    );

    expect(result.items.map((message) => message.id)).toEqual(["dm-owned-1"]);
    expect(result.items[0]?.isOwnMessage).toBe(true);
  });

  it("recognizes the authenticated member as recipient when the message was addressed by handle", async () => {
    const service = createService("viewer-account", [
      {
        redactedMetadata: {
          id: "dm-to-handle",
          senderAccountId: "sender-account",
          recipientId: "@viewer",
          recipientHandle: "@viewer",
          body: "Addressed to viewer",
        },
      },
    ]);

    const result = await service.listDirectMessages(
      "Bearer viewer-token",
      "sender-account",
    );

    expect(result.items.map((message) => message.id)).toEqual(["dm-to-handle"]);
    expect(result.items[0]?.isOwnMessage).toBe(false);
  });

  it("does not treat a secondary recipient handle as proof of recipient identity", async () => {
    const service = createService("viewer-account", [
      {
        redactedMetadata: {
          id: "dm-mismatched-recipient",
          senderAccountId: "sender-account",
          recipientId: "different-account",
          recipientHandle: "@viewer",
          body: "Must not be exposed by a display handle",
        },
      },
    ]);

    const result = await service.listDirectMessages(
      "Bearer viewer-token",
      "sender-account",
    );

    expect(result.items).toEqual([]);
    expect(result.messages).toEqual([]);
  });
});
