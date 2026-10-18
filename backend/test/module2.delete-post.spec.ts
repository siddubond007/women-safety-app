import { beforeEach, describe, expect, it, vi } from "vitest";
import { AuthenticationService } from "../src/auth/auth.service.js";
import { PrismaService } from "../src/database/prisma.service.js";
import { Module2Service } from "../src/module2/module2.service.js";

const accountId = "2f6f7fa1-8c5c-4bb0-ae1a-0f7e3a2e5a41";
const postId = "4b1f7f84-2f0d-4f39-8bd9-73ac2a7763a1";

describe("Module2Service post deletion", () => {
  let service: Module2Service;
  let prisma: Record<string, any>;
  let tx: Record<string, any>;

  beforeEach(() => {
    tx = {
      memberPost: { update: vi.fn().mockResolvedValue({ id: postId }) },
      memberPostComment: { updateMany: vi.fn().mockResolvedValue({ count: 2 }) },
      memberPostLike: { deleteMany: vi.fn().mockResolvedValue({ count: 3 }) },
      memberPostBookmark: { deleteMany: vi.fn().mockResolvedValue({ count: 1 }) },
      postAudienceMember: { deleteMany: vi.fn().mockResolvedValue({ count: 2 }) },
      auditEvent: { createMany: vi.fn().mockResolvedValue({ count: 1 }) },
    };

    prisma = {
      memberProfile: {
        findUnique: vi.fn().mockResolvedValue({ accountId }),
      },
      memberPost: {
        findFirst: vi.fn().mockResolvedValue({ id: postId }),
      },
      $transaction: vi.fn(async (operation: (tx: Record<string, any>) => Promise<unknown>) =>
        operation(tx),
      ),
    };

    const auth = {
      authenticateAuthorization: vi.fn().mockResolvedValue({
        accountId,
        account: { status: "ACTIVE", verificationStatus: "VERIFIED" },
      }),
    };
    service = new Module2Service(
      auth as unknown as AuthenticationService,
      prisma as unknown as PrismaService,
    );
  });

  it("only deletes a published post owned by the authenticated member", async () => {
    await expect(service.deletePost("Bearer test-token", postId)).resolves.toEqual({
      postId,
      deleted: true,
    });

    expect(prisma.memberPost.findFirst).toHaveBeenCalledWith({
      where: {
        id: postId,
        accountId,
        status: "PUBLISHED",
        deletedAt: null,
      },
      select: { id: true },
    });
  });

  it("scrubs visible comments and removes engagement before recording the audit event", async () => {
    await service.deletePost("Bearer test-token", postId);

    expect(tx.memberPost.update).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { id: postId },
        data: expect.objectContaining({
          body: "[removed by author]",
          mediaRef: null,
          status: "REMOVED",
          deletedAt: expect.any(Date),
        }),
      }),
    );
    expect(tx.memberPostComment.updateMany).toHaveBeenCalledWith({
      where: { postId, deletedAt: null },
      data: { body: "[removed]", deletedAt: expect.any(Date) },
    });
    expect(tx.memberPostLike.deleteMany).toHaveBeenCalledWith({ where: { postId } });
    expect(tx.memberPostBookmark.deleteMany).toHaveBeenCalledWith({ where: { postId } });
    expect(tx.postAudienceMember.deleteMany).toHaveBeenCalledWith({ where: { postId } });
    expect(tx.auditEvent.createMany).toHaveBeenCalledWith({
      data: expect.objectContaining({
        actorId: accountId,
        action: "module2.post.deleted_by_author",
        targetId: postId,
        outcome: "success",
      }),
    });
  });
});
