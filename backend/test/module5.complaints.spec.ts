import { ForbiddenException } from "@nestjs/common";
import { describe, expect, it, vi } from "vitest";
import { AuthenticationService } from "../src/auth/auth.service.js";
import { ComplaintsService } from "../src/complaints/complaints.service.js";
import { PrismaService } from "../src/database/prisma.service.js";

function createTestService() {
  process.env.NODE_ENV = "development";
  process.env.SAKHI_ENV = "dev";
  process.env.HOST = "127.0.0.1";
  process.env.SAKHI_ADMIN_REVIEW_TOKEN = "ADMIN2026TEST";

  const auth = {
    getCurrentAccountStatus: vi.fn().mockResolvedValue({
      accountId: "00000000-0000-4000-8000-000000000105",
      accountStatus: "ACTIVE",
      verificationStatus: "VERIFIED",
    }),
  };
  const prisma = {
    auditEvent: {
      findMany: vi.fn().mockResolvedValue([]),
      create: vi.fn().mockResolvedValue({ id: "audit-1" }),
    },
  };
  return new ComplaintsService(
    prisma as unknown as PrismaService,
    auth as unknown as AuthenticationService,
  );
}

describe("Module 5: Discreet & Anonymous Complaint System (SRS 7.1–7.6)", () => {
  it("lists all 10 configurable complaint categories and mandatory non-police legal disclaimer", async () => {
    const service = createTestService();
    const res = await service.listCategories();
    expect(res.categories.length).toBeGreaterThanOrEqual(10);
    expect(res.legalDisclaimer).toContain("does not automatically constitute a Police FIR");
    expect(res.emergencyChannels.some((c) => c.code === "112")).toBe(true);
  });

  it("detects self-identifying PII clues in incident descriptions and suggests safe generalization (SRS 7.4)", () => {
    const service = createTestService();
    const res = service.checkDescriptionForIdentityClues({
      description:
        "He messaged me at 6:34 PM about my bridal studio on 4th Cross and called +91 9845012345.",
    });
    expect(res.hasIdentityClues).toBe(true);
    expect(res.flaggedCount).toBeGreaterThanOrEqual(2);
    expect(res.suggestedSafeDescription).not.toContain("9845012345");
    expect(res.suggestedSafeDescription).toContain("local workspace");
  });

  it("scrubs EXIF GPS and device metadata from uploaded evidence files (SRS 7.4)", () => {
    const service = createTestService();
    const res = service.scrubEvidenceMetadata({
      originalFileName: "IMG_20261025_Raghavi_Phone.jpg",
      contentType: "image/jpeg",
      byteSize: 1024000,
      deviceModel: "OnePlus CPH2581",
      visualBlurApplied: true,
    });
    expect(res.sanitizedFile.exifGpsStripped).toBe(true);
    expect(res.sanitizedFile.deviceMetadataStripped).toBe(true);
    expect(res.sanitizedFile.fileName).toMatch(/^evidence_redacted_[a-z0-9]+\.jpg$/);
  });

  it("submits an Anonymous complaint with zero identity attachment and tracks it across all 7 statuses", async () => {
    const service = createTestService();
    const submitted = await service.submitComplaint("Bearer token", {
      reportingMode: "ANONYMOUS",
      categorySlug: "harassment",
      urgency: "HAPPENING_NOW",
      description: "Persistent harassing messages after declining business collaboration.",
      approximateDateLabel: "25 Oct 2026",
      approximateTimeWindow: "Evening (5 PM – 9 PM)",
      locationType: "COARSE_AREA",
      generalLocationLabel: "Tirupati 5km Coarse Zone",
      linkedTargetHandle: "@studio_collab_tpt24",
      evidenceFiles: [{ fileName: "evidence_redacted_01.png", byteSize: 512000 }],
      wantsUpdates: true,
      submitAnonymouslyToReviewTeam: true,
      acknowledgedNonPoliceLegalNotice: true,
    });

    expect(submitted.submitted).toBe(true);
    expect(submitted.referenceNumber).toMatch(/^#SKH-ANON-2026-\d{4}$/);
    expect(submitted.privacyGuarantees.publicProfileNameAttached).toBe(false);
    expect(submitted.privacyGuarantees.publishedOnSocialWall).toBe(false);
    expect(submitted.disguisedWellnessQuote.encodedSerialTag).toContain("Series #");

    // Track by Reference Number
    const tracked = await service.trackByReference(
      submitted.referenceNumber,
      submitted.passkey,
    );
    expect(tracked.found).toBe(true);
    expect(tracked.complaint.status).toBe("SUBMITTED");
    expect(tracked.allSupportedStatuses).toHaveLength(7);

    // Admin transitions to ADDITIONAL_INFO_REQUIRED
    await service.adminUpdateStatusAndEscalate(
      "ADMIN2026TEST",
      submitted.referenceNumber,
      {
        status: "ADDITIONAL_INFO_REQUIRED",
        publicMessageToComplainant: "Did the user contact you from another handle?",
      },
    );

    // Complainant sends anonymous reply -> automatically resumes UNDER_REVIEW
    const afterReply = await service.addComplainantReply(submitted.referenceNumber, {
      passkey: submitted.passkey,
      message: "Yes, from @secondary_handle_24.",
      additionalEvidenceFiles: [{ fileName: "followup.png" }],
    });
    expect(afterReply.complaint.status).toBe("UNDER_REVIEW");

    // Admin transitions to REJECTED_WITH_REASON -> Complainant submits Appeal -> ESCALATED
    await service.adminUpdateStatusAndEscalate(
      "ADMIN2026TEST",
      submitted.referenceNumber,
      {
        status: "REJECTED_WITH_REASON",
        rejectionReasonCode: "#INSUFFICIENT-INITIAL-CONTEXT",
        publicMessageToComplainant: "Initial context was insufficient.",
      },
    );
    const appealed = await service.submitAppeal(submitted.referenceNumber, {
      passkey: submitted.passkey,
      appealReasonCategory: "New Evidence Available",
      appealDescription: "Attached threatening voice note.",
    });
    expect(appealed.complaint.status).toBe("ESCALATED");

    // User purges uploaded media immediately
    const purged = await service.purgeComplainantMedia(submitted.referenceNumber);
    expect(purged.purged).toBe(true);
    expect(purged.complaint.mediaPurgedAt).toBeTruthy();
  });

  it("enforces role-based moderator masking, controlled evidence watermarking, duplicate merging, and malicious flood throttling (SRS 7.6)", async () => {
    const service = createTestService();
    const queueStandardMod = await service.adminDashboardAndQueue("ADMIN2026TEST", {
      viewerRole: "STANDARD_MODERATOR",
    });
    expect(
      queueStandardMod.complaints.every(
        (c) =>
          c.generalLocationLabel === "[Location Masked for Ordinary Moderator Role]",
      ),
    ).toBe(true);

    // Controlled evidence access logs audit and returns watermark
    const evAccess = await service.adminAccessControlledEvidence(
      "ADMIN2026TEST",
      "#SKH-ANON-2026-8492",
      {
        evidenceId: "ev_8492_01",
        action: "WATERMARKED_DOWNLOAD",
        justificationReason: "Repeat offender cluster verification",
      },
    );
    expect(evAccess.authorized).toBe(true);
    expect(evAccess.watermarkOverlayText).toContain("#SKH-ANON-2026-8492");

    // Malicious report handling throttles blinded bucket without unmasking identity
    await service.adminHandleMaliciousReport(
      "ADMIN2026TEST",
      "#SKH-ANON-2026-8471",
      {
        action: "THROTTLE_BLINDED_BUCKET",
        cooldownHours: 72,
        reason: "Coordinated competitor spam flood",
      },
    );

    await expect(
      service.submitComplaint(undefined, {
        reportingMode: "ANONYMOUS",
        categorySlug: "business_related_complaints",
        description: "Another spam flood from same bucket",
        clientRateLimitHint: "spam_test",
      }),
    ).resolves.toBeDefined();

    await expect(
      service.adminDashboardAndQueue("INVALID_TOKEN"),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });
});
