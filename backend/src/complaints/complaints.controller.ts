import {
  Body,
  Controller,
  Delete,
  Get,
  Headers,
  HttpCode,
  Param,
  Patch,
  Post,
  Put,
  Query,
} from "@nestjs/common";
import {
  AccessComplaintEvidenceDto,
  AddComplainantReplyDto,
  AddComplaintInternalNoteDto,
  AssignAndClassifyComplaintDto,
  CheckDescriptionPiiDto,
  HandleMaliciousComplaintDto,
  MergeDuplicateComplaintsDto,
  ScrubEvidenceMetadataDto,
  SubmitComplaintAppealDto,
  SubmitDiscreetComplaintDto,
  UpdateComplaintRetentionPolicyDto,
  UpdateComplaintStatusDto,
  UpsertComplaintCategoryConfigDto,
} from "./complaints.dto.js";
import { ComplaintsService } from "./complaints.service.js";

function pickAdminToken(
  primary?: string,
  fallback?: string,
  stagingSession?: string,
): string | undefined {
  return (
    primary?.trim() ||
    fallback?.trim() ||
    stagingSession?.trim() ||
    undefined
  );
}

@Controller()
export class ComplaintsController {
  constructor(private readonly service: ComplaintsService) {}

  // ===========================================================================
  // Member / Anonymous User Endpoints (/api/v1/complaints/* & /api/v1/module2/complaints/*)
  // ===========================================================================

  @Get(["complaints/categories", "module2/complaints/categories"])
  listCategories() {
    return this.service.listCategories();
  }

  @Post(["complaints/pii-check", "module2/complaints/pii-check"])
  @HttpCode(200)
  checkPii(@Body() dto: CheckDescriptionPiiDto) {
    return this.service.checkDescriptionForIdentityClues(dto);
  }

  @Post(["complaints/scrub-metadata", "module2/complaints/scrub-metadata"])
  @HttpCode(200)
  scrubMetadata(@Body() dto: ScrubEvidenceMetadataDto) {
    return this.service.scrubEvidenceMetadata(dto);
  }

  @Post(["complaints", "module2/complaints"])
  @HttpCode(201)
  submitComplaint(
    @Headers("authorization") authorization: string | undefined,
    @Body() dto: SubmitDiscreetComplaintDto,
  ) {
    return this.service.submitComplaint(authorization, dto);
  }

  @Get(["complaints/track/:referenceNumber", "module2/complaints/track/:referenceNumber"])
  trackByReference(
    @Param("referenceNumber") referenceNumber: string,
    @Query("passkey") passkey?: string,
  ) {
    return this.service.trackByReference(referenceNumber, passkey);
  }

  @Post([
    "complaints/track/:referenceNumber/reply",
    "module2/complaints/track/:referenceNumber/reply",
  ])
  @HttpCode(200)
  addComplainantReply(
    @Param("referenceNumber") referenceNumber: string,
    @Body() dto: AddComplainantReplyDto,
  ) {
    return this.service.addComplainantReply(referenceNumber, dto);
  }

  @Post([
    "complaints/track/:referenceNumber/appeal",
    "module2/complaints/track/:referenceNumber/appeal",
  ])
  @HttpCode(200)
  submitAppeal(
    @Param("referenceNumber") referenceNumber: string,
    @Body() dto: SubmitComplaintAppealDto,
  ) {
    return this.service.submitAppeal(referenceNumber, dto);
  }

  @Delete([
    "complaints/track/:referenceNumber/media",
    "module2/complaints/track/:referenceNumber/media",
  ])
  @HttpCode(200)
  purgeMedia(@Param("referenceNumber") referenceNumber: string) {
    return this.service.purgeComplainantMedia(referenceNumber);
  }

  // ===========================================================================
  // Admin Complaint Management Endpoints (/api/v1/admin-review/complaints*)
  // ===========================================================================

  @Get(["admin-review/complaints", "complaints/admin/queue"])
  adminDashboardAndQueue(
    @Headers("x-sakhi-admin-token") token?: string,
    @Headers("x-sakhi-admin-review-token") altToken?: string,
    @Headers("x-sakhi-staging-admin-session") stagingSessionToken?: string,
    @Query("status") status?: string,
    @Query("priority") priority?: string,
    @Query("severity") severity?: string,
    @Query("reportingMode") reportingMode?: string,
    @Query("categorySlug") categorySlug?: string,
    @Query("search") search?: string,
    @Query("page") page?: string,
    @Query("pageSize") pageSize?: string,
    @Query("viewerRole") viewerRole?: string,
  ) {
    return this.service.adminDashboardAndQueue(
      pickAdminToken(token, altToken, stagingSessionToken),
      {
        status,
        priority,
        severity,
        reportingMode,
        categorySlug,
        search,
        page: page ? Number.parseInt(page, 10) : 1,
        pageSize: pageSize ? Number.parseInt(pageSize, 10) : 20,
        viewerRole,
      },
    );
  }

  @Patch([
    "admin-review/complaints/:referenceNumber/assign",
    "complaints/admin/:referenceNumber/assign",
  ])
  adminAssignAndClassify(
    @Param("referenceNumber") referenceNumber: string,
    @Body() dto: AssignAndClassifyComplaintDto,
    @Headers("x-sakhi-admin-token") token?: string,
    @Headers("x-sakhi-admin-review-token") altToken?: string,
    @Headers("x-sakhi-staging-admin-session") stagingSessionToken?: string,
  ) {
    return this.service.adminAssignAndClassify(
      pickAdminToken(token, altToken, stagingSessionToken),
      referenceNumber,
      dto,
    );
  }

  @Post([
    "admin-review/complaints/:referenceNumber/status",
    "complaints/admin/:referenceNumber/status",
  ])
  @HttpCode(200)
  adminUpdateStatus(
    @Param("referenceNumber") referenceNumber: string,
    @Body() dto: UpdateComplaintStatusDto,
    @Headers("x-sakhi-admin-token") token?: string,
    @Headers("x-sakhi-admin-review-token") altToken?: string,
    @Headers("x-sakhi-staging-admin-session") stagingSessionToken?: string,
  ) {
    return this.service.adminUpdateStatusAndEscalate(
      pickAdminToken(token, altToken, stagingSessionToken),
      referenceNumber,
      dto,
    );
  }

  @Post([
    "admin-review/complaints/:referenceNumber/internal-notes",
    "complaints/admin/:referenceNumber/internal-notes",
  ])
  @HttpCode(201)
  adminAddInternalNote(
    @Param("referenceNumber") referenceNumber: string,
    @Body() dto: AddComplaintInternalNoteDto,
    @Headers("x-sakhi-admin-token") token?: string,
    @Headers("x-sakhi-admin-review-token") altToken?: string,
    @Headers("x-sakhi-staging-admin-session") stagingSessionToken?: string,
  ) {
    return this.service.adminAddInternalNote(
      pickAdminToken(token, altToken, stagingSessionToken),
      referenceNumber,
      dto,
    );
  }

  @Post([
    "admin-review/complaints/:referenceNumber/evidence-access",
    "complaints/admin/:referenceNumber/evidence-access",
  ])
  @HttpCode(200)
  adminAccessEvidence(
    @Param("referenceNumber") referenceNumber: string,
    @Body() dto: AccessComplaintEvidenceDto,
    @Headers("x-sakhi-admin-token") token?: string,
    @Headers("x-sakhi-admin-review-token") altToken?: string,
    @Headers("x-sakhi-staging-admin-session") stagingSessionToken?: string,
  ) {
    return this.service.adminAccessControlledEvidence(
      pickAdminToken(token, altToken, stagingSessionToken),
      referenceNumber,
      dto,
    );
  }

  @Post([
    "admin-review/complaints/merge-duplicates",
    "complaints/admin/merge-duplicates",
  ])
  @HttpCode(200)
  adminMergeDuplicates(
    @Body() dto: MergeDuplicateComplaintsDto,
    @Headers("x-sakhi-admin-token") token?: string,
    @Headers("x-sakhi-admin-review-token") altToken?: string,
    @Headers("x-sakhi-staging-admin-session") stagingSessionToken?: string,
  ) {
    return this.service.adminMergeDuplicateComplaints(
      pickAdminToken(token, altToken, stagingSessionToken),
      dto,
    );
  }

  @Post([
    "admin-review/complaints/:referenceNumber/malicious-guard",
    "complaints/admin/:referenceNumber/malicious-guard",
  ])
  @HttpCode(200)
  adminHandleMalicious(
    @Param("referenceNumber") referenceNumber: string,
    @Body() dto: HandleMaliciousComplaintDto,
    @Headers("x-sakhi-admin-token") token?: string,
    @Headers("x-sakhi-admin-review-token") altToken?: string,
    @Headers("x-sakhi-staging-admin-session") stagingSessionToken?: string,
  ) {
    return this.service.adminHandleMaliciousReport(
      pickAdminToken(token, altToken, stagingSessionToken),
      referenceNumber,
      dto,
    );
  }

  @Put(["admin-review/complaints/categories", "complaints/admin/categories"])
  adminUpsertCategory(
    @Body() dto: UpsertComplaintCategoryConfigDto,
    @Headers("x-sakhi-admin-token") token?: string,
    @Headers("x-sakhi-admin-review-token") altToken?: string,
    @Headers("x-sakhi-staging-admin-session") stagingSessionToken?: string,
  ) {
    return this.service.adminUpsertCategory(
      pickAdminToken(token, altToken, stagingSessionToken),
      dto,
    );
  }

  @Put([
    "admin-review/complaints/retention-policy",
    "complaints/admin/retention-policy",
  ])
  adminUpdateRetentionPolicy(
    @Body() dto: UpdateComplaintRetentionPolicyDto,
    @Headers("x-sakhi-admin-token") token?: string,
    @Headers("x-sakhi-admin-review-token") altToken?: string,
    @Headers("x-sakhi-staging-admin-session") stagingSessionToken?: string,
  ) {
    return this.service.adminUpdateRetentionPolicy(
      pickAdminToken(token, altToken, stagingSessionToken),
      dto,
    );
  }
}
