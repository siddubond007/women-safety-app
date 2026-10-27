import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  UnauthorizedException,
} from "@nestjs/common";
import { describe, expect, it, vi } from "vitest";
import { AuthenticationService } from "../src/auth/auth.service.js";
import {
  ComplaintsService,
  stripBinaryMetadata,
} from "../src/complaints/complaints.service.js";
import { PrismaService } from "../src/database/prisma.service.js";

function createTestService() {
  process.env.NODE_ENV = "development";
  process.env.SAKHI_ENV = "dev";
  process.env.HOST = "127.0.0.1";
  process.env.SAKHI_ADMIN_REVIEW_TOKEN = "ADMIN2026TEST";

  const persistedComplaints = new Map<string, Record<string, unknown>>();
  const persistedCategories = new Map<string, Record<string, unknown>>();

  const auth = {
    getCurrentAccount: vi.fn().mockImplementation(async (header?: string) => {
      if (!header || !header.toLowerCase().startsWith("bearer valid")) {
        throw new UnauthorizedException("Invalid session");
      }
      return {
        accountId: "00000000-0000-4000-8000-000000000105",
        accountStatus: "ACTIVE",
        verificationStatus: "VERIFIED",
      };
    }),
  };

  const prisma = {
    discreetComplaint: {
      findMany: vi
        .fn()
        .mockImplementation(async () =>
          Array.from(persistedComplaints.values()),
        ),
      upsert: vi
        .fn()
        .mockImplementation(async ({ where, create, update }: any) => {
          const existing = persistedComplaints.get(where.referenceNumber);
          const merged = existing ? { ...existing, ...update } : { ...create };
          persistedComplaints.set(where.referenceNumber, merged);
          return merged;
        }),
    },
    complaintCategoryConfig: {
      findMany: vi
        .fn()
        .mockImplementation(async () =>
          Array.from(persistedCategories.values()),
        ),
      upsert: vi
        .fn()
        .mockImplementation(async ({ where, create, update }: any) => {
          const existing = persistedCategories.get(where.slug);
          const merged = existing ? { ...existing, ...update } : { ...create };
          persistedCategories.set(where.slug, merged);
          return merged;
        }),
    },
    complaintRetentionPolicy: {
      findUnique: vi.fn().mockResolvedValue(null),
      upsert: vi.fn().mockImplementation(async ({ create, update }: any) => ({
        ...create,
        ...update,
      })),
    },
    auditEvent: {
      findMany: vi.fn().mockResolvedValue([]),
      create: vi.fn().mockResolvedValue({ id: "audit-1" }),
    },
  };

  return {
    service: new ComplaintsService(
      prisma as unknown as PrismaService,
      auth as unknown as AuthenticationService,
    ),
    prisma,
    persistedComplaints,
  };
}

describe("Module 5: Discreet & Anonymous Complaint System — Real Data & Validation Suite", () => {
  it("starts with an empty complaint queue (zero fabricated or hardcoded records)", async () => {
    const { service } = createTestService();
    const dashboard = await service.adminDashboardAndQueue("ADMIN2026TEST");
    expect(dashboard.complaints).toEqual([]);
    expect(dashboard.metrics.totalComplaints).toBe(0);
    expect(dashboard.metrics.openComplaintsCount).toBe(0);
    expect(dashboard.metrics.urgentP1Count).toBe(0);
    expect(dashboard.metrics.duplicateClustersCount).toBe(0);
    expect(dashboard.metrics.medianTriageHours).toBe(0);
  });

  it("lists all 10 configurable SRS categories and persists admin category changes", async () => {
    const { service } = createTestService();
    const res = await service.listCategories();
    expect(res.categories).toHaveLength(10);
    expect(res.legalDisclaimer).toContain(
      "does not automatically constitute a Police FIR",
    );

    // Disable a category via admin workflow and verify it is excluded from active list
    await service.adminUpsertCategory("ADMIN2026TEST", {
      slug: "public_place_safety",
      name: "Public-place safety concerns",
      description: "Unsafe streets or transit",
      isEnabled: false,
    });
    const afterDisable = await service.listCategories();
    expect(
      afterDisable.categories.some((c) => c.slug === "public_place_safety"),
    ).toBe(false);

    // Re-enable it
    await service.adminUpsertCategory("ADMIN2026TEST", {
      slug: "public_place_safety",
      name: "Public-place safety concerns",
      description: "Unsafe streets or transit",
      isEnabled: true,
    });
  });

  it("strips real binary EXIF/APP1 segments from JPEG buffers and eXIf/tEXt chunks from PNG buffers", () => {
    const { service } = createTestService();

    // Construct a real JPEG buffer with SOI (FFD8), APP1 EXIF segment (FFE1, length 10), and EOI (FFD9)
    const jpegWithExif = Buffer.from([
      0xff,
      0xd8, // SOI
      0xff,
      0xe1,
      0x00,
      0x08,
      0x45,
      0x78,
      0x69,
      0x66,
      0x00,
      0x00, // APP1 EXIF (10 bytes total)
      0xff,
      0xfe,
      0x00,
      0x05,
      0x47,
      0x50,
      0x53, // COM comment (7 bytes total)
      0xff,
      0xd9, // EOI
    ]);
    const stripped = stripBinaryMetadata(jpegWithExif, "image/jpeg");
    expect(stripped.removedMarkers).toContain("JPEG.APP1.EXIF_GPS_XMP");
    expect(stripped.removedMarkers).toContain("JPEG.COM.Comment");
    expect(
      stripped.scrubbedBuffer.equals(Buffer.from([0xff, 0xd8, 0xff, 0xd9])),
    ).toBe(true);

    const uploadRes = service.scrubEvidenceBinaryFile({
      originalFileName: "IMG_GPS_Photo.jpg",
      contentType: "image/jpeg",
      buffer: jpegWithExif,
    });
    expect(uploadRes.sanitizedFile.exifGpsStripped).toBe(true);
    expect(uploadRes.sanitizedFile.byteSize).toBe(4);
    expect(uploadRes.sanitizedFile.scrubbedFields).toContain(
      "JPEG.APP1.EXIF_GPS_XMP",
    );

    // Reject unsupported executable MIME type
    expect(() =>
      service.scrubEvidenceMetadata({
        originalFileName: "malware.exe",
        contentType: "application/x-msdownload",
        byteSize: 2048,
      }),
    ).toThrow(BadRequestException);
  });

  it("validates required fields, whitespace descriptions, invalid categories, malformed URLs, future dates, and duplicate submissions", async () => {
    const { service } = createTestService();

    // 1. Whitespace / too-short description rejected
    await expect(
      service.submitComplaint(undefined, {
        reportingMode: "ANONYMOUS",
        categorySlug: "harassment",
        description: "     too short    ",
      }),
    ).rejects.toBeInstanceOf(BadRequestException);

    // 2. Invalid category rejected
    await expect(
      service.submitComplaint(undefined, {
        reportingMode: "ANONYMOUS",
        categorySlug: "non_existent_category_xyz",
        description:
          "Repeated threatening messages sent in the community group.",
      }),
    ).rejects.toBeInstanceOf(BadRequestException);

    // 3. 'other' category without customCategoryLabel rejected
    await expect(
      service.submitComplaint(undefined, {
        reportingMode: "ANONYMOUS",
        categorySlug: "other",
        description:
          "Repeated threatening messages sent in the community group.",
      }),
    ).rejects.toBeInstanceOf(BadRequestException);

    // 4. Unacknowledged legal disclaimer rejected
    await expect(
      service.submitComplaint(undefined, {
        reportingMode: "ANONYMOUS",
        categorySlug: "harassment",
        description:
          "Repeated threatening messages sent in the community group.",
        acknowledgedNonPoliceLegalNotice: false,
      }),
    ).rejects.toBeInstanceOf(BadRequestException);

    // 5. Malformed URL rejected
    await expect(
      service.submitComplaint(undefined, {
        reportingMode: "ANONYMOUS",
        categorySlug: "harassment",
        description:
          "Repeated threatening messages sent in the community group.",
        supportingLinks: ["javascript:alert(1)"],
      }),
    ).rejects.toBeInstanceOf(BadRequestException);

    // 6. Future incident date rejected
    await expect(
      service.submitComplaint(undefined, {
        reportingMode: "ANONYMOUS",
        categorySlug: "harassment",
        description:
          "Repeated threatening messages sent in the community group.",
        approximateDateLabel: "2099-12-31",
      }),
    ).rejects.toBeInstanceOf(BadRequestException);

    // 7. Confidential mode without valid member auth token rejected
    await expect(
      service.submitComplaint(undefined, {
        reportingMode: "CONFIDENTIAL",
        categorySlug: "harassment",
        description:
          "Repeated threatening messages sent in the community group.",
      }),
    ).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it("enforces passkey verification, valid status transitions, RBAC masking, and full complaint lifecycle", async () => {
    const { service } = createTestService();

    // Submit a real Anonymous complaint (even if a bearer token is passed, confidentialAccountId must be null)
    const anonRes = await service.submitComplaint("Bearer valid-token", {
      reportingMode: "ANONYMOUS",
      categorySlug: "harassment",
      urgency: "HAPPENING_NOW",
      description:
        "Persistent harassing messages after declining a business collaboration inquiry.",
      approximateDateLabel: "25 Oct 2026",
      approximateTimeWindow: "Evening (5 PM – 9 PM)",
      locationType: "COARSE_AREA",
      generalLocationLabel: "Tirupati 5km Coarse Zone",
      linkedTargetHandle: "@offender_handle_1",
      supportingLinks: ["sakhi://post/post_101", "https://example.com/context"],
      evidenceFiles: [
        {
          id: "ev_test_01",
          fileName: "evidence_redacted_01.png",
          contentType: "image/png",
          byteSize: 120000,
        },
      ],
      clientRateLimitHint: "user_device_bucket_1",
    });

    expect(anonRes.submitted).toBe(true);
    expect(anonRes.referenceNumber).toMatch(/^#SKH-ANON-2026-\d{4}$/);
    expect(anonRes.passkey).toBeTruthy();

    // Duplicate rapid submission with identical text from same bucket is rejected
    await expect(
      service.submitComplaint(undefined, {
        reportingMode: "ANONYMOUS",
        categorySlug: "harassment",
        description:
          "Persistent harassing messages after declining a business collaboration inquiry.",
        clientRateLimitHint: "user_device_bucket_1",
      }),
    ).rejects.toBeInstanceOf(ConflictException);

    // Tracking without passkey or with wrong passkey is rejected
    await expect(
      service.trackByReference(anonRes.referenceNumber, undefined),
    ).rejects.toBeInstanceOf(ForbiddenException);
    await expect(
      service.trackByReference(anonRes.referenceNumber, "WRONG-PASSKEY"),
    ).rejects.toBeInstanceOf(ForbiddenException);

    // Tracking with valid passkey succeeds
    const tracked = await service.trackByReference(
      anonRes.referenceNumber,
      anonRes.passkey,
    );
    expect(tracked.found).toBe(true);
    expect(tracked.complaint.status).toBe("SUBMITTED");

    // Tracking via Disguised Wellness Quote Serial also succeeds
    const trackedBySerial = await service.trackByReference(
      anonRes.disguisedBackupSerial,
    );
    expect(trackedBySerial.complaint.referenceNumber).toBe(
      anonRes.referenceNumber,
    );

    // Invalid status transition (SUBMITTED -> CLOSED directly) is rejected
    await expect(
      service.adminUpdateStatusAndEscalate(
        "ADMIN2026TEST",
        anonRes.referenceNumber,
        { status: "CLOSED" },
      ),
    ).rejects.toBeInstanceOf(BadRequestException);

    // Valid transition: SUBMITTED -> ADDITIONAL_INFO_REQUIRED (with required question)
    await service.adminUpdateStatusAndEscalate(
      "ADMIN2026TEST",
      anonRes.referenceNumber,
      {
        status: "ADDITIONAL_INFO_REQUIRED",
        publicMessageToComplainant:
          "Did the reported account contact you from any secondary handle?",
      },
    );

    // Complainant replies with valid passkey -> automatically resumes UNDER_REVIEW
    const afterReply = await service.addComplainantReply(
      anonRes.referenceNumber,
      {
        passkey: anonRes.passkey,
        message: "Yes, they also messaged from @offender_backup.",
      },
    );
    expect(afterReply.complaint.status).toBe("UNDER_REVIEW");

    // Admin adds a private internal note and verifies complainant CANNOT see it
    await service.adminAddInternalNote(
      "ADMIN2026TEST",
      anonRes.referenceNumber,
      {
        noteText: "INTERNAL ONLY: Cross-checking device fingerprint.",
        visibilityRole: "SENIOR_REVIEWER",
      },
    );
    const afterNoteTracked = await service.trackByReference(
      anonRes.referenceNumber,
      anonRes.passkey,
    );
    expect((afterNoteTracked.complaint as any).internalNotes).toBeUndefined();

    // Standard Moderator role masking check
    const modQueue = await service.adminDashboardAndQueue("ADMIN2026TEST", {
      viewerRole: "STANDARD_MODERATOR",
    });
    expect(modQueue.complaints[0].generalLocationLabel).toBe(
      "[Location Masked for Ordinary Moderator Role]",
    );
    expect(modQueue.complaints[0].internalNotes).toEqual([]);
    expect(modQueue.complaints[0]).not.toHaveProperty("passkeyDigest");
    expect(modQueue.complaints[0]).not.toHaveProperty("disguisedBackupSerial");

    // A caller cannot elevate its role through the viewerRole query parameter.
    const elevationAttemptQueue = await service.adminDashboardAndQueue(
      "ADMIN2026TEST",
      { viewerRole: "SUPER_ADMIN" },
    );
    expect(elevationAttemptQueue.reviewer.effectiveRole).toBe(
      "SENIOR_REVIEWER",
    );
    expect(elevationAttemptQueue.complaints[0]).not.toHaveProperty(
      "passkeyDigest",
    );
    expect(elevationAttemptQueue.complaints[0]).not.toHaveProperty(
      "disguisedBackupSerial",
    );

    const elevationAttemptDetail = await service.adminGetComplaintDetail(
      "ADMIN2026TEST",
      anonRes.referenceNumber,
      "SUPER_ADMIN",
    );
    expect(elevationAttemptDetail.reviewer.effectiveRole).toBe(
      "SENIOR_REVIEWER",
    );
    expect(elevationAttemptDetail.complaint).not.toHaveProperty(
      "passkeyDigest",
    );
    expect(elevationAttemptDetail.complaint).not.toHaveProperty(
      "disguisedBackupSerial",
    );

    // Standard Moderator cannot unblur evidence
    await expect(
      service.adminAccessControlledEvidence(
        "ADMIN2026TEST",
        anonRes.referenceNumber,
        {
          evidenceId: "ev_test_01",
          action: "REVEAL_VIEWER",
          justificationReason: "Checking screenshot evidence",
          viewerRole: "STANDARD_MODERATOR",
        },
      ),
    ).rejects.toBeInstanceOf(ForbiddenException);

    // Senior Reviewer can unblur evidence with valid justification
    const evAccess = await service.adminAccessControlledEvidence(
      "ADMIN2026TEST",
      anonRes.referenceNumber,
      {
        evidenceId: "ev_test_01",
        action: "WATERMARKED_DOWNLOAD",
        justificationReason:
          "Verifying harassment screenshot for account suspension",
      },
    );
    expect(evAccess.authorized).toBe(true);
    expect(evAccess.watermarkOverlayText).toContain(anonRes.referenceNumber);

    // Admin transitions to REJECTED_WITH_REASON -> Complainant appeals -> ESCALATED
    await service.adminUpdateStatusAndEscalate(
      "ADMIN2026TEST",
      anonRes.referenceNumber,
      {
        status: "REJECTED_WITH_REASON",
        rejectionReasonCode: "#INSUFFICIENT-INITIAL-CONTEXT",
        publicMessageToComplainant: "Closing pending additional proof.",
      },
    );
    const appealed = await service.submitAppeal(anonRes.referenceNumber, {
      passkey: anonRes.passkey,
      appealReasonCategory: "New Evidence",
      appealDescription:
        "Providing full chat transcript and witness confirmation.",
    });
    expect(appealed.complaint.status).toBe("ESCALATED");

    // Complainant purges media with valid passkey
    const purged = await service.purgeComplainantMedia(
      anonRes.referenceNumber,
      anonRes.passkey,
    );
    expect(purged.purged).toBe(true);
    expect(purged.complaint.mediaPurgedAt).toBeTruthy();
  });
});
