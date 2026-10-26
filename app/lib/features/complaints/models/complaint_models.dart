import 'package:flutter/material.dart';

import '../../../core/widgets/sakhi_botanical_flower.dart';

/// SRS Section 7.2 — Reporting Modes
enum ComplaintReportingMode {
  anonymous(
    code: 'ANONYMOUS',
    title: 'Anonymous Reporting',
    subtitle: 'Maximum Privacy • Zero Identity Link',
    badgeLabel: 'ANONYMOUS MODE',
    description:
        'Your name, handle, phone number, and profile ID are completely detached from the complaint record. Neither the reported party nor standard moderators can see who submitted it.',
  ),
  confidential(
    code: 'CONFIDENTIAL',
    title: 'Confidential Reporting',
    subtitle: 'Identity Hidden from Public • Senior Safety Team Only',
    badgeLabel: 'CONFIDENTIAL MODE',
    description:
        'Hidden from the reported user and the public community, but visible only to authorised Senior Female Safety Reviewers so our team can follow up with you directly.',
  );

  const ComplaintReportingMode({
    required this.code,
    required this.title,
    required this.subtitle,
    required this.badgeLabel,
    required this.description,
  });

  final String code;
  final String title;
  final String subtitle;
  final String badgeLabel;
  final String description;

  static ComplaintReportingMode fromCode(String? raw) {
    if (raw == 'CONFIDENTIAL') return ComplaintReportingMode.confidential;
    return ComplaintReportingMode.anonymous;
  }
}

/// SRS Section 7.3 — Complaint Categories (10 configurable categories)
class ComplaintCategoryInfo {
  const ComplaintCategoryInfo({
    required this.id,
    required this.code,
    required this.label,
    required this.shortLabel,
    required this.subtitle,
    required this.safetyGuidance,
    required this.defaultSeverity,
    required this.icon,
    required this.flowerType,
    this.enabled = true,
  });

  final String id;
  final String code;
  final String label;
  final String shortLabel;
  final String subtitle;
  final String safetyGuidance;
  final String defaultSeverity;
  final IconData icon;
  final SakhiFlowerType flowerType;
  final bool enabled;

  ComplaintCategoryInfo copyWith({
    String? label,
    String? shortLabel,
    String? subtitle,
    String? safetyGuidance,
    String? defaultSeverity,
    bool? enabled,
  }) {
    return ComplaintCategoryInfo(
      id: id,
      code: code,
      label: label ?? this.label,
      shortLabel: shortLabel ?? this.shortLabel,
      subtitle: subtitle ?? this.subtitle,
      safetyGuidance: safetyGuidance ?? this.safetyGuidance,
      defaultSeverity: defaultSeverity ?? this.defaultSeverity,
      icon: icon,
      flowerType: flowerType,
      enabled: enabled ?? this.enabled,
    );
  }
}

/// SRS Section 7.5 — 7 Complaint Statuses
enum ComplaintStatus {
  submitted(
    code: 'SUBMITTED',
    label: 'Submitted',
    stepIndex: 0,
    badgeBg: Color(0xFFF3E4F8),
    badgeText: Color(0xFF5A1868),
    summary:
        'Your complaint has been encrypted, stripped of device EXIF metadata, and queued for our authorised safety review team.',
  ),
  underReview(
    code: 'UNDER_REVIEW',
    label: 'Under Review',
    stepIndex: 1,
    badgeBg: Color(0xFFEDE0F5),
    badgeText: Color(0xFF6B2D86),
    summary:
        'An authorised Senior Safety Reviewer has been assigned and is actively examining the evidence vault and linked context.',
  ),
  additionalInfoRequired(
    code: 'ADDITIONAL_INFORMATION_REQUIRED',
    label: 'Additional Information Required',
    stepIndex: 2,
    badgeBg: Color(0xFFFFF4DC),
    badgeText: Color(0xFFA86408),
    summary:
        'The reviewer needs a brief clarification or supporting screenshot. You can reply below without revealing your identity.',
  ),
  escalated(
    code: 'ESCALATED',
    label: 'Escalated',
    stepIndex: 3,
    badgeBg: Color(0xFFFDE2E8),
    badgeText: Color(0xFFB81E43),
    summary:
        'Escalated to the Trust & Safety Legal Panel / POSH Desk for high-priority protective enforcement.',
  ),
  actionTaken(
    code: 'ACTION_TAKEN',
    label: 'Action Taken',
    stepIndex: 4,
    badgeBg: Color(0xFFDFF4EC),
    badgeText: Color(0xFF1A6B4F),
    summary:
        'Protective enforcement completed. The reported violation has been actioned under Sakhi Safety Policy.',
  ),
  closed(
    code: 'CLOSED',
    label: 'Closed',
    stepIndex: 5,
    badgeBg: Color(0xFFEAF0EE),
    badgeText: Color(0xFF335248),
    summary:
        'This case is resolved and archived under DPDP data-minimization rules. You may purge your uploaded evidence anytime.',
  ),
  rejectedWithReason(
    code: 'REJECTED_WITH_REASON',
    label: 'Rejected with Reason',
    stepIndex: 5,
    badgeBg: Color(0xFFF9E6EC),
    badgeText: Color(0xFF8C2D4B),
    summary:
        'Closed with a transparent moderator explanation. You may submit a one-tap Appeal with additional context.',
  );

  const ComplaintStatus({
    required this.code,
    required this.label,
    required this.stepIndex,
    required this.badgeBg,
    required this.badgeText,
    required this.summary,
  });

  final String code;
  final String label;
  final int stepIndex;
  final Color badgeBg;
  final Color badgeText;
  final String summary;

  static ComplaintStatus fromCode(String? raw) {
    for (final status in ComplaintStatus.values) {
      if (status.code == raw) return status;
    }
    return ComplaintStatus.submitted;
  }
}

class SanitizedEvidenceFileModel {
  const SanitizedEvidenceFileModel({
    required this.id,
    required this.originalLabel,
    required this.sanitizedFileName,
    required this.mimeType,
    required this.sizeBytes,
    required this.sha256Hash,
    required this.exifScrubbed,
    required this.removedTags,
    required this.blurredByDefault,
    required this.uploadedAtIso,
  });

  final String id;
  final String originalLabel;
  final String sanitizedFileName;
  final String mimeType;
  final int sizeBytes;
  final String sha256Hash;
  final bool exifScrubbed;
  final List<String> removedTags;
  final bool blurredByDefault;
  final String uploadedAtIso;

  String get formattedSize {
    if (sizeBytes >= 1024 * 1024) {
      return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(sizeBytes / 1024).round()} KB';
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'originalLabel': originalLabel,
    'sanitizedFileName': sanitizedFileName,
    'mimeType': mimeType,
    'sizeBytes': sizeBytes,
    'sha256Hash': sha256Hash,
    'exifScrubbed': exifScrubbed,
    'removedTags': removedTags,
    'blurredByDefault': blurredByDefault,
    'uploadedAtIso': uploadedAtIso,
  };
}

class ComplainantMessageModel {
  const ComplainantMessageModel({
    required this.id,
    required this.senderRole,
    required this.senderBadge,
    required this.body,
    required this.createdAtLabel,
    this.attachmentNames = const <String>[],
  });

  final String id;
  final String senderRole; // REVIEWER or COMPLAINANT
  final String senderBadge;
  final String body;
  final String createdAtLabel;
  final List<String> attachmentNames;

  bool get isFromReviewer => senderRole == 'REVIEWER';
}

class InternalReviewerNoteModel {
  const InternalReviewerNoteModel({
    required this.id,
    required this.authorRole,
    required this.authorLabel,
    required this.note,
    required this.visibilityScope,
    required this.createdAtLabel,
  });

  final String id;
  final String authorRole;
  final String authorLabel;
  final String note;
  final String visibilityScope;
  final String createdAtLabel;
}

class ComplaintAuditEntryModel {
  const ComplaintAuditEntryModel({
    required this.id,
    required this.action,
    required this.actorBadge,
    required this.detail,
    required this.integrityHash,
    required this.timestampLabel,
  });

  final String id;
  final String action;
  final String actorBadge;
  final String detail;
  final String integrityHash;
  final String timestampLabel;
}

class PiiDetectedItemModel {
  const PiiDetectedItemModel({
    required this.type,
    required this.snippet,
    required this.replacement,
  });

  final String type;
  final String snippet;
  final String replacement;
}

class PiiCheckResultModel {
  const PiiCheckResultModel({
    required this.hasPotentialPii,
    required this.detectedItems,
    required this.redactedText,
  });

  final bool hasPotentialPii;
  final List<PiiDetectedItemModel> detectedItems;
  final String redactedText;
}

class DiscreetComplaintModel {
  const DiscreetComplaintModel({
    required this.id,
    required this.referenceNumber,
    required this.passkey,
    required this.disguisedSerialTag,
    required this.reportingMode,
    required this.categoryCode,
    required this.customCategoryNote,
    required this.urgencyLevel,
    required this.status,
    required this.severityPriority,
    required this.description,
    required this.incidentDateWindow,
    required this.generalAreaText,
    required this.supportingLinks,
    required this.linkedPostId,
    required this.linkedProfileHandle,
    required this.linkedBusinessId,
    required this.wantsFollowUp,
    required this.discreetNotificationMode,
    required this.evidenceFiles,
    required this.complainantMessages,
    required this.internalNotes,
    required this.auditTrail,
    required this.assignedReviewerName,
    required this.assignedDepartment,
    required this.slaTargetHours,
    required this.createdAtLabel,
    required this.updatedAtLabel,
    this.publicResolutionNote,
    this.rejectionReasonTitle,
    this.rejectionReasonDetail,
    this.appealSubmitted = false,
    this.appealReasonText,
    this.mediaPurgedByUser = false,
    this.duplicateOfReference,
    this.duplicateClusterCount = 1,
    this.maliciousAbuseFlagged = false,
    this.maskedConfidentialContact,
  });

  final String id;
  final String referenceNumber;
  final String passkey;
  final String disguisedSerialTag;
  final ComplaintReportingMode reportingMode;
  final String categoryCode;
  final String? customCategoryNote;
  final String urgencyLevel;
  final ComplaintStatus status;
  final String severityPriority; // CRITICAL_P1, HIGH_P2, MEDIUM_P3, LOW_P4
  final String description;
  final String incidentDateWindow;
  final String generalAreaText;
  final List<String> supportingLinks;
  final String? linkedPostId;
  final String? linkedProfileHandle;
  final String? linkedBusinessId;
  final bool wantsFollowUp;
  final String discreetNotificationMode;
  final List<SanitizedEvidenceFileModel> evidenceFiles;
  final List<ComplainantMessageModel> complainantMessages;
  final List<InternalReviewerNoteModel> internalNotes;
  final List<ComplaintAuditEntryModel> auditTrail;
  final String assignedReviewerName;
  final String assignedDepartment;
  final int slaTargetHours;
  final String createdAtLabel;
  final String updatedAtLabel;
  final String? publicResolutionNote;
  final String? rejectionReasonTitle;
  final String? rejectionReasonDetail;
  final bool appealSubmitted;
  final String? appealReasonText;
  final bool mediaPurgedByUser;
  final String? duplicateOfReference;
  final int duplicateClusterCount;
  final bool maliciousAbuseFlagged;
  final String? maskedConfidentialContact;

  DiscreetComplaintModel copyWith({
    ComplaintStatus? status,
    String? severityPriority,
    List<SanitizedEvidenceFileModel>? evidenceFiles,
    List<ComplainantMessageModel>? complainantMessages,
    List<InternalReviewerNoteModel>? internalNotes,
    List<ComplaintAuditEntryModel>? auditTrail,
    String? assignedReviewerName,
    String? assignedDepartment,
    int? slaTargetHours,
    String? updatedAtLabel,
    String? publicResolutionNote,
    String? rejectionReasonTitle,
    String? rejectionReasonDetail,
    bool? appealSubmitted,
    String? appealReasonText,
    bool? mediaPurgedByUser,
    String? duplicateOfReference,
    int? duplicateClusterCount,
    bool? maliciousAbuseFlagged,
  }) {
    return DiscreetComplaintModel(
      id: id,
      referenceNumber: referenceNumber,
      passkey: passkey,
      disguisedSerialTag: disguisedSerialTag,
      reportingMode: reportingMode,
      categoryCode: categoryCode,
      customCategoryNote: customCategoryNote,
      urgencyLevel: urgencyLevel,
      status: status ?? this.status,
      severityPriority: severityPriority ?? this.severityPriority,
      description: description,
      incidentDateWindow: incidentDateWindow,
      generalAreaText: generalAreaText,
      supportingLinks: supportingLinks,
      linkedPostId: linkedPostId,
      linkedProfileHandle: linkedProfileHandle,
      linkedBusinessId: linkedBusinessId,
      wantsFollowUp: wantsFollowUp,
      discreetNotificationMode: discreetNotificationMode,
      evidenceFiles: evidenceFiles ?? this.evidenceFiles,
      complainantMessages: complainantMessages ?? this.complainantMessages,
      internalNotes: internalNotes ?? this.internalNotes,
      auditTrail: auditTrail ?? this.auditTrail,
      assignedReviewerName: assignedReviewerName ?? this.assignedReviewerName,
      assignedDepartment: assignedDepartment ?? this.assignedDepartment,
      slaTargetHours: slaTargetHours ?? this.slaTargetHours,
      createdAtLabel: createdAtLabel,
      updatedAtLabel: updatedAtLabel ?? this.updatedAtLabel,
      publicResolutionNote: publicResolutionNote ?? this.publicResolutionNote,
      rejectionReasonTitle: rejectionReasonTitle ?? this.rejectionReasonTitle,
      rejectionReasonDetail:
          rejectionReasonDetail ?? this.rejectionReasonDetail,
      appealSubmitted: appealSubmitted ?? this.appealSubmitted,
      appealReasonText: appealReasonText ?? this.appealReasonText,
      mediaPurgedByUser: mediaPurgedByUser ?? this.mediaPurgedByUser,
      duplicateOfReference: duplicateOfReference ?? this.duplicateOfReference,
      duplicateClusterCount:
          duplicateClusterCount ?? this.duplicateClusterCount,
      maliciousAbuseFlagged:
          maliciousAbuseFlagged ?? this.maliciousAbuseFlagged,
      maskedConfidentialContact: maskedConfidentialContact,
    );
  }
}

class ComplaintRetentionPolicyModel {
  const ComplaintRetentionPolicyModel({
    required this.closedCaseRetentionDays,
    required this.rejectedCaseRetentionDays,
    required this.autoPurgeRawMediaAfterDays,
    required this.scrubIpLogsAfterHours,
    required this.allowUserImmediateMediaPurge,
    required this.dpdpComplianceNote,
  });

  final int closedCaseRetentionDays;
  final int rejectedCaseRetentionDays;
  final int autoPurgeRawMediaAfterDays;
  final int scrubIpLogsAfterHours;
  final bool allowUserImmediateMediaPurge;
  final String dpdpComplianceNote;

  ComplaintRetentionPolicyModel copyWith({
    int? closedCaseRetentionDays,
    int? rejectedCaseRetentionDays,
    int? autoPurgeRawMediaAfterDays,
    int? scrubIpLogsAfterHours,
    bool? allowUserImmediateMediaPurge,
    String? dpdpComplianceNote,
  }) {
    return ComplaintRetentionPolicyModel(
      closedCaseRetentionDays:
          closedCaseRetentionDays ?? this.closedCaseRetentionDays,
      rejectedCaseRetentionDays:
          rejectedCaseRetentionDays ?? this.rejectedCaseRetentionDays,
      autoPurgeRawMediaAfterDays:
          autoPurgeRawMediaAfterDays ?? this.autoPurgeRawMediaAfterDays,
      scrubIpLogsAfterHours: scrubIpLogsAfterHours ?? this.scrubIpLogsAfterHours,
      allowUserImmediateMediaPurge:
          allowUserImmediateMediaPurge ?? this.allowUserImmediateMediaPurge,
      dpdpComplianceNote: dpdpComplianceNote ?? this.dpdpComplianceNote,
    );
  }
}
