import {
  ForbiddenException,
  InternalServerErrorException,
  NotFoundException,
} from "@nestjs/common";
import { describe, expect, it, vi } from "vitest";
import { AuthenticationService } from "../src/auth/auth.service.js";
import { PrismaService } from "../src/database/prisma.service.js";
import { Module2Service } from "../src/module2/module2.service.js";

const viewerId = "2f6f7fa1-8c5c-4bb0-ae1a-0f7e3a2e5a41";
const ownerId = "3a7f8fb2-9d6d-4cc1-bf2b-1a8f4b3e6d52";
const businessId = "a2d54d85-9ab7-4d8f-95fc-b0f85f65a0c1";

function makeService(
  listing: Record<string, unknown>,
  overrides: Record<string, any> = {},
) {
  const auth = overrides.auth ?? {
    authenticateAuthorization: vi.fn().mockResolvedValue({
      accountId: viewerId,
      account: { status: "ACTIVE", verificationStatus: "VERIFIED" },
    }),
  };
  const prisma: Record<string, any> = {
    memberProfile: {
      findUnique: vi.fn().mockResolvedValue({
        accountId: viewerId,
        displayName: "Sakhi Viewer",
        username: "@viewer",
      }),
      update: vi.fn().mockResolvedValue({}),
    },
    businessDirectoryListing: {
      findFirst: vi.fn().mockResolvedValue({ ...listing }),
      update: vi.fn().mockImplementation(async (args: Record<string, any>) => ({
        ...listing,
        ...args.data,
      })),
      create: vi.fn(),
    },
    businessEnquiry: {
      findFirst: vi.fn().mockResolvedValue(null),
      findUnique: vi.fn().mockResolvedValue(null),
      findMany: vi.fn().mockResolvedValue([]),
      create: vi.fn(),
      update: vi.fn(),
    },
    businessReport: { create: vi.fn() },
    auditEvent: {
      create: vi.fn().mockResolvedValue({}),
      findMany: vi.fn().mockResolvedValue([]),
    },
    ...overrides,
  };
  const service = new Module2Service(
    auth as unknown as AuthenticationService,
    prisma as unknown as PrismaService,
  );
  return { service, auth, prisma };
}

const pendingListing = () => ({
  id: businessId,
  businessCode: "BUS-TEST-001",
  businessName: "Pending Sakhi Studio",
  ownerAccountId: ownerId,
  ownerDisplayName: "Business Owner",
  category: "Fashion and clothing",
  city: "Tirupati",
  description: "A business page awaiting moderator review",
  approvalStatus: "PENDING_APPROVAL",
  verificationBadgeStatus: "NONE",
  savedByAccountIds: [],
  viewsCount: 0,
  enquiriesCount: 0,
  productsServices: [],
  mediaGallery: [],
  offersAndPosts: [],
  businessHours: {},
});

describe("Module 6 business page access control", () => {
  it("does not count a view when an anonymous visitor requests a pending listing", async () => {
    const { service, prisma } = makeService(pendingListing());

    await expect(
      service.getMemberBusinessDetail(undefined, businessId),
    ).rejects.toBeInstanceOf(NotFoundException);

    expect(prisma.businessDirectoryListing.update).not.toHaveBeenCalled();
  });

  it("does not let a member edit a legacy listing without an owner account", async () => {
    const { service, prisma } = makeService({
      ...pendingListing(),
      ownerAccountId: null,
      approvalStatus: "APPROVED",
    });

    await expect(
      service.updateMemberBusiness("Bearer viewer-token", businessId, {
        businessName: "Hijacked title",
      }),
    ).rejects.toBeInstanceOf(ForbiddenException);

    expect(prisma.businessDirectoryListing.update).not.toHaveBeenCalled();
  });

  it("does not let a non-owner save a pending private listing", async () => {
    const { service, prisma } = makeService(pendingListing());

    await expect(
      service.toggleSaveBusiness("Bearer viewer-token", businessId),
    ).rejects.toBeInstanceOf(NotFoundException);

    expect(prisma.businessDirectoryListing.update).not.toHaveBeenCalled();
  });

  it("does not report a listing as saved when persistence fails", async () => {
    const listing = { ...pendingListing(), approvalStatus: "APPROVED" };
    const update = vi.fn().mockRejectedValue(new Error("database unavailable"));
    const { service, prisma } = makeService(listing, {
      businessDirectoryListing: {
        findFirst: vi.fn().mockResolvedValue(listing),
        update,
        create: vi.fn(),
      },
    });

    await expect(
      service.toggleSaveBusiness("Bearer viewer-token", businessId),
    ).rejects.toBeInstanceOf(InternalServerErrorException);

    expect(update).toHaveBeenCalledOnce();
  });

  it("returns the saved state only after the listing update succeeds", async () => {
    const listing = { ...pendingListing(), approvalStatus: "APPROVED" };
    const update = vi
      .fn()
      .mockResolvedValue({ ...listing, savedByAccountIds: [viewerId] });
    const { service } = makeService(listing, {
      businessDirectoryListing: {
        findFirst: vi.fn().mockResolvedValue(listing),
        update,
        create: vi.fn(),
      },
    });

    await expect(
      service.toggleSaveBusiness("Bearer viewer-token", businessId),
    ).resolves.toMatchObject({ businessId, isSaved: true, savesCount: 1 });
    expect(update).toHaveBeenCalledOnce();
  });

  it("does not let a member report a listing that is not publicly visible", async () => {
    const { service, prisma } = makeService(pendingListing());

    await expect(
      service.reportBusiness("Bearer viewer-token", businessId, {
        reason: "Not yet public",
      }),
    ).rejects.toBeInstanceOf(NotFoundException);

    expect(prisma.businessReport.create).not.toHaveBeenCalled();
    expect(prisma.businessDirectoryListing.update).not.toHaveBeenCalled();
  });

  it("does not confirm a business report when durable report persistence fails", async () => {
    const listing = { ...pendingListing(), approvalStatus: "APPROVED" };
    const { service, prisma } = makeService(listing, {
      businessReport: {
        create: vi.fn().mockRejectedValue(new Error("database unavailable")),
      },
    });

    await expect(
      service.reportBusiness("Bearer viewer-token", businessId, {
        reason: "Suspicious listing",
      }),
    ).rejects.toBeInstanceOf(InternalServerErrorException);

    expect(prisma.businessReport.create).toHaveBeenCalledOnce();
    expect(prisma.businessDirectoryListing.update).not.toHaveBeenCalled();
  });

  it("confirms a business report only after its durable record is saved", async () => {
    const listing = { ...pendingListing(), approvalStatus: "APPROVED" };
    const createReport = vi.fn().mockResolvedValue({ id: "report-1" });
    const { service, prisma } = makeService(listing, {
      businessReport: { create: createReport },
    });

    const result = await service.reportBusiness(
      "Bearer viewer-token",
      businessId,
      {
        reason: "Suspicious listing",
        details: "Contact details appear fraudulent",
      },
    );

    expect(result.reported).toBe(true);
    expect(createReport).toHaveBeenCalledOnce();
    expect(createReport.mock.calls[0]?.[0].data).toMatchObject({
      businessId,
      reporterAccountId: viewerId,
      reason: "Suspicious listing",
      details: "Contact details appear fraudulent",
      status: "OPEN",
    });
  });

  it("does not let a non-owner enquire about a pending listing", async () => {
    const { service, prisma } = makeService(pendingListing());

    await expect(
      service.createBusinessEnquiry("Bearer viewer-token", businessId, {
        message: "Is this available?",
      }),
    ).rejects.toBeInstanceOf(NotFoundException);

    expect(prisma.businessEnquiry.create).not.toHaveBeenCalled();
  });

  it("requires owner edits to return previously approved listings to review", async () => {
    const listing = {
      ...pendingListing(),
      ownerAccountId: viewerId,
      approvalStatus: "APPROVED",
      verificationBadgeStatus: "VERIFIED_WOMAN_OWNED",
    };
    const { service, prisma } = makeService(listing);

    await service.updateMemberBusiness("Bearer viewer-token", businessId, {
      description: "Updated business description",
    });

    const update = prisma.businessDirectoryListing.update.mock.calls[0]?.[0];
    expect(update.data.approvalStatus).toBe("PENDING_APPROVAL");
    expect(update.data.verificationBadgeStatus).toBe("PENDING_BADGE");
  });
  describe("business enquiry status permissions", () => {
    const enquiry = (status = "OPEN") => ({
      id: "enquiry-1",
      ownerAccountId: ownerId,
      senderAccountId: viewerId,
      status,
      messages: [],
      createdAt: new Date("2026-01-01T00:00:00.000Z"),
      updatedAt: new Date("2026-01-01T00:00:00.000Z"),
    });

    it("does not allow a customer to change the enquiry status", async () => {
      const update = vi.fn();
      const { service } = makeService(pendingListing(), {
        businessEnquiry: {
          findUnique: vi.fn().mockResolvedValue(enquiry("OPEN")),
          update,
        },
      });

      await expect(service.replyBusinessEnquiry("Bearer viewer-token", "enquiry-1", {
        message: "Thanks",
        status: "RESOLVED",
      })).rejects.toBeInstanceOf(ForbiddenException);
      expect(update).not.toHaveBeenCalled();
    });

    it("preserves the current status when a customer sends a message without a status", async () => {
      const update = vi.fn().mockImplementation(async ({ data }) => ({
        ...enquiry("REPLIED"), ...data,
      }));
      const { service } = makeService(pendingListing(), {
        businessEnquiry: {
          findUnique: vi.fn().mockResolvedValue(enquiry("REPLIED")),
          update,
        },
      });

      await service.replyBusinessEnquiry("Bearer viewer-token", "enquiry-1", {
        message: "I have one more question",
      });
      expect(update.mock.calls[0]?.[0].data.status).toBe("REPLIED");
    });

    it("does not allow a business owner to reopen a thread through a reply", async () => {
      const update = vi.fn();
      const auth = { authenticateAuthorization: vi.fn().mockResolvedValue({
        accountId: ownerId,
        account: { status: "ACTIVE", verificationStatus: "VERIFIED" },
      }) };
      const { service } = makeService(pendingListing(), {
        auth,
        businessEnquiry: {
          findUnique: vi.fn().mockResolvedValue(enquiry("OPEN")),
          update,
        },
      });

      await expect(service.replyBusinessEnquiry("Bearer owner-token", "enquiry-1", {
        message: "Reply",
        status: "OPEN",
      })).rejects.toBeInstanceOf(ForbiddenException);
      expect(update).not.toHaveBeenCalled();
    });

    it("allows the business owner to resolve an enquiry", async () => {
      const update = vi.fn().mockImplementation(async ({ data }) => ({
        ...enquiry("OPEN"), ...data,
      }));
      const auth = { authenticateAuthorization: vi.fn().mockResolvedValue({
        accountId: ownerId,
        account: { status: "ACTIVE", verificationStatus: "VERIFIED" },
      }) };
      const { service } = makeService(pendingListing(), {
        auth,
        businessEnquiry: {
          findUnique: vi.fn().mockResolvedValue(enquiry("OPEN")),
          update,
        },
      });

      await service.replyBusinessEnquiry("Bearer owner-token", "enquiry-1", {
        message: "This has been resolved",
        status: "RESOLVED",
      });
      expect(update.mock.calls[0]?.[0].data.status).toBe("RESOLVED");
    });
  });
});
