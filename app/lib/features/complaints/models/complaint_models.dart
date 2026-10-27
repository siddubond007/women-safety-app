import 'package:flutter/material.dart';

import '../../../core/widgets/sakhi_botanical_flower.dart';

/// SRS Section 7.2 & 7.4 — Reporting Modes
enum ComplaintReportingMode {
  anonymous(
    code: 'ANONYMOUS',
    title: 'Anonymous Reporting',
    subtitle: 'Profile Detached • Zero Account ID Stored',
    badgeLabel: 'ANONYMOUS MODE',
    description:
        'Your Sakhi profile ID, display name, and phone number are detached and not stored on the complaint record. Neither the reported party nor moderators can link the complaint to your account.',
  ),
  confidential(
    code: 'CONFIDENTIAL',
    title: 'Confidential Reporting',
    subtitle: 'Hidden from Public & Target • Senior Safety Team Only',
    badgeLabel: 'CONFIDENTIAL MODE',
    description:
        'Requires an active signed-in member session. Completely hidden from the reported user, public feed, and standard moderators, but accessible to authorised Senior Safety Reviewers for direct follow-up.',
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
    if (raw?.toUpperCase() == 'CONFIDENTIAL') {
      return ComplaintReportingMode.confidential;
    }
    return ComplaintReportingMode.anonymous;
  }
}

/// SRS Section 7.2 — 10 Configurable Complaint Categories
class ComplaintCategoryInfo {
  const ComplaintCategoryInfo({
    required this.id,
    required this.code,
    required this.label,
    required this.shortLabel,
    required this.subtitle,
    required this.safetyGuidance,
    required this.legalHelplineNote,
    required this.defaultPriority,
    required this.defaultSeverity,
    required this.icon,
    required this.flowerType,
    this.enabled = true,
    this.displayOrder = 1,
  });

  final String id;
  final String code; // slug on backend, e.g. 'harassment'
  final String label;
  final String shortLabel;
  final String subtitle;
  final String safetyGuidance;
  final String legalHelplineNote;
  final String defaultPriority;
  final String defaultSeverity;
  final IconData icon;
  final SakhiFlowerType flowerType;
  final bool enabled;
  final int displayOrder;

  ComplaintCategoryInfo copyWith({
    String? label,
    String? shortLabel,
    String? subtitle,
    String? safetyGuidance,
    String? legalHelplineNote,
    String? defaultPriority,
    String? defaultSeverity,
    bool? enabled,
    int? displayOrder,
  }) {
    return ComplaintCategoryInfo(
      id: id,
      code: code,
      label: label ?? this.label,
      shortLabel: shortLabel ?? this.shortLabel,
      subtitle: subtitle ?? this.subtitle,
      safetyGuidance: safetyGuidance ?? this.safetyGuidance,
      legalHelplineNote: legalHelplineNote ?? this.legalHelplineNote,
      defaultPriority: defaultPriority ?? this.defaultPriority,
      defaultSeverity: defaultSeverity ?? this.defaultSeverity,
      icon: icon,
      flowerType: flowerType,
      enabled: enabled ?? this.enabled,
      displayOrder: displayOrder ?? this.displayOrder,
    );
  }

  factory ComplaintCategoryInfo.fromBackendJson(
    Map<String, dynamic> json, {
    ComplaintCategoryInfo? fallback,
  }) {
    final slug = (json['slug'] as String? ?? fallback?.code ?? 'other')
        .trim()
        .toLowerCase();
    final name = (json['name'] as String? ?? fallback?.label ?? 'Other').trim();
    return ComplaintCategoryInfo(
      id: 'cat-$slug',
      code: slug,
      label: name,
      shortLabel: fallback?.shortLabel ?? name,
      subtitle:
          (json['description'] as String? ?? fallback?.subtitle ?? '').trim(),
      safetyGuidance:
          (json['safetyGuidanceText'] as String? ??
                  fallback?.safetyGuidance ??
                  '')
              .trim(),
      legalHelplineNote:
          (json['legalHelplineNote'] as String? ??
                  fallback?.legalHelplineNote ??
                  'Dial 112 or 1091 for immediate police assistance.')
              .trim(),
      defaultPriority:
          (json['defaultPriority'] as String? ??
                  fallback?.defaultPriority ??
                  'P2_HIGH')
              .trim(),
      defaultSeverity:
          (json['defaultSeverity'] as String? ??
                  fallback?.defaultSeverity ??
                  'S2_HIGH')
              .trim(),
      icon: fallback?.icon ?? Icons.shield_outlined,
      flowerType: fallback?.flowerType ?? SakhiFlowerType.roseClassic,
      enabled: json['isEnabled'] is bool
          ? json['isEnabled'] as bool
          : (fallback?.enabled ?? true),
      displayOrder: json['displayOrder'] is int
          ? json['displayOrder'] as int
          : (fallback?.displayOrder ?? 1),
    );
  }
}

/// SRS Section 7.5 — 7 Supported Complaint Statuses
enum ComplaintStatus {
  submitted(
    code: 'SUBMITTED',
    label: 'Submitted',
    stepIndex: 0,
    badgeBg: Color(0xFFF3E4F8),
    badgeText: Color(0xFF5A1868),
    summary:
        'Your complaint has been encrypted, stripped of EXIF metadata, and queued for our authorised safety review team.',
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
    code: 'ADDITIONAL_INFO_REQUIRED',
    label: 'Additional Information Required',
    stepIndex: 2,
    badgeBg: Color(0xFFFFF4DC),
    badgeText: Color(0xFFA86408),
    summary:
        'The reviewer needs a brief clarification or supporting screenshot. You can reply below using your passkey without revealing your identity.',
  ),
  escalated(
    code: 'ESCALATED',
    label: 'Escalated',
    stepIndex: 3,
    badgeBg: Color(0xFFFDE2E8),
    badgeText: Color(0xFFB81E43),
    summary:
        'Escalated to the Senior Trust & Safety Specialist Desk for high-priority protective enforcement.',
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
        'Closed with a transparent moderator explanation. You may submit an Appeal with additional context.',
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
    final norm = raw?.trim().toUpperCase();
    if (norm == 'ADDITIONAL_INFORMATION_REQUIRED' ||
        norm == 'ADDITIONAL_INFO_REQUIRED') {
      return ComplaintStatus.additionalInfoRequired;
    }
    for (final status in ComplaintStatus.values) {
      if (status.code == norm) return status;
    }
    return ComplaintStatus.submitted;
  }

  /// Valid next status transitions enforced by SRS 7.5
  List<ComplaintStatus> get allowedTransitions {
    switch (this) {
      case ComplaintStatus.submitted:
        return const <ComplaintStatus>[
          ComplaintStatus.underReview,
          ComplaintStatus.additionalInfoRequired,
          ComplaintStatus.escalated,
          ComplaintStatus.actionTaken,
          ComplaintStatus.rejectedWithReason,
        ];
      case ComplaintStatus.underReview:
      case ComplaintStatus.additionalInfoRequired:
      case ComplaintStatus.escalated:
        return const <ComplaintStatus>[
          ComplaintStatus.underReview,
          ComplaintStatus.additionalInfoRequired,
          ComplaintStatus.escalated,
          ComplaintStatus.actionTaken,
          ComplaintStatus.closed,
          ComplaintStatus.rejectedWithReason,
        ];
      case ComplaintStatus.actionTaken:
        return const <ComplaintStatus>[
          ComplaintStatus.closed,
          ComplaintStatus.escalated,
          ComplaintStatus.underReview,
        ];
      case ComplaintStatus.closed:
      case ComplaintStatus.rejectedWithReason:
        return const <ComplaintStatus>[
          ComplaintStatus.escalated,
          ComplaintStatus.underReview,
        ];
    }
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
    this.isPurged = false,
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
  final bool isPurged;

  String get formattedSize {
    if (isPurged) return 'Purged (0 B)';
    if (sizeBytes >= 1024 * 1024) {
      return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(sizeBytes / 1024).clamp(1, 99999).round()} KB';
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'fileName': sanitizedFileName,
    'originalFileNameRedacted': originalLabel,
    'contentType': mimeType,
    'byteSize': sizeBytes,
    'sha256Digest': sha256Hash,
    'exifGpsStripped': exifScrubbed,
    'deviceMetadataStripped': true,
    'visualBlurApplied': blurredByDefault,
    'scrubbedFields': removedTags,
    'uploadedAt': uploadedAtIso,
    'isPurged': isPurged,
  };

  factory SanitizedEvidenceFileModel.fromBackendJson(
    Map<String, dynamic> json,
  ) {
    final rawFields = json['scrubbedFields'] ?? json['removedTags'];
    final tags = rawFields is List
        ? rawFields.map((e) => e.toString()).toList(growable: false)
        : const <String>['EXIF.GPS', 'EXIF.DeviceModel'];
    return SanitizedEvidenceFileModel(
      id: (json['id'] as String? ?? 'ev_unknown').trim(),
      originalLabel:
          (json['originalFileNameRedacted'] as String? ??
                  json['originalLabel'] as String? ??
                  '[REDACTED]')
              .trim(),
      sanitizedFileName:
          (json['fileName'] as String? ??
                  json['sanitizedFileName'] as String? ??
                  'evidence_redacted.png')
              .trim(),
      mimeType:
          (json['contentType'] as String? ??
                  json['mimeType'] as String? ??
                  'image/png')
              .trim(),
      sizeBytes: (json['byteSize'] as num? ?? json['sizeBytes'] as num? ?? 0)
          .toInt(),
      sha256Hash:
          (json['sha256Digest'] as String? ??
                  json['sha256Hash'] as String? ??
                  '')
              .trim(),
      exifScrubbed: json['exifGpsStripped'] is bool
          ? json['exifGpsStripped'] as bool
          : true,
      removedTags: tags,
      blurredByDefault: json['visualBlurApplied'] is bool
          ? json['visualBlurApplied'] as bool
          : true,
      uploadedAtIso:
          (json['uploadedAt'] as String? ??
                  json['uploadedAtIso'] as String? ??
                  '')
              .trim(),
      isPurged: json['isPurged'] == true,
    );
  }
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
  final String senderRole;
  final String senderBadge;
  final String body;
  final String createdAtLabel;
  final List<String> attachmentNames;

  bool get isFromReviewer =>
      senderRole == 'SAFETY_REVIEWER' || senderRole == 'REVIEWER';

  factory ComplainantMessageModel.fromBackendJson(Map<String, dynamic> json) {
    final files = json['attachedFiles'];
    final names = files is List
        ? files
              .whereType<Map<String, dynamic>>()
              .map((f) => (f['fileName'] as String? ?? 'attachment').trim())
              .toList(growable: false)
        : const <String>[];
    return ComplainantMessageModel(
      id: (json['id'] as String? ?? 'msg').trim(),
      senderRole: (json['senderRole'] as String? ?? 'SAFETY_REVIEWER').trim(),
      senderBadge: (json['senderLabel'] as String? ??
              json['senderBadge'] as String? ??
              'Safety Reviewer')
          .trim(),
      body: (json['message'] as String? ?? json['body'] as String? ?? '')
          .trim(),
      createdAtLabel:
          (json['createdAt'] as String? ??
                  json['createdAtLabel'] as String? ??
                  '')
              .trim(),
      attachmentNames: names,
    );
  }
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

  factory InternalReviewerNoteModel.fromBackendJson(Map<String, dynamic> json) {
    return InternalReviewerNoteModel(
      id: (json['id'] as String? ?? 'note').trim(),
      authorRole: (json['visibilityRole'] as String? ?? 'SENIOR_REVIEWER')
          .trim(),
      authorLabel: (json['reviewerName'] as String? ?? 'Safety Reviewer')
          .trim(),
      note: (json['noteText'] as String? ?? '').trim(),
      visibilityScope: (json['visibilityRole'] as String? ?? 'SENIOR_REVIEWER')
          .trim(),
      createdAtLabel: (json['createdAt'] as String? ?? '').trim(),
    );
  }
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

  factory ComplaintAuditEntryModel.fromBackendJson(Map<String, dynamic> json) {
    final code = (json['auditCode'] as String? ?? '').trim();
    final act = (json['action'] as String? ?? '').trim();
    return ComplaintAuditEntryModel(
      id: (json['id'] as String? ?? 'aud').trim(),
      action: code.isNotEmpty ? '$code • $act' : act,
      actorBadge: (json['actorLabel'] as String? ??
              json['actorRole'] as String? ??
              'System')
          .trim(),
      detail: (json['summary'] as String? ?? '').trim(),
      integrityHash: (json['integrityHash'] as String? ?? 'SHA256:verified')
          .trim(),
      timestampLabel: (json['timestamp'] as String? ?? '').trim(),
    );
  }
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
    required this.categoryTitle,
    required this.customCategoryNote,
    required this.urgencyLevel,
    required this.status,
    required this.severity,
    required this.priority,
    required this.description,
    required this.approximateDateLabel,
    required this.approximateTimeWindow,
    required this.locationType,
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
    this.duplicateClusterId,
    this.maliciousAbuseFlagged = false,
    this.maskedConfidentialContact,
  });

  final String id;
  final String referenceNumber;
  final String passkey;
  final String disguisedSerialTag;
  final ComplaintReportingMode reportingMode;
  final String categoryCode;
  final String categoryTitle;
  final String? customCategoryNote;
  final String urgencyLevel;
  final ComplaintStatus status;
  final String severity;
  final String priority;
  final String description;
  final String approximateDateLabel;
  final String approximateTimeWindow;
  final String locationType;
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
  final String? duplicateClusterId;
  final bool maliciousAbuseFlagged;
  final String? maskedConfidentialContact;

  String get severityPriority => '$priority • $severity';
  String get incidentDateWindow =>
      '$approximateDateLabel • $approximateTimeWindow';

  DiscreetComplaintModel copyWith({
    String? passkey,
    ComplaintStatus? status,
    String? severity,
    String? priority,
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
    String? duplicateClusterId,
    bool? maliciousAbuseFlagged,
  }) {
    return DiscreetComplaintModel(
      id: id,
      referenceNumber: referenceNumber,
      passkey: passkey ?? this.passkey,
      disguisedSerialTag: disguisedSerialTag,
      reportingMode: reportingMode,
      categoryCode: categoryCode,
      categoryTitle: categoryTitle,
      customCategoryNote: customCategoryNote,
      urgencyLevel: urgencyLevel,
      status: status ?? this.status,
      severity: severity ?? this.severity,
      priority: priority ?? this.priority,
      description: description,
      approximateDateLabel: approximateDateLabel,
      approximateTimeWindow: approximateTimeWindow,
      locationType: locationType,
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
      duplicateClusterId: duplicateClusterId ?? this.duplicateClusterId,
      maliciousAbuseFlagged:
          maliciousAbuseFlagged ?? this.maliciousAbuseFlagged,
      maskedConfidentialContact: maskedConfidentialContact,
    );
  }

  factory DiscreetComplaintModel.fromBackendJson(
    Map<String, dynamic> json, {
    String? knownPasskey,
  }) {
    final rawEvidence = json['evidenceFiles'];
    final evidenceList = rawEvidence is List
        ? rawEvidence
              .whereType<Map<String, dynamic>>()
              .map(SanitizedEvidenceFileModel.fromBackendJson)
              .toList(growable: false)
        : const <SanitizedEvidenceFileModel>[];

    final rawMessages = json['complainantMessages'];
    final messageList = rawMessages is List
        ? rawMessages
              .whereType<Map<String, dynamic>>()
              .map(ComplainantMessageModel.fromBackendJson)
              .toList(growable: false)
        : const <ComplainantMessageModel>[];

    final rawNotes = json['internalNotes'];
    final noteList = rawNotes is List
        ? rawNotes
              .whereType<Map<String, dynamic>>()
              .map(InternalReviewerNoteModel.fromBackendJson)
              .toList(growable: false)
        : const <InternalReviewerNoteModel>[];

    final rawAudit = json['auditHistory'];
    final auditList = rawAudit is List
        ? rawAudit
              .whereType<Map<String, dynamic>>()
              .map(ComplaintAuditEntryModel.fromBackendJson)
              .toList(growable: false)
        : const <ComplaintAuditEntryModel>[];

    final rawLinks = json['supportingLinks'];
    final linkList = rawLinks is List
        ? rawLinks
              .map((item) {
                if (item is String) return item;
                if (item is Map<String, dynamic>) {
                  return (item['url'] as String? ?? '').trim();
                }
                return '';
              })
              .where((s) => s.isNotEmpty)
              .toList(growable: false)
        : const <String>[];

    final priority = (json['priority'] as String? ?? 'P2_HIGH').trim();
    final severity = (json['severity'] as String? ?? 'S2_HIGH').trim();
    final slaHours = priority == 'P1_URGENT'
        ? 4
        : priority == 'P2_HIGH'
        ? 12
        : 24;

    return DiscreetComplaintModel(
      id: (json['id'] as String? ?? '').trim(),
      referenceNumber: (json['referenceNumber'] as String? ?? '').trim(),
      passkey: (knownPasskey ?? json['passkey'] as String? ?? '').trim(),
      disguisedSerialTag:
          (json['disguisedBackupSerial'] as String? ?? '').trim(),
      reportingMode: ComplaintReportingMode.fromCode(
        json['reportingMode'] as String?,
      ),
      categoryCode: (json['categorySlug'] as String? ?? 'harassment').trim(),
      categoryTitle: (json['categoryTitle'] as String? ?? 'Harassment').trim(),
      customCategoryNote: json['customCategoryLabel'] as String?,
      urgencyLevel: (json['urgency'] as String? ?? 'PAST_INCIDENT').trim(),
      status: ComplaintStatus.fromCode(json['status'] as String?),
      severity: severity,
      priority: priority,
      description: (json['description'] as String? ?? '').trim(),
      approximateDateLabel:
          (json['approximateDateLabel'] as String? ?? 'Recent').trim(),
      approximateTimeWindow:
          (json['approximateTimeWindow'] as String? ?? 'Unspecified').trim(),
      locationType: (json['locationType'] as String? ?? 'COARSE_AREA').trim(),
      generalAreaText:
          (json['generalLocationLabel'] as String? ??
                  'Online / Inside Sakhi App')
              .trim(),
      supportingLinks: linkList,
      linkedPostId: json['linkedPostId'] as String?,
      linkedProfileHandle: json['linkedTargetHandle'] as String?,
      linkedBusinessId: json['linkedBusinessId'] as String?,
      wantsFollowUp: json['wantsUpdates'] is bool
          ? json['wantsUpdates'] as bool
          : true,
      discreetNotificationMode: 'SILENT_VAULT_ONLY',
      evidenceFiles: evidenceList,
      complainantMessages: messageList,
      internalNotes: noteList,
      auditTrail: auditList,
      assignedReviewerName:
          (json['assignedReviewerName'] as String? ??
                  'Pending Senior Safety Triage')
              .trim(),
      assignedDepartment: 'Trust & Safety Review Desk',
      slaTargetHours: slaHours,
      createdAtLabel: (json['createdAt'] as String? ?? '').trim(),
      updatedAtLabel: (json['updatedAt'] as String? ?? '').trim(),
      publicResolutionNote: json['publicResolutionSummary'] as String?,
      rejectionReasonTitle: json['rejectionReasonCode'] as String?,
      rejectionReasonDetail: json['publicResolutionSummary'] as String?,
      mediaPurgedByUser: json['mediaPurgedAt'] != null,
      duplicateOfReference: json['mergedIntoReference'] as String?,
      duplicateClusterId: json['duplicateClusterId'] as String?,
      maliciousAbuseFlagged: json['isFlaggedMaliciousAbuse'] == true,
      maskedConfidentialContact:
          json['confidentialAccountVaultStatus'] as String?,
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
      scrubIpLogsAfterHours:
          scrubIpLogsAfterHours ?? this.scrubIpLogsAfterHours,
      allowUserImmediateMediaPurge:
          allowUserImmediateMediaPurge ?? this.allowUserImmediateMediaPurge,
      dpdpComplianceNote: dpdpComplianceNote ?? this.dpdpComplianceNote,
    );
  }

  factory ComplaintRetentionPolicyModel.fromBackendJson(
    Map<String, dynamic> json,
  ) {
    final closedDays =
        (json['closedEvidenceRetentionDays'] as num? ?? 90).toInt();
    final rejectedDays =
        (json['rejectedReportRetentionDays'] as num? ?? 30).toInt();
    final logDays = (json['technicalRateLimitLogDays'] as num? ?? 14).toInt();
    return ComplaintRetentionPolicyModel(
      closedCaseRetentionDays: closedDays,
      rejectedCaseRetentionDays: rejectedDays,
      autoPurgeRawMediaAfterDays: closedDays,
      scrubIpLogsAfterHours: logDays * 24,
      allowUserImmediateMediaPurge: true,
      dpdpComplianceNote:
          'DPDP Act 2023 Compliant • Closed evidence purged after ${closedDays}d • Rejected reports purged after ${rejectedDays}d • Technical rate-limit logs rotated every ${logDays}d.',
    );
  }
}
