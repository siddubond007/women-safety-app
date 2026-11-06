import {
  BadRequestException,
  ForbiddenException,
  InternalServerErrorException,
  NotFoundException,
} from "@nestjs/common";
import { describe, expect, it, vi } from "vitest";
import { AuthenticationService } from "../src/auth/auth.service.js";
import { PrismaService } from "../src/database/prisma.service.js";
import { Module2Service } from "../src/module2/module2.service.js";

type HarnessOptions = {
  messageMe?: string;
  recipientStatus?: string;
  recipientVerificationStatus?: string;
  senderVerificationStatus?: string;
  followsRecipient?: boolean;
  recipientFollowsSender?: boolean;
  senderBlocksRecipient?: boolean;
  recipientBlocksSender?: boolean;
  recipientDirectoryFound?: boolean;
  recipientProfileFound?: boolean;
  directMessageCreateFails?: boolean;
  directMessageDelegateAvailable?: boolean;
  auditCreateFails?: boolean;
};

function createHarness(options: HarnessOptions = {}) {
  const recipientDirectory = {
    id: "cccccccc-cccc-4ccc-8ccc-cccccccccccc",
    username: "@recipient",
  };
  const senderDirectory = {
    id: "dddddddd-dddd-4ddd-8ddd-dddddddddddd",
    username: "@sender",
  };
  const senderProfile = {
    accountId: "sender-account",
    displayName: "Actual Sender",
    username: "@sender",
    avatarAsset: "",
    avatarMediaAssetId: null,
  };
  const recipientProfile = {
    accountId: "recipient-account",
    displayName: "Actual Recipient",
    username: "@recipient",
    avatarAsset: "",
    avatarMediaAssetId: null,
    account: {
      id: "recipient-account",
      status: options.recipientStatus ?? "ACTIVE",
      verificationStatus: options.recipientVerificationStatus ?? "VERIFIED",
      privacyPreference: {
        messageMe: options.messageMe ?? "All Verified Members",
      },
    },
  };
  const auth = {
    authenticateAuthorization: vi.fn().mockResolvedValue({
      accountId: "sender-account",
      account: {
        status: "ACTIVE",
        verificationStatus: options.senderVerificationStatus ?? "VERIFIED",
      },
    }),
  };
  const auditCreate = vi.fn().mockResolvedValue({ id: "audit-1" });
  if (options.auditCreateFails) {
    auditCreate.mockRejectedValue(new Error("audit write failed"));
  }
  const directMessageCreate = vi.fn().mockImplementation(({ data }) => {
    if (options.directMessageCreateFails) {
      return Promise.reject(new Error("message write failed"));
    }
    return Promise.resolve(data);
  });
  const followFindUnique = vi.fn().mockImplementation(({ where }) => {
    const accountId =
      where.accountId_directoryProfileId?.accountId ?? where.accountId;
    if (accountId === "sender-account") {
      return Promise.resolve(
        options.followsRecipient === false ? null : { isFollowing: true },
      );
    }
    if (accountId === "recipient-account") {
      return Promise.resolve(
        options.recipientFollowsSender === true ? { isFollowing: true } : null,
      );
    }
    return Promise.resolve(null);
  });
  const blockFindFirst = vi.fn().mockImplementation(({ where }) => {
    if (where.accountId === "sender-account" && options.senderBlocksRecipient) {
      return Promise.resolve({ id: "sender-block-1" });
    }
    if (
      where.accountId === "recipient-account" &&
      options.recipientBlocksSender
    ) {
      return Promise.resolve({ id: "recipient-block-1" });
    }
    return Promise.resolve(null);
  });
  const prisma = {
    communityDirectoryProfile: {
      findUnique: vi
        .fn()
        .mockImplementation(({ where }) =>
          where.id === recipientDirectory.id &&
          options.recipientDirectoryFound !== false
            ? Promise.resolve(recipientDirectory)
            : Promise.resolve(null),
        ),
      findFirst: vi
        .fn()
        .mockImplementation(({ where }) =>
          where.username.equals.toLowerCase() === "@recipient"
            ? Promise.resolve(recipientDirectory)
            : Promise.resolve(senderDirectory),
        ),
    },
    memberProfile: {
      findUnique: vi
        .fn()
        .mockImplementation(({ where }) =>
          where.accountId === "sender-account"
            ? Promise.resolve(senderProfile)
            : Promise.resolve(
                options.recipientProfileFound === false
                  ? null
                  : recipientProfile,
              ),
        ),
      findFirst: vi
        .fn()
        .mockResolvedValue(
          options.recipientProfileFound === false ? null : recipientProfile,
        ),
    },
    memberFollow: {
      findUnique: followFindUnique,
    },
    memberModerationBlock: {
      findFirst: blockFindFirst,
    },
    directMessage:
      options.directMessageDelegateAvailable === false
        ? undefined
        : {
            create: directMessageCreate,
            findFirst: vi.fn().mockResolvedValue(null),
          },
    auditEvent: {
      create: auditCreate,
    },
  };
  const service = new Module2Service(
    auth as unknown as AuthenticationService,
    prisma as unknown as PrismaService,
  );
  return {
    service,
    prisma,
    auditCreate,
    directMessageCreate,
    followFindUnique,
  };
}

const request = {
  recipientId: "cccccccc-cccc-4ccc-8ccc-cccccccccccc",
  recipientHandle: "@recipient",
  recipientName: "Client-supplied fake name",
  message: "  Hello from Sakhi  ",
};

describe("Module 2 direct-message recipient authorization and persistence", () => {
  it("resolves the directory ID to the real recipient and stores a dedicated message row", async () => {
    const harness = createHarness();

    const result = await harness.service.sendDirectMessage(
      "Bearer test-token",
      request,
    );

    expect(result.sent).toBe(true);
    expect(result.message.recipientId).toBe(
      "cccccccc-cccc-4ccc-8ccc-cccccccccccc",
    );
    expect(result.message.recipientAccountId).toBe("recipient-account");
    expect(result.message.recipientDirectoryProfileId).toBe(
      "cccccccc-cccc-4ccc-8ccc-cccccccccccc",
    );
    expect(result.message.recipientName).toBe("Actual Recipient");
    expect(result.message.body).toBe("Hello from Sakhi");
    expect(harness.directMessageCreate).toHaveBeenCalledOnce();
    expect(harness.directMessageCreate).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          senderAccountId: "sender-account",
          recipientAccountId: "recipient-account",
          body: "Hello from Sakhi",
        }),
      }),
    );
  });

  it("writes only content-free metadata to the audit trail", async () => {
    const harness = createHarness();
    const result = await harness.service.sendDirectMessage(
      "Bearer test-token",
      request,
    );

    expect(harness.auditCreate).toHaveBeenCalledOnce();
    const auditCall = harness.auditCreate.mock.calls[0]?.[0];
    expect(auditCall.data.action).toBe("module3.direct_message.persisted");
    expect(auditCall.data.redactedMetadata).toEqual({
      messageId: result.message.id,
      recipientAccountId: "recipient-account",
      hasAttachment: false,
      requestStatus: "PENDING_REQUEST",
    });
    expect(auditCall.data.redactedMetadata).not.toHaveProperty("body");
  });

  it("rejects an unknown recipient instead of accepting the client-supplied name", async () => {
    const harness = createHarness({
      recipientDirectoryFound: false,
      recipientProfileFound: false,
    });

    await expect(
      harness.service.sendDirectMessage("Bearer test-token", request),
    ).rejects.toBeInstanceOf(NotFoundException);
    expect(harness.directMessageCreate).not.toHaveBeenCalled();
  });

  it("rejects a recipient ID and username that resolve to different members", async () => {
    const harness = createHarness();

    await expect(
      harness.service.sendDirectMessage("Bearer test-token", {
        ...request,
        recipientHandle: "@someone-else",
      }),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(harness.directMessageCreate).not.toHaveBeenCalled();
  });

  it("rejects recipients who are not active and verified", async () => {
    const inactive = createHarness({ recipientStatus: "SUSPENDED" });
    await expect(
      inactive.service.sendDirectMessage("Bearer test-token", request),
    ).rejects.toBeInstanceOf(ForbiddenException);

    const unverified = createHarness({
      recipientVerificationStatus: "UNVERIFIED",
    });
    await expect(
      unverified.service.sendDirectMessage("Bearer test-token", request),
    ).rejects.toBeInstanceOf(ForbiddenException);

    expect(inactive.directMessageCreate).not.toHaveBeenCalled();
    expect(unverified.directMessageCreate).not.toHaveBeenCalled();
  });

  it("rejects senders who are not verified members", async () => {
    const harness = createHarness({ senderVerificationStatus: "UNVERIFIED" });

    await expect(
      harness.service.sendDirectMessage("Bearer test-token", request),
    ).rejects.toBeInstanceOf(ForbiddenException);
    expect(harness.directMessageCreate).not.toHaveBeenCalled();
  });

  it("puts first-time senders into Message Requests until the recipient follows or accepts them", async () => {
    const unknownSender = createHarness();
    const pending = await unknownSender.service.sendDirectMessage(
      "Bearer test-token",
      request,
    );
    expect(pending.message.requestStatus).toBe("PENDING_REQUEST");

    const knownSender = createHarness({ recipientFollowsSender: true });
    const accepted = await knownSender.service.sendDirectMessage(
      "Bearer test-token",
      request,
    );
    expect(accepted.message.requestStatus).toBe("ACCEPTED");
  });

  it("honors the recipient's No One messaging preference", async () => {
    const harness = createHarness({ messageMe: "No One" });

    await expect(
      harness.service.sendDirectMessage("Bearer test-token", request),
    ).rejects.toBeInstanceOf(ForbiddenException);
    expect(harness.directMessageCreate).not.toHaveBeenCalled();
  });

  it("requires an active follow when the recipient selects Followers Only", async () => {
    const notFollowing = createHarness({
      messageMe: "Followers Only",
      followsRecipient: false,
    });

    await expect(
      notFollowing.service.sendDirectMessage("Bearer test-token", request),
    ).rejects.toBeInstanceOf(ForbiddenException);
    expect(notFollowing.followFindUnique).toHaveBeenCalledOnce();
    expect(notFollowing.directMessageCreate).not.toHaveBeenCalled();

    const following = createHarness({
      messageMe: "Followers Only",
      followsRecipient: true,
    });
    const result = await following.service.sendDirectMessage(
      "Bearer test-token",
      request,
    );
    expect(result.sent).toBe(true);
    expect(following.directMessageCreate).toHaveBeenCalledOnce();
  });

  it("blocks direct messages when either member has blocked the other", async () => {
    for (const options of [
      { senderBlocksRecipient: true },
      { recipientBlocksSender: true },
    ]) {
      const harness = createHarness(options);

      await expect(
        harness.service.sendDirectMessage("Bearer test-token", request),
      ).rejects.toBeInstanceOf(ForbiddenException);
      expect(harness.directMessageCreate).not.toHaveBeenCalled();
    }
  });

  it("resolves a recipient account UUID when the caller has no directory key", async () => {
    const harness = createHarness();

    const result = await harness.service.sendDirectMessage(
      "Bearer test-token",
      {
        ...request,
        recipientId: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb",
      },
    );

    expect(result.message.recipientAccountId).toBe("recipient-account");
    expect(harness.directMessageCreate).toHaveBeenCalledOnce();
  });

  it("supports username-only recipient lookup", async () => {
    const harness = createHarness();

    const result = await harness.service.sendDirectMessage(
      "Bearer test-token",
      {
        ...request,
        recipientId: "",
      },
    );

    expect(result.message.recipientAccountId).toBe("recipient-account");
    expect(result.message.recipientHandle).toBe("@recipient");
    expect(harness.directMessageCreate).toHaveBeenCalledOnce();
  });

  it("does not report sent when the dedicated message write fails", async () => {
    const harness = createHarness({ directMessageCreateFails: true });

    await expect(
      harness.service.sendDirectMessage("Bearer test-token", request),
    ).rejects.toBeInstanceOf(InternalServerErrorException);
    expect(harness.directMessageCreate).toHaveBeenCalledOnce();
    expect(harness.auditCreate).not.toHaveBeenCalled();
  });

  it("fails closed when the dedicated message delegate is unavailable", async () => {
    const harness = createHarness({ directMessageDelegateAvailable: false });

    await expect(
      harness.service.sendDirectMessage("Bearer test-token", request),
    ).rejects.toBeInstanceOf(InternalServerErrorException);
    expect(harness.auditCreate).not.toHaveBeenCalled();
  });

  it("keeps a stored message successful when optional audit logging fails", async () => {
    const harness = createHarness({ auditCreateFails: true });

    const result = await harness.service.sendDirectMessage(
      "Bearer test-token",
      request,
    );

    expect(result.sent).toBe(true);
    expect(harness.directMessageCreate).toHaveBeenCalledOnce();
    expect(harness.auditCreate).toHaveBeenCalledOnce();
  });

  it("rejects an empty message body after trimming", async () => {
    const harness = createHarness();

    await expect(
      harness.service.sendDirectMessage("Bearer test-token", {
        ...request,
        message: "   ",
      }),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(harness.directMessageCreate).not.toHaveBeenCalled();
  });
});
