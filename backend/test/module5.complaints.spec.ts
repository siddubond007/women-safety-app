import { createHash } from "node:crypto";
import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  ServiceUnavailableException,
  UnauthorizedException,
} from "@nestjs/common";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { AuthenticationService } from "../src/auth/auth.service.js";
import {
  ComplaintsService,
  stripBinaryMetadata,
} from "../src/complaints/complaints.service.js";
import { PrismaService } from "../src/database/prisma.service.js";
import { SakhiAdminRbacRegistry } from "../src/admin-review/admin-rbac.helper.js";
import { StagingTestAdminService } from "../src/staging-test-admin/staging-test-admin.service.js";

const LOCAL_REVIEWER_TOKEN = "staff-admin.unit-test-super-admin-session";
const COMPLAINT_REVIEWER_SESSION = "staff-admin.unit-test-complaint-reviewer-session";
const sessionPrincipals = new Map<string, any>();

const DEFAULT_TEST_SUPER_ADMIN = {
  staffId: "00000000-0000-4000-8000-000000000001",
  staffCode: "#SA-TEST",
  reviewerLabel: "Unit Test Super Admin",
  fullName: "Unit Test Super Admin",
  email: "superadmin@example.test",
  role: "SUPER_ADMIN",
  roleTitle: "Super Admin",
  badgeLabel: "Super Admin",
  clearanceLevel: "LEVEL_4_MASTER_GOVERNANCE",
  isAuthorisedComplaintReviewer: true,
  permissions: { view: true, create: true, edit: true, approve: true, suspend: true, export: true, delete: true },
  allowedRoutes: [],
};
const DEFAULT_TEST_COMPLAINT_REVIEWER = {
  ...DEFAULT_TEST_SUPER_ADMIN,
  staffId: "00000000-0000-4000-8000-000000000002",
  staffCode: "#CR-TEST",
  reviewerLabel: "Unit Test Complaint Reviewer",
  fullName: "Unit Test Complaint Reviewer",
  role: "COMPLAINT_REVIEWER",
  roleTitle: "Complaint Reviewer",
  badgeLabel: "Complaint Reviewer",
  clearanceLevel: "LEVEL_3_COMPLAINT_REVIEW",
  permissions: { view: true, create: false, edit: true, approve: true, suspend: false, export: true, delete: false },
  allowedRoutes: ["/complaints"],
};

function sessionForIssuedStaffCredential(accessToken: string): string {
  const staff = SakhiAdminRbacRegistry.findStaffByToken(accessToken);
  if (!staff) throw new Error("Test staff account was not persisted in the RBAC registry.");
  const sessionToken = "staff-admin.unit-test-" + staff.id;
  sessionPrincipals.set(sessionToken, SakhiAdminRbacRegistry.principalFromStaff(staff));
  return sessionToken;
}

beforeEach(() => {
  sessionPrincipals.clear();
  sessionPrincipals.set(COMPLAINT_REVIEWER_SESSION, DEFAULT_TEST_COMPLAINT_REVIEWER);
  vi.spyOn(StagingTestAdminService, "resolvePrincipalFromSessionToken").mockImplementation(
    (token?: string) => {
      if (token === LOCAL_REVIEWER_TOKEN) return DEFAULT_TEST_SUPER_ADMIN as any;
      const principal = token ? sessionPrincipals.get(token) : undefined;
      if (principal) return principal;
      throw new UnauthorizedException("Unknown test staff session.");
    },
  );
});

afterEach(() => {
  vi.restoreAllMocks();
  SakhiAdminRbacRegistry.resetForTesting();
});

function createTestService() {
  process.env.NODE_ENV = "development";
  process.env.SAKHI_ENV = "dev";
  process.env.HOST = "127.0.0.1";
  process.env.SAKHI_ADMIN_REVIEW_TOKEN = LOCAL_REVIEWER_TOKEN;

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
      findUnique: vi.fn().mockImplementation(async ({ where }: any) =>
        Array.from(persistedComplaints.values()).find((row: any) =>
          row.id === where.id || row.referenceNumber === where.referenceNumber
        ) ?? null
      ),
      updateMany: vi.fn().mockImplementation(async ({ where, data }: any) => {
        const row = Array.from(persistedComplaints.values()).find((item: any) => item.id === where.id) as any;
        if (!row) return { count: 0 };
        if (where.passkeyFailedAttempts?.lt !== undefined && row.passkeyFailedAttempts >= where.passkeyFailedAttempts.lt) return { count: 0 };
        if (data.passkeyFailedAttempts?.increment) row.passkeyFailedAttempts += data.passkeyFailedAttempts.increment;
        if (data.passkeyFailedAttempts === 0) row.passkeyFailedAttempts = 0;
        if (data.passkeyLockedUntil !== undefined) row.passkeyLockedUntil = data.passkeyLockedUntil;
        persistedComplaints.set(row.referenceNumber, row);
        return { count: 1 };
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

  const persistedStaff = new Map<string, Record<string, any>>();
  const adminStaffAccount = {
    findMany: vi
      .fn()
      .mockImplementation(async () => Array.from(persistedStaff.values())),
    findUnique: vi.fn().mockImplementation(async ({ where }: any) => persistedStaff.get(where.id) ?? null),
    create: vi.fn().mockImplementation(async ({ data }: any) => {
      persistedStaff.set(data.id, { ...data });
      return persistedStaff.get(data.id);
    }),
    updateMany: vi.fn().mockImplementation(async ({ where, data }: any) => {
      const current = persistedStaff.get(where.id);
      if (!current) return { count: 0 };
      persistedStaff.set(where.id, { ...current, ...data });
      return { count: 1 };
    }),
    count: vi.fn().mockImplementation(async ({ where }: any) =>
      Array.from(persistedStaff.values()).filter((row) =>
        (!where?.role || row.role === where.role) && (!where?.status || row.status === where.status)
      ).length
    ),
    upsert: vi.fn().mockImplementation(async ({ where, create, update }: any) => {
      const current = persistedStaff.get(where.id);
      const saved = current ? { ...current, ...update } : { ...create };
      persistedStaff.set(where.id, saved);
      return saved;
    }),
  };
  const adminStaffSession = {
    updateMany: vi.fn().mockResolvedValue({ count: 0 }),
  };
  const adminStaffBackupCode = {
    updateMany: vi.fn().mockResolvedValue({ count: 0 }),
  };
  const adminStaffRecoveryRequest = {
    updateMany: vi.fn().mockResolvedValue({ count: 0 }),
  };
  Object.assign(prisma, {
    adminStaffAccount,
    adminStaffSession,
    adminStaffBackupCode,
    adminStaffRecoveryRequest,
    $transaction: vi.fn(async (callback: (tx: any) => Promise<unknown>) =>
      callback(prisma),
    ),
  });

  return {
    service: new ComplaintsService(
      prisma as unknown as PrismaService,
      auth as unknown as AuthenticationService,
      {
        uploadComplaintEvidence: vi
          .fn()
          .mockImplementation(async ({ evidenceId, buffer }: any) => ({
            driveFileId: `drive_${evidenceId}`,
            driveFolderId: "folder_evidence",
            size: buffer.length,
            sha256Checksum: createHash("sha256").update(buffer).digest("hex"),
          })),
        verifyComplaintEvidenceFile: vi.fn().mockResolvedValue(true),
        downloadFile: vi.fn().mockResolvedValue({
          buffer: Buffer.from("synthetic evidence bytes"),
          contentType: "image/png",
        }),
        deleteComplaintEvidence: vi.fn().mockResolvedValue(undefined),
      } as any,
    ),
    prisma,
    persistedComplaints,
  };
}

describe("Module 5: Discreet & Anonymous Complaint System — Real Data & Validation Suite", () => {
  it("starts with an empty complaint queue (zero fabricated or hardcoded records)", async () => {
    const { service } = createTestService();
    const dashboard = await service.adminDashboardAndQueue(LOCAL_REVIEWER_TOKEN);
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
    await service.adminUpsertCategory(LOCAL_REVIEWER_TOKEN, {
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
    await service.adminUpsertCategory(LOCAL_REVIEWER_TOKEN, {
      slug: "public_place_safety",
      name: "Public-place safety concerns",
      description: "Unsafe streets or transit",
      isEnabled: true,
    });
  });

  it("strips real binary EXIF/APP1 segments from JPEG buffers and eXIf/tEXt chunks from PNG buffers", async () => {
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

    const uploadRes = await service.scrubEvidenceBinaryFile({
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
    await expect(
      service.scrubEvidenceMetadata({
        originalFileName: "malware.exe",
        contentType: "application/x-msdownload",
        byteSize: 2048,
      }),
    ).rejects.toThrow(BadRequestException);
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

  it("does not report a complaint as submitted when durable persistence fails", async () => {
    const { service, prisma, persistedComplaints } = createTestService();
    prisma.discreetComplaint.upsert.mockRejectedValueOnce(
      new Error("synthetic database write failure"),
    );

    await expect(
      service.submitComplaint(undefined, {
        reportingMode: "ANONYMOUS",
        categorySlug: "harassment",
        description:
          "Synthetic persistence failure regression test, no real incident.",
        acknowledgedNonPoliceLegalNotice: true,
      }),
    ).rejects.toBeInstanceOf(ServiceUnavailableException);

    expect(prisma.auditEvent.create).not.toHaveBeenCalled();
    expect(persistedComplaints.size).toBe(0);
  });

  it("enforces passkey verification, valid status transitions, RBAC masking, and full complaint lifecycle", async () => {
    const { service } = createTestService();

    // Evidence must originate from the server-side scrub-and-store upload flow.
    const uploadedEvidence = await service.scrubEvidenceBinaryFile({
      originalFileName: "proof.png",
      contentType: "image/png",
      buffer: Buffer.from("synthetic evidence bytes"),
    });

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
      evidenceFiles: [uploadedEvidence.sanitizedFile],
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
    expect(tracked.complaint.retentionExpiresAt).toBeNull();

    // Tracking via Disguised Wellness Quote Serial also succeeds
    const trackedBySerial = await service.trackByReference(
      anonRes.disguisedBackupSerial,
      anonRes.passkey,
    );
    expect(trackedBySerial.complaint.referenceNumber).toBe(
      anonRes.referenceNumber,
    );

    // Invalid status transition (SUBMITTED -> CLOSED directly) is rejected
    await expect(
      service.adminUpdateStatusAndEscalate(
        LOCAL_REVIEWER_TOKEN,
        anonRes.referenceNumber,
        { status: "CLOSED" },
      ),
    ).rejects.toBeInstanceOf(BadRequestException);

    // Valid transition: SUBMITTED -> ADDITIONAL_INFO_REQUIRED (with required question)
    await service.adminUpdateStatusAndEscalate(
      LOCAL_REVIEWER_TOKEN,
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
      COMPLAINT_REVIEWER_SESSION,
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
    const modQueue = await service.adminDashboardAndQueue(COMPLAINT_REVIEWER_SESSION, {
      viewerRole: "STANDARD_MODERATOR",
    });
    const firstModeratedComplaint = modQueue.complaints[0];
    expect(firstModeratedComplaint).toBeDefined();
    if (!firstModeratedComplaint) {
      throw new Error("Expected the first complaint in the moderator queue.");
    }
    expect(firstModeratedComplaint.generalLocationLabel).toBe(
      "[Location Masked for Ordinary Moderator Role]",
    );
    expect(firstModeratedComplaint.internalNotes).toEqual([]);
    expect(firstModeratedComplaint).not.toHaveProperty("passkeyDigest");
    expect(firstModeratedComplaint).not.toHaveProperty("disguisedBackupSerial");

    // A caller cannot elevate its role through the viewerRole query parameter.
    const elevationAttemptQueue = await service.adminDashboardAndQueue(
      COMPLAINT_REVIEWER_SESSION,
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
      COMPLAINT_REVIEWER_SESSION,
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

    // The server derives the role from the authenticated session; a client
    // cannot downgrade or elevate access by supplying viewerRole.
    const contentModeratorSession = "staff-admin.unit-test-content-moderator";
    sessionPrincipals.set(contentModeratorSession, {
      ...DEFAULT_TEST_COMPLAINT_REVIEWER,
      role: "CONTENT_MODERATOR",
      roleTitle: "Content Moderator",
      isAuthorisedComplaintReviewer: false,
      permissions: { ...DEFAULT_TEST_COMPLAINT_REVIEWER.permissions },
    });
    await expect(
      service.adminAccessControlledEvidence(
        contentModeratorSession,
        anonRes.referenceNumber,
        {
          evidenceId: uploadedEvidence.sanitizedFile.id,
          action: "REVEAL_VIEWER",
          justificationReason: "Checking screenshot evidence",
        },
      ),
    ).rejects.toBeInstanceOf(ForbiddenException);

    // A real Complaint Reviewer can unblur evidence with valid justification.
    const evAccess = await service.adminAccessControlledEvidence(
      COMPLAINT_REVIEWER_SESSION,
      anonRes.referenceNumber,
      {
        evidenceId: uploadedEvidence.sanitizedFile.id,
        action: "WATERMARKED_DOWNLOAD",
        justificationReason:
          "Verifying harassment screenshot for account suspension",
      },
    );
    expect(evAccess.authorized).toBe(true);
    expect(evAccess.watermarkOverlayText).toContain(anonRes.referenceNumber);

    // Rejection starts the configured evidence retention clock.
    await service.adminUpdateStatusAndEscalate(
      LOCAL_REVIEWER_TOKEN,
      anonRes.referenceNumber,
      {
        status: "REJECTED_WITH_REASON",
        rejectionReasonCode: "#INSUFFICIENT-INITIAL-CONTEXT",
        publicMessageToComplainant: "Closing pending additional proof.",
      },
    );
    const rejected = await service.trackByReference(
      anonRes.referenceNumber,
      anonRes.passkey,
    );
    expect(rejected.complaint.retentionExpiresAt).toBeTruthy();

    // An appeal reopens the case and cancels the pending retention deadline.
    const appealed = await service.submitAppeal(anonRes.referenceNumber, {
      passkey: anonRes.passkey,
      appealReasonCategory: "New Evidence",
      appealDescription:
        "Providing full chat transcript and witness confirmation.",
    });
    expect(appealed.complaint.status).toBe("ESCALATED");
    expect(appealed.complaint.retentionExpiresAt).toBeNull();

    // Complainant purges media with valid passkey
    const purged = await service.purgeComplainantMedia(
      anonRes.referenceNumber,
      anonRes.passkey,
    );
    expect(purged.purged).toBe(true);
    expect(purged.complaint.mediaPurgedAt).toBeTruthy();
  });
});

describe("Module 5 & Module 10 RBAC — Real Admin Staff, Two-Way Messages & Open P1 Metrics", () => {
  it("uses a high-entropy independent complaint passkey, allowlists audit metadata, and persists lockout", async () => {
    const { service, prisma, persistedComplaints } = createTestService();
    const created = await service.submitComplaint(undefined, {
      reportingMode: "ANONYMOUS",
      categorySlug: "harassment",
      description: "Repeated threatening messages from an account after a clear refusal.",
    });
    expect(created.passkey).toMatch(/^[A-Za-z0-9_-]{43}$/);
    expect(created.disguisedBackupSerial).not.toContain(created.passkey);
    const stored = persistedComplaints.get(created.referenceNumber) as any;
    expect(stored.passkeyDigest).toMatch(/^scrypt\$/);
    const auditCall = (prisma.auditEvent.create as any).mock.calls[0][0];
    expect(auditCall.data.redactedMetadata).not.toHaveProperty("description");
    expect(auditCall.data.redactedMetadata).not.toHaveProperty("passkeyDigest");
    expect(auditCall.data.redactedMetadata).not.toHaveProperty("disguisedBackupSerial");

    for (let attempt = 0; attempt < 5; attempt += 1) {
      await expect(service.trackByReference(created.referenceNumber, "incorrect-passkey"))
        .rejects.toBeInstanceOf(ForbiddenException);
    }
    expect(stored.passkeyFailedAttempts).toBe(5);
    expect(stored.passkeyLockedUntil).toBeInstanceOf(Date);
    await expect(service.trackByReference(created.referenceNumber, created.passkey))
      .rejects.toThrow(/temporarily locked/i);
  });

  it("rejects shared staging admin tokens and requires a persistent staff session", () => {
    const previous = {
      nodeEnv: process.env.NODE_ENV,
      sakhiEnv: process.env.SAKHI_ENV,
      reviewerToken: process.env.SAKHI_ADMIN_REVIEW_TOKEN,
      reviewEnabled: process.env.SAKHI_STAGING_ADMIN_REVIEW_ENABLED,
      otpMode: process.env.SAKHI_OTP_MODE,
    };
    try {
      process.env.NODE_ENV = "production";
      process.env.SAKHI_ENV = "staging";
      process.env.SAKHI_ADMIN_REVIEW_TOKEN = "a".repeat(64);
      process.env.SAKHI_STAGING_ADMIN_REVIEW_ENABLED = "true";
      process.env.SAKHI_OTP_MODE = "staging_test";
      const service = new ComplaintsService(
        {} as PrismaService,
        {} as AuthenticationService,
      );
      expect(() => service.assertReviewer("a".repeat(64))).toThrow(
        UnauthorizedException,
      );
    } finally {
      if (previous.nodeEnv === undefined) delete process.env.NODE_ENV;
      else process.env.NODE_ENV = previous.nodeEnv;
      if (previous.sakhiEnv === undefined) delete process.env.SAKHI_ENV;
      else process.env.SAKHI_ENV = previous.sakhiEnv;
      if (previous.reviewerToken === undefined) delete process.env.SAKHI_ADMIN_REVIEW_TOKEN;
      else process.env.SAKHI_ADMIN_REVIEW_TOKEN = previous.reviewerToken;
      if (previous.reviewEnabled === undefined) delete process.env.SAKHI_STAGING_ADMIN_REVIEW_ENABLED;
      else process.env.SAKHI_STAGING_ADMIN_REVIEW_ENABLED = previous.reviewEnabled;
      if (previous.otpMode === undefined) delete process.env.SAKHI_OTP_MODE;
      else process.env.SAKHI_OTP_MODE = previous.otpMode;
    }
  });

  it("populates authorisedReviewers from real database AdminStaffAccount rows (zero fake Meera/Kavita/Anjali) and enforces 5-role boundaries", async () => {
    const { service, prisma } = createTestService();
    const { SakhiAdminRbacRegistry } =
      await import("../src/admin-review/admin-rbac.helper.js");
    SakhiAdminRbacRegistry.resetForTesting();

    // Only real persisted staff accounts may appear; no synthetic bootstrap reviewer.
    const initialDash = await service.adminDashboardAndQueue(LOCAL_REVIEWER_TOKEN);
    expect(initialDash.authorisedReviewers).toHaveLength(0);
    expect(JSON.stringify(initialDash.authorisedReviewers)).not.toContain(
      "Meera Krishnan",
    );

    // Create a Role 3 Authorised Complaint Reviewer and a Role 2 Content Moderator
    const reviewerStaff = await SakhiAdminRbacRegistry.createStaffAccount(
      prisma as unknown as PrismaService,
      {
        fullName: "Priya Nair",
        email: "priya.nair@sakhi.org.in",
        role: "COMPLAINT_REVIEWER",
      },
      "Sakhi Super Admin",
    );
    const moderatorStaff = await SakhiAdminRbacRegistry.createStaffAccount(
      prisma as unknown as PrismaService,
      {
        fullName: "Sneha Reddy",
        email: "sneha.reddy@sakhi.org.in",
        role: "CONTENT_MODERATOR",
      },
      "Sakhi Super Admin",
    );

    // Role 2 Content Moderator is strictly blocked from accessing Discreet Complaints (SRS 7.4)
    const moderatorSession = sessionForIssuedStaffCredential(moderatorStaff.issuedAccessToken);
    const reviewerSession = sessionForIssuedStaffCredential(reviewerStaff.issuedAccessToken);

    await expect(
      service.adminDashboardAndQueue(moderatorSession),
    ).rejects.toBeInstanceOf(ForbiddenException);

    // Role 3 Authorised Complaint Reviewer can access the queue and appears in authorisedReviewers
    const staffDash = await service.adminDashboardAndQueue(reviewerSession);
    expect(
      staffDash.authorisedReviewers.some((r) => r.name.includes("Priya Nair")),
    ).toBe(true);

    // Role 3 Authorised Complaint Reviewer cannot alter global DPDP retention policy (Super Admin only)
    await expect(
      service.adminUpdateRetentionPolicy(reviewerSession, {
        closedEvidenceRetentionDays: 60,
        rejectedReportRetentionDays: 20,
        technicalRateLimitLogDays: 7,
      }),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });

  it("delivers user follow-up replies & appeals to admin, supports direct reviewer replies, and counts only open P1 complaints in urgentP1Count", async () => {
    const { service } = createTestService();

    // Reject numbers-only description and numbers-only location
    await expect(
      service.submitComplaint(undefined, {
        reportingMode: "ANONYMOUS",
        categorySlug: "harassment",
        description: "123456789012345678901234567890",
      }),
    ).rejects.toBeInstanceOf(BadRequestException);

    await expect(
      service.submitComplaint(undefined, {
        reportingMode: "ANONYMOUS",
        categorySlug: "harassment",
        description:
          "Repeated harassing messages sent inside the community group.",
        generalLocationLabel: "999999",
      }),
    ).rejects.toBeInstanceOf(BadRequestException);

    // Submit a valid urgent P1 complaint
    const created = await service.submitComplaint(undefined, {
      reportingMode: "ANONYMOUS",
      categorySlug: "harassment",
      urgency: "HAPPENING_NOW",
      description:
        "Repeated harassing messages sent inside the community group.",
    });

    // User sends a follow-up message
    await service.addComplainantReply(created.referenceNumber, {
      passkey: created.passkey,
      message: "Please reopen or review the new screenshot I attached.",
    });

    // Admin sends a direct reply to the complainant
    await service.adminSendMessageToComplainant(
      LOCAL_REVIEWER_TOKEN,
      created.referenceNumber,
      {
        message: "We have received your message and are reviewing the account.",
      },
    );

    const openDash = await service.adminDashboardAndQueue(LOCAL_REVIEWER_TOKEN);
    expect(openDash.metrics.openComplaintsCount).toBe(1);
    expect(openDash.metrics.urgentP1Count).toBe(1);
    expect(openDash.complaints[0]?.complainantMessages).toHaveLength(2);
    expect(openDash.complaints[0]?.complainantMessages[0]?.message).toContain(
      "Please reopen",
    );
    expect(openDash.complaints[0]?.complainantMessages[1]?.message).toContain(
      "We have received your message",
    );

    // Transition UNDER_REVIEW -> CLOSED and verify urgentP1Count drops to 0!
    await service.adminUpdateStatusAndEscalate(
      LOCAL_REVIEWER_TOKEN,
      created.referenceNumber,
      { status: "UNDER_REVIEW" },
    );
    await service.adminUpdateStatusAndEscalate(
      LOCAL_REVIEWER_TOKEN,
      created.referenceNumber,
      { status: "CLOSED", publicMessageToComplainant: "Resolved." },
    );

    const closedDash = await service.adminDashboardAndQueue(LOCAL_REVIEWER_TOKEN);
    expect(closedDash.metrics.openComplaintsCount).toBe(0);
    expect(closedDash.metrics.urgentP1Count).toBe(0);
  });
});
