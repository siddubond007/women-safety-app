import { describe, expect, it, vi } from "vitest";
import { AuthenticationService } from "../src/auth/auth.service.js";
import { PrismaService } from "../src/database/prisma.service.js";
import { Module2Service } from "../src/module2/module2.service.js";

type MessageRow = {
  id: string;
  senderAccountId: string;
  recipientAccountId: string;
  senderDirectoryProfileId: string | null;
  recipientDirectoryProfileId: string | null;
  senderName: string;
  senderUsername: string;
  senderAvatar: string | null;
  recipientName: string;
  recipientHandle: string;
  body: string;
  createdAt: Date;
};

type HarnessOptions = {
  peerProfile?: { accountId: string } | null;
  accountIdLookup?: string;
  directoryProfile?: { username: string } | null;
  directoryId?: string;
  username?: string;
};

function createService(
  accountId: string,
  rows: MessageRow[],
  options: HarnessOptions = {},
) {
  const auth = {
    authenticateAuthorization: vi.fn().mockResolvedValue({
      accountId,
      account: { status: "ACTIVE", verificationStatus: "VERIFIED" },
    }),
  };
  const directoryFindUnique = vi
    .fn()
    .mockImplementation(({ where }) =>
      options.directoryProfile && where.id === options.directoryId
        ? Promise.resolve(options.directoryProfile)
        : Promise.resolve(null),
    );
  const memberProfile = {
    findUnique: vi.fn().mockImplementation(({ where }) => {
      if (where.accountId === accountId) {
        return Promise.resolve({ username: options.username ?? "@viewer" });
      }
      if (where.accountId === options.accountIdLookup) {
        return Promise.resolve(options.peerProfile ?? null);
      }
      return Promise.resolve(null);
    }),
    findFirst: vi.fn().mockResolvedValue(options.peerProfile ?? null),
  };
  const findMessages = vi.fn().mockResolvedValue(rows);
  const prisma = {
    communityDirectoryProfile: {
      findUnique: directoryFindUnique,
    },
    memberProfile,
    directMessage: {
      findMany: findMessages,
    },
  };
  const service = new Module2Service(
    auth as unknown as AuthenticationService,
    prisma as unknown as PrismaService,
  );
  return { service, prisma, findMessages, directoryFindUnique, memberProfile };
}

function message(
  id: string,
  senderAccountId: string,
  recipientAccountId: string,
  createdAt = new Date("2026-10-31T10:00:00.000Z"),
): MessageRow {
  return {
    id,
    senderAccountId,
    recipientAccountId,
    senderDirectoryProfileId: null,
    recipientDirectoryProfileId: null,
    senderName: senderAccountId === "viewer-account" ? "Viewer" : "Peer",
    senderUsername: senderAccountId === "viewer-account" ? "@viewer" : "@peer",
    senderAvatar: null,
    recipientName: recipientAccountId === "viewer-account" ? "Viewer" : "Peer",
    recipientHandle:
      recipientAccountId === "viewer-account" ? "@viewer" : "@peer",
    body: `message ${id}`,
    createdAt,
  };
}

describe("Module 2 direct-message participant access", () => {
  it("does not query a conversation when the requested peer cannot be resolved", async () => {
    const harness = createService("viewer-account", [], {
      peerProfile: null,
    });

    const result = await harness.service.listDirectMessages(
      "Bearer viewer-token",
      "unknown-peer",
    );

    expect(result.items).toEqual([]);
    expect(result.messages).toEqual([]);
    expect(harness.findMessages).not.toHaveBeenCalled();
  });

  it("queries only the two authenticated participant directions for a peer account", async () => {
    const harness = createService(
      "viewer-account",
      [message("dm-owned-1", "viewer-account", "peer-account")],
      {
        peerProfile: { accountId: "peer-account" },
      },
    );

    const result = await harness.service.listDirectMessages(
      "Bearer viewer-token",
      "peer-handle",
    );

    expect(result.items.map((item) => item.id)).toEqual(["dm-owned-1"]);
    expect(result.items[0]?.isOwnMessage).toBe(true);
    expect(harness.findMessages).toHaveBeenCalledWith({
      where: {
        OR: [
          {
            senderAccountId: "viewer-account",
            recipientAccountId: "peer-account",
          },
          {
            senderAccountId: "peer-account",
            recipientAccountId: "viewer-account",
          },
        ],
      },
      orderBy: { createdAt: "desc" },
      take: 250,
    });
  });

  it("resolves a peer account UUID when no directory profile matches", async () => {
    const accountId = "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb";
    const harness = createService("viewer-account", [], {
      accountIdLookup: accountId,
      peerProfile: { accountId },
    });

    const result = await harness.service.listDirectMessages(
      "Bearer viewer-token",
      accountId,
    );

    expect(result.items).toEqual([]);
    expect(harness.memberProfile.findUnique).toHaveBeenCalledWith({
      where: { accountId },
      select: { accountId: true, displayName: true, username: true },
    });
    expect(harness.findMessages).toHaveBeenCalledWith(
      expect.objectContaining({
        where: {
          OR: [
            {
              senderAccountId: "viewer-account",
              recipientAccountId: accountId,
            },
            {
              senderAccountId: accountId,
              recipientAccountId: "viewer-account",
            },
          ],
        },
      }),
    );
  });
  it("resolves a directory-profile UUID to the peer account before querying", async () => {
    const directoryId = "cccccccc-cccc-4ccc-8ccc-cccccccccccc";
    const harness = createService("viewer-account", [], {
      directoryId,
      directoryProfile: { username: "@peer" },
      peerProfile: { accountId: "peer-account" },
    });

    const result = await harness.service.listDirectMessages(
      "Bearer viewer-token",
      directoryId,
    );

    expect(result.items).toEqual([]);
    expect(harness.directoryFindUnique).toHaveBeenCalledWith({
      where: { id: directoryId },
      select: { id: true, name: true, username: true },
    });
    expect(harness.findMessages).toHaveBeenCalledWith(
      expect.objectContaining({
        where: {
          OR: [
            {
              senderAccountId: "viewer-account",
              recipientAccountId: "peer-account",
            },
            {
              senderAccountId: "peer-account",
              recipientAccountId: "viewer-account",
            },
          ],
        },
      }),
    );
  });

  it("recognizes the authenticated member as recipient for incoming messages", async () => {
    const harness = createService(
      "viewer-account",
      [message("dm-incoming-1", "peer-account", "viewer-account")],
      {
        peerProfile: { accountId: "peer-account" },
      },
    );

    const result = await harness.service.listDirectMessages(
      "Bearer viewer-token",
      "peer-handle",
    );

    expect(result.items.map((item) => item.id)).toEqual(["dm-incoming-1"]);
    expect(result.items[0]?.isOwnMessage).toBe(false);
    expect(result.items[0]?.body).toBe("message dm-incoming-1");
  });

  it("lists only the authenticated account's messages when peerId is omitted", async () => {
    const harness = createService("viewer-account", [
      message("dm-own-1", "viewer-account", "peer-account"),
    ]);

    const result = await harness.service.listDirectMessages(
      "Bearer viewer-token",
    );

    expect(result.items).toHaveLength(1);
    expect(harness.findMessages).toHaveBeenCalledWith({
      where: {
        OR: [
          { senderAccountId: "viewer-account" },
          { recipientAccountId: "viewer-account" },
        ],
      },
      orderBy: { createdAt: "desc" },
      take: 250,
    });
  });

  it("returns the latest 250 messages in chronological display order", async () => {
    const newestFirst = Array.from({ length: 250 }, (_, index) => {
      const sequence = 250 - index;
      return message(
        `dm-${sequence}`,
        "viewer-account",
        "peer-account",
        new Date(Date.UTC(2026, 9, 31, 10, sequence)),
      );
    });
    const harness = createService("viewer-account", newestFirst);

    const result = await harness.service.listDirectMessages(
      "Bearer viewer-token",
    );

    expect(result.items).toHaveLength(250);
    expect(result.items[0]?.id).toBe("dm-1");
    expect(result.items[249]?.id).toBe("dm-250");
  });
});
