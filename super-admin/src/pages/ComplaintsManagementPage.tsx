import { useCallback, useEffect, useMemo, useState } from "react";
import {
  AlertTriangle,
  CheckCircle2,
  ChevronLeft,
  ChevronRight,
  Eye,
  FileClock,
  GitMerge,
  Lock,
  MessageSquare,
  MessageSquareWarning,
  Plus,
  RefreshCw,
  Search,
  Send,
  Settings2,
  ShieldAlert,
  UserCheck,
} from "lucide-react";
import { Link } from "react-router-dom";
import { StatusPill } from "../components/StatusPill";
import { SakhiQuoteLoader } from "../components/SakhiQuoteLoader";
import { adminApi } from "../services/api/adminApi";
import { adminAuthService } from "../services/auth/adminAuthService";

interface SanitizedEvidenceFile {
  id: string;
  fileName: string;
  originalFileNameRedacted: string;
  contentType: string;
  byteSize: number;
  sha256Digest: string;
  exifGpsStripped: boolean;
  deviceMetadataStripped: boolean;
  visualBlurApplied: boolean;
  scrubbedFields: string[];
  uploadedAt: string;
  isPurged?: boolean;
}

interface ComplainantMessageItem {
  id: string;
  senderRole: string;
  senderLabel: string;
  message: string;
  attachedFiles?: SanitizedEvidenceFile[];
  createdAt: string;
}

interface InternalReviewerNoteItem {
  id: string;
  reviewerId: string;
  reviewerName: string;
  visibilityRole: string;
  noteText: string;
  createdAt: string;
}

interface ComplaintAuditEntry {
  id: string;
  auditCode: string;
  actorRole: string;
  actorLabel: string;
  action: string;
  summary: string;
  integrityHash?: string;
  timestamp: string;
}

interface ComplaintItem {
  id: string;
  referenceNumber: string;
  disguisedBackupSerial?: string;
  reportingMode: "ANONYMOUS" | "CONFIDENTIAL";
  confidentialAccountVaultStatus?: string;
  blindedRateLimitBucket: string;
  categorySlug: string;
  categoryTitle: string;
  customCategoryLabel?: string | null;
  urgency: string;
  description: string;
  piiGuardRedacted: boolean;
  approximateDateLabel: string;
  approximateTimeWindow: string;
  locationType: string;
  generalLocationLabel?: string | null;
  linkedTargetType?: string | null;
  linkedTargetHandle?: string | null;
  linkedPostId?: string | null;
  linkedBusinessId?: string | null;
  evidenceFiles: SanitizedEvidenceFile[];
  supportingLinks: Array<{ url: string; linkType: string; snapshotArchived: boolean }>;
  status: string;
  severity: string;
  priority: string;
  assignedReviewerId?: string | null;
  assignedReviewerName?: string | null;
  duplicateClusterId?: string | null;
  mergedIntoReference?: string | null;
  isFlaggedMaliciousAbuse: boolean;
  maliciousAbuseReason?: string | null;
  rejectionReasonCode?: string | null;
  publicResolutionSummary?: string | null;
  enforcementActions: string[];
  complainantMessages: ComplainantMessageItem[];
  internalNotes: InternalReviewerNoteItem[];
  auditHistory: ComplaintAuditEntry[];
  mediaPurgedAt?: string | null;
  createdAt: string;
  updatedAt: string;
}

interface ComplaintCategoryConfig {
  slug: string;
  name: string;
  description: string;
  defaultPriority: string;
  defaultSeverity: string;
  safetyGuidanceText: string;
  legalHelplineNote: string;
  isEnabled: boolean;
  displayOrder: number;
}

interface ComplaintsDashboardPayload {
  reviewer: {
    reviewerLabel: string;
    effectiveRole: string;
    ordinaryModeratorMaskingActive: boolean;
  };
  metrics: {
    totalComplaints: number;
    openComplaintsCount: number;
    urgentP1Count: number;
    anonymousPercentage: number;
    confidentialPercentage: number;
    duplicateClustersCount: number;
    flaggedMaliciousAbuseCount: number;
    medianTriageHours: number;
  };
  pagination: {
    page: number;
    pageSize: number;
    totalItems: number;
    totalPages: number;
  };
  complaints: ComplaintItem[];
  categories: ComplaintCategoryConfig[];
  retentionPolicy: {
    closedEvidenceRetentionDays: number;
    rejectedReportRetentionDays: number;
    technicalRateLimitLogDays: number;
    updatedBy?: string;
    updatedAt?: string;
  };
  authorisedReviewers: Array<{
    id: string;
    staffCode?: string;
    name: string;
    role?: string;
    clearance: string;
  }>;
}

const ALL_STATUSES = [
  "SUBMITTED",
  "UNDER_REVIEW",
  "ADDITIONAL_INFO_REQUIRED",
  "ESCALATED",
  "ACTION_TAKEN",
  "CLOSED",
  "REJECTED_WITH_REASON",
];

const VALID_NEXT_STATUSES: Record<string, string[]> = {
  SUBMITTED: [
    "UNDER_REVIEW",
    "ADDITIONAL_INFO_REQUIRED",
    "ESCALATED",
    "ACTION_TAKEN",
    "REJECTED_WITH_REASON",
  ],
  UNDER_REVIEW: [
    "ADDITIONAL_INFO_REQUIRED",
    "ESCALATED",
    "ACTION_TAKEN",
    "CLOSED",
    "REJECTED_WITH_REASON",
  ],
  ADDITIONAL_INFO_REQUIRED: [
    "UNDER_REVIEW",
    "ESCALATED",
    "ACTION_TAKEN",
    "CLOSED",
    "REJECTED_WITH_REASON",
  ],
  ESCALATED: [
    "UNDER_REVIEW",
    "ADDITIONAL_INFO_REQUIRED",
    "ACTION_TAKEN",
    "CLOSED",
    "REJECTED_WITH_REASON",
  ],
  ACTION_TAKEN: ["CLOSED", "ESCALATED", "UNDER_REVIEW"],
  CLOSED: ["ESCALATED", "UNDER_REVIEW"],
  REJECTED_WITH_REASON: ["ESCALATED", "UNDER_REVIEW"],
};

const STATUS_LABELS: Record<string, string> = {
  SUBMITTED: "Submitted",
  UNDER_REVIEW: "Under Review",
  ADDITIONAL_INFO_REQUIRED: "Additional Info Required",
  ESCALATED: "Escalated",
  ACTION_TAKEN: "Action Taken",
  CLOSED: "Closed",
  REJECTED_WITH_REASON: "Rejected with Reason",
};

const PRIORITY_LABELS: Record<string, string> = {
  P1_URGENT: "P1 Urgent",
  P2_HIGH: "P2 High",
  P3_STANDARD: "P3 Standard",
  P4_ROUTINE: "P4 Routine",
};

const SEVERITY_LABELS: Record<string, string> = {
  S1_CRITICAL: "S1 Critical",
  S2_HIGH: "S2 High",
  S3_MODERATE: "S3 Moderate",
  S4_LOW: "S4 Low",
};

function formatStatusLabel(status: string): string {
  return (
    STATUS_LABELS[status] ??
    status
      .replace(/_/g, " ")
      .toLowerCase()
      .replace(/\b\w/g, (c) => c.toUpperCase())
  );
}

function formatPriorityLabel(priority: string): string {
  return (
    PRIORITY_LABELS[priority] ??
    priority
      .replace(/_/g, " ")
      .toLowerCase()
      .replace(/\b\w/g, (c) => c.toUpperCase())
  );
}

function formatSeverityLabel(severity: string): string {
  return (
    SEVERITY_LABELS[severity] ??
    severity
      .replace(/_/g, " ")
      .toLowerCase()
      .replace(/\b\w/g, (c) => c.toUpperCase())
  );
}

function formatCleanText(raw?: string | null): string {
  if (!raw) return "";
  return raw.replace(/_/g, " ");
}

const COMPLAINTS_MSG_TIME_FMT = new Intl.DateTimeFormat("en-IN", {
  day: "2-digit",
  month: "short",
  hour: "2-digit",
  minute: "2-digit",
});

function formatMessageTime(iso: string): string {
  try {
    return COMPLAINTS_MSG_TIME_FMT.format(new Date(iso));
  } catch {
    return iso;
  }
}

export function ComplaintsManagementPage() {
  const adminProfile = adminAuthService.getProfile();
  const isSuperAdmin = adminProfile.role === "SUPER_ADMIN";

  const [data, setData] = useState<ComplaintsDashboardPayload | null>(null);
  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [notice, setNotice] = useState("");
  const [error, setError] = useState("");

  // Active sub-module tab
  const [activeTab, setActiveTab] = useState<
    "queue" | "vault" | "duplicates" | "malicious" | "config"
  >("queue");

  // Filters & Pagination
  const [statusFilter, setStatusFilter] = useState<string>("ALL");
  const [priorityFilter, setPriorityFilter] = useState<string>("ALL");
  const [modeFilter, setModeFilter] = useState<string>("ALL");
  const [categoryFilter, setCategoryFilter] = useState<string>("ALL");
  const [searchQuery, setSearchQuery] = useState<string>("");
  const [page, setPage] = useState<number>(1);
  const [selectedRef, setSelectedRef] = useState<string>("");

  // Case Action States
  const [selectedReviewerId, setSelectedReviewerId] = useState("SA-01");
  const [selectedSeverity, setSelectedSeverity] = useState("S2_HIGH");
  const [selectedPriority, setSelectedPriority] = useState("P1_URGENT");
  const [nextStatus, setNextStatus] = useState("UNDER_REVIEW");
  const [publicMessage, setPublicMessage] = useState("");
  const [directReplyText, setDirectReplyText] = useState("");
  const [rejectionCode, setRejectionCode] = useState("#OUTSIDE-SCOPE-COMMERCIAL");
  const [internalNoteText, setInternalNoteText] = useState("");
  const [noteVisibilityRole, setNoteVisibilityRole] = useState("SENIOR_REVIEWER");

  // Controlled Evidence Vault State
  const [revealedEvidenceIds, setRevealedEvidenceIds] = useState<Record<string, string>>({});
  const [exportReason, setExportReason] = useState(
    "Escalation Review & Repeat-Offender Ban Documentation",
  );

  // Duplicate Merge Form State
  const [mergePrimaryRef, setMergePrimaryRef] = useState("");
  const [mergeDuplicateRefsInput, setMergeDuplicateRefsInput] = useState("");
  const [mergeClusterId, setMergeClusterId] = useState("");

  // Malicious Report Guard State
  const [maliciousTargetRef, setMaliciousTargetRef] = useState("");
  const [maliciousCooldownHours, setMaliciousCooldownHours] = useState(72);
  const [maliciousReason, setMaliciousReason] = useState(
    "Coordinated burst flood with zero corroborating evidence",
  );

  // Category & Retention Config State
  const [newCatName, setNewCatName] = useState("");
  const [newCatDesc, setNewCatDesc] = useState("");
  const [newCatGuidance, setNewCatGuidance] = useState("");
  const [closedRetentionDays, setClosedRetentionDays] = useState(90);
  const [rejectedRetentionDays, setRejectedRetentionDays] = useState(30);
  const [logRetentionDays, setLogRetentionDays] = useState(14);

  const syncComplaintEditor = useCallback(
    (
      complaint: ComplaintItem,
      reviewersList?: ComplaintsDashboardPayload["authorisedReviewers"],
    ) => {
      setSelectedSeverity(complaint.severity || "S2_HIGH");
      setSelectedPriority(complaint.priority || "P1_URGENT");
      if (complaint.assignedReviewerId) {
        setSelectedReviewerId(complaint.assignedReviewerId);
      } else if (reviewersList && reviewersList.length > 0) {
        setSelectedReviewerId(reviewersList[0].id);
      }
      const allowed = VALID_NEXT_STATUSES[complaint.status] ?? ALL_STATUSES;
      setNextStatus((current) =>
        allowed.includes(current) ? current : (allowed[0] ?? "UNDER_REVIEW"),
      );
    },
    [],
  );

  const loadDashboard = useCallback(async () => {
    setLoading(true);
    setError("");
    try {
      const qs = new URLSearchParams({
        status: statusFilter,
        priority: priorityFilter,
        reportingMode: modeFilter,
        categorySlug: categoryFilter,
        search: searchQuery.trim(),
        page: String(page),
        pageSize: "20",
      });
      const res = await adminApi<ComplaintsDashboardPayload>(
        `/admin-review/complaints?${qs.toString()}`,
      );
      setData(res);
      if (res.complaints.length > 0) {
        const currentExists = res.complaints.some(
          (c) => c.referenceNumber === selectedRef,
        );
        const activeCase = currentExists
          ? res.complaints.find((c) => c.referenceNumber === selectedRef)!
          : res.complaints[0];
        if (!currentExists) {
          setSelectedRef(activeCase.referenceNumber);
        }
        syncComplaintEditor(activeCase, res.authorisedReviewers);
        setMergePrimaryRef((prev) => prev || activeCase.referenceNumber);
        setMaliciousTargetRef((prev) => prev || activeCase.referenceNumber);
      } else {
        setSelectedRef("");
      }
      setClosedRetentionDays(res.retentionPolicy.closedEvidenceRetentionDays);
      setRejectedRetentionDays(res.retentionPolicy.rejectedReportRetentionDays);
      setLogRetentionDays(res.retentionPolicy.technicalRateLimitLogDays);
    } catch (err) {
      setError(
        err instanceof Error
          ? err.message
          : "Could not load complaints from backend API. Verify the backend server and admin session token.",
      );
    } finally {
      setLoading(false);
    }
  }, [
    statusFilter,
    priorityFilter,
    modeFilter,
    categoryFilter,
    searchQuery,
    page,
    selectedRef,
    syncComplaintEditor,
  ]);

  useEffect(() => {
    void Promise.resolve().then(loadDashboard);
  }, [loadDashboard]);

  const selectedComplaint = useMemo(() => {
    if (!data || data.complaints.length === 0) return null;
    return (
      data.complaints.find((c) => c.referenceNumber === selectedRef) ??
      data.complaints[0]
    );
  }, [data, selectedRef]);

  async function handleAssignAndClassify() {
    if (!selectedComplaint || !data) return;
    const rev =
      data.authorisedReviewers.find((r) => r.id === selectedReviewerId) ??
      data.authorisedReviewers[0];
    if (!rev) return;
    setSubmitting(true);
    setError("");
    setNotice("");
    try {
      await adminApi(
        `/admin-review/complaints/${encodeURIComponent(selectedComplaint.referenceNumber)}/assign`,
        {
          method: "PATCH",
          body: {
            assignedReviewerId: rev.id,
            assignedReviewerName: rev.name,
            severity: selectedSeverity,
            priority: selectedPriority,
          },
        },
      );
      setNotice(
        `Assigned ${selectedComplaint.referenceNumber} to ${rev.name} (${formatSeverityLabel(selectedSeverity)} • ${formatPriorityLabel(selectedPriority)}).`,
      );
      await loadDashboard();
    } catch (err) {
      setError(
        err instanceof Error
          ? err.message
          : "Failed to assign reviewer and classify complaint.",
      );
    } finally {
      setSubmitting(false);
    }
  }

  async function handleSendDirectMessageToComplainant() {
    if (!selectedComplaint) return;
    const clean = directReplyText.trim();
    if (clean.length < 2) {
      setError("Enter a message of at least 2 characters for the complainant.");
      return;
    }
    setSubmitting(true);
    setError("");
    setNotice("");
    try {
      await adminApi(
        `/admin-review/complaints/${encodeURIComponent(selectedComplaint.referenceNumber)}/messages`,
        {
          method: "POST",
          body: { message: clean },
        },
      );
      setDirectReplyText("");
      setNotice(
        `Sent encrypted response to complainant on ${selectedComplaint.referenceNumber}. They can view it immediately in Track My Report.`,
      );
      await loadDashboard();
    } catch (err) {
      setError(
        err instanceof Error
          ? err.message
          : "Failed to send message to complainant.",
      );
    } finally {
      setSubmitting(false);
    }
  }

  async function handleUpdateStatus() {
    if (!selectedComplaint) return;
    if (
      nextStatus === "ADDITIONAL_INFO_REQUIRED" &&
      publicMessage.trim().length < 5
    ) {
      setError(
        "Please enter a follow-up question for the complainant before setting status to Additional Info Required.",
      );
      return;
    }
    if (
      nextStatus === "REJECTED_WITH_REASON" &&
      !rejectionCode.trim() &&
      !publicMessage.trim()
    ) {
      setError(
        "Rejected complaints require a rejection reason code or explanation.",
      );
      return;
    }

    setSubmitting(true);
    setError("");
    setNotice("");
    try {
      await adminApi(
        `/admin-review/complaints/${encodeURIComponent(selectedComplaint.referenceNumber)}/status`,
        {
          method: "POST",
          body: {
            status: nextStatus,
            publicMessageToComplainant: publicMessage.trim() || undefined,
            rejectionReasonCode:
              nextStatus === "REJECTED_WITH_REASON"
                ? rejectionCode.trim()
                : undefined,
            enforcementActions:
              nextStatus === "ACTION_TAKEN"
                ? [
                    "SUSPEND_TARGET_ACCOUNT",
                    "REMOVE_OFFENDING_CONTENT",
                    "REPEAT_OFFENDER_HASH_LOGGED",
                  ]
                : undefined,
          },
        },
      );
      setPublicMessage("");
      setNotice(
        `Updated ${selectedComplaint.referenceNumber} status to ${formatStatusLabel(nextStatus)} and logged SHA-256 audit entry.`,
      );
      await loadDashboard();
    } catch (err) {
      setError(
        err instanceof Error ? err.message : "Failed to update complaint status.",
      );
    } finally {
      setSubmitting(false);
    }
  }

  async function handleAddInternalNote() {
    if (!selectedComplaint) return;
    if (internalNoteText.trim().length < 3) {
      setError("Internal note must be at least 3 characters.");
      return;
    }
    setSubmitting(true);
    setError("");
    setNotice("");
    try {
      await adminApi(
        `/admin-review/complaints/${encodeURIComponent(selectedComplaint.referenceNumber)}/internal-notes`,
        {
          method: "POST",
          body: {
            noteText: internalNoteText.trim(),
            visibilityRole: noteVisibilityRole,
          },
        },
      );
      setInternalNoteText("");
      setNotice(
        `Private internal reviewer note saved to ${selectedComplaint.referenceNumber} (hidden from complainant & public).`,
      );
      await loadDashboard();
    } catch (err) {
      setError(
        err instanceof Error ? err.message : "Failed to save internal note.",
      );
    } finally {
      setSubmitting(false);
    }
  }

  async function handleControlledEvidenceAccess(
    evidenceId: string,
    action: "REVEAL_VIEWER" | "WATERMARKED_DOWNLOAD",
  ) {
    if (!selectedComplaint) return;
    if (exportReason.trim().length < 10) {
      setError(
        "Please provide an audit justification of at least 10 characters before revealing or exporting evidence.",
      );
      return;
    }
    setSubmitting(true);
    setError("");
    setNotice("");
    try {
      const res = await adminApi<{ watermarkOverlayText: string }>(
        `/admin-review/complaints/${encodeURIComponent(selectedComplaint.referenceNumber)}/evidence-access`,
        {
          method: "POST",
          body: {
            evidenceId,
            action,
            justificationReason: exportReason.trim(),
          },
        },
      );
      setRevealedEvidenceIds((prev) => ({
        ...prev,
        [evidenceId]: res.watermarkOverlayText,
      }));
      setNotice(
        `Controlled Evidence ${action === "REVEAL_VIEWER" ? "Reveal" : "Watermarked Export"} authorized & logged in immutable audit trail.`,
      );
      await loadDashboard();
    } catch (err) {
      setError(
        err instanceof Error
          ? err.message
          : "Evidence access denied or failed.",
      );
    } finally {
      setSubmitting(false);
    }
  }

  async function handleMergeCluster() {
    const primary = mergePrimaryRef.trim();
    const dupList = mergeDuplicateRefsInput
      .split(",")
      .map((s) => s.trim())
      .filter(Boolean);
    if (!primary || dupList.length === 0) {
      setError(
        "Specify both a Primary Reference # and at least one comma-separated Duplicate Reference # to merge.",
      );
      return;
    }
    setSubmitting(true);
    setError("");
    setNotice("");
    try {
      const res = await adminApi<{
        clusterId: string;
        primaryReferenceNumber: string;
        mergedReferences: string[];
      }>("/admin-review/complaints/merge-duplicates", {
        method: "POST",
        body: {
          primaryReferenceNumber: primary,
          duplicateReferenceNumbers: dupList,
          clusterId: mergeClusterId.trim() || undefined,
        },
      });
      setNotice(
        `Merged ${res.mergedReferences.join(", ")} into primary investigation ${res.primaryReferenceNumber} under Cluster #${res.clusterId}.`,
      );
      setMergeDuplicateRefsInput("");
      await loadDashboard();
    } catch (err) {
      setError(
        err instanceof Error
          ? err.message
          : "Failed to merge duplicate complaints.",
      );
    } finally {
      setSubmitting(false);
    }
  }

  async function handleMaliciousSafeguard() {
    const ref = maliciousTargetRef.trim() || selectedComplaint?.referenceNumber;
    if (!ref) {
      setError("Select or enter a complaint reference number to apply safeguard.");
      return;
    }
    if (maliciousReason.trim().length < 5) {
      setError("Provide a reason of at least 5 characters.");
      return;
    }
    setSubmitting(true);
    setError("");
    setNotice("");
    try {
      const res = await adminApi<{ throttledBucket: string; cooldownUntil: string }>(
        `/admin-review/complaints/${encodeURIComponent(ref)}/malicious-guard`,
        {
          method: "POST",
          body: {
            action: "THROTTLE_BLINDED_BUCKET",
            cooldownHours: maliciousCooldownHours,
            reason: maliciousReason.trim(),
          },
        },
      );
      setNotice(
        `Applied ${maliciousCooldownHours}h cooldown to blinded bucket (${res.throttledBucket}) for ${ref} without unmasking user identity.`,
      );
      await loadDashboard();
    } catch (err) {
      setError(
        err instanceof Error
          ? err.message
          : "Failed to apply malicious-report safeguard.",
      );
    } finally {
      setSubmitting(false);
    }
  }

  async function handleSaveRetentionPolicy() {
    setSubmitting(true);
    setError("");
    setNotice("");
    try {
      await adminApi("/admin-review/complaints/retention-policy", {
        method: "PUT",
        body: {
          closedEvidenceRetentionDays: closedRetentionDays,
          rejectedReportRetentionDays: rejectedRetentionDays,
          technicalRateLimitLogDays: logRetentionDays,
        },
      });
      setNotice(
        `Updated DPDP Retention Policy: Closed media (${closedRetentionDays}d), Rejected reports (${rejectedRetentionDays}d), Rate-limit logs (${logRetentionDays}d).`,
      );
      await loadDashboard();
    } catch (err) {
      setError(
        err instanceof Error
          ? err.message
          : "Failed to update retention policy.",
      );
    } finally {
      setSubmitting(false);
    }
  }

  async function handleToggleCategory(cat: ComplaintCategoryConfig) {
    setSubmitting(true);
    setError("");
    setNotice("");
    try {
      await adminApi("/admin-review/complaints/categories", {
        method: "PUT",
        body: {
          slug: cat.slug,
          name: cat.name,
          description: cat.description,
          defaultPriority: cat.defaultPriority,
          defaultSeverity: cat.defaultSeverity,
          safetyGuidanceText: cat.safetyGuidanceText,
          legalHelplineNote: cat.legalHelplineNote,
          isEnabled: !cat.isEnabled,
          displayOrder: cat.displayOrder,
        },
      });
      setNotice(
        `Category "${cat.name}" is now ${!cat.isEnabled ? "Enabled" : "Disabled"} for mobile complaint submissions.`,
      );
      await loadDashboard();
    } catch (err) {
      setError(
        err instanceof Error
          ? err.message
          : "Failed to update category state.",
      );
    } finally {
      setSubmitting(false);
    }
  }

  async function handleAddCategory() {
    if (!newCatName.trim()) {
      setError("Category name is required.");
      return;
    }
    const slug = newCatName
      .trim()
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, "_")
      .replace(/^_+|_+$/g, "");
    setSubmitting(true);
    setError("");
    setNotice("");
    try {
      await adminApi("/admin-review/complaints/categories", {
        method: "PUT",
        body: {
          slug,
          name: newCatName.trim(),
          description:
            newCatDesc.trim() || "Custom configurable safety category",
          safetyGuidanceText:
            newCatGuidance.trim() ||
            "Preserve screenshots safely and use Quick Exit if needed.",
          defaultPriority: "P2_HIGH",
          defaultSeverity: "S2_HIGH",
          isEnabled: true,
        },
      });
      setNewCatName("");
      setNewCatDesc("");
      setNewCatGuidance("");
      setNotice(
        `Saved configurable category "${newCatName.trim()}" — synced live to mobile complaint intake.`,
      );
      await loadDashboard();
    } catch (err) {
      setError(
        err instanceof Error ? err.message : "Failed to save category.",
      );
    } finally {
      setSubmitting(false);
    }
  }

  if (loading && !data) {
    return (
      <SakhiQuoteLoader statusLabel="Loading Discreet & Anonymous Complaint Management Console..." />
    );
  }

  const metrics = data?.metrics ?? {
    totalComplaints: 0,
    openComplaintsCount: 0,
    urgentP1Count: 0,
    anonymousPercentage: 0,
    confidentialPercentage: 0,
    duplicateClustersCount: 0,
    flaggedMaliciousAbuseCount: 0,
    medianTriageHours: 0,
  };

  const complaints = data?.complaints ?? [];
  const categories = data?.categories ?? [];
  const pagination = data?.pagination ?? {
    page: 1,
    pageSize: 20,
    totalItems: 0,
    totalPages: 1,
  };

  const visibleTabs = [
    {
      id: "queue",
      label: "1. Triage Queue & Case Workflow",
      icon: MessageSquareWarning,
    },
    { id: "vault", label: "2. Controlled Evidence Vault", icon: Lock },
    {
      id: "duplicates",
      label: "3. Duplicate & Cluster Merge",
      icon: GitMerge,
    },
    {
      id: "malicious",
      label: "4. Malicious-Report & Abuse Guard",
      icon: ShieldAlert,
    },
    ...(isSuperAdmin
      ? [
          {
            id: "config",
            label: "5. Categories & Retention Policy",
            icon: Settings2,
          },
        ]
      : []),
  ];

  return (
    <div
      className="page-stack"
      style={{ display: "flex", flexDirection: "column", gap: "24px" }}
    >
      {/* Top Header */}
      <section className="hero-card">
        <div className="hero-copy">
          <div className="eyebrow-row">
            <StatusPill tone="rose">
              DISCREET &amp; ANONYMOUS COMPLAINT DESK
            </StatusPill>
            <StatusPill tone="green">
              Real Database Persistence &amp; RBAC Active
            </StatusPill>
          </div>
          <h1>Discreet &amp; Anonymous Complaint Management Console</h1>
          <p>
            Role-restricted triage queue for Anonymous (<code>#SKH-ANON</code>)
            and Confidential (<code>#SKH-CONF</code>) safety complaints.
            Ordinary content moderators are strictly blocked from this queue.
          </p>
        </div>
        <div
          className="hero-actions"
          style={{
            display: "flex",
            gap: "12px",
            alignItems: "center",
            flexWrap: "wrap",
          }}
        >
          <div
            style={{
              padding: "8px 14px",
              borderRadius: "10px",
              background: "#f8f1fb",
              border: "1px solid #dcc8e6",
              fontSize: "12.5px",
              fontWeight: 700,
              color: "#52345f",
            }}
          >
            Signed in as: {adminProfile.fullName} ({adminProfile.staffCode} •{" "}
            {adminProfile.badgeLabel})
          </div>
          <button
            className="secondary-button"
            type="button"
            disabled={loading || submitting}
            onClick={() => void loadDashboard()}
          >
            <RefreshCw size={15} /> {loading ? "Syncing..." : "Refresh Queue"}
          </button>
        </div>
      </section>

      {notice && (
        <div
          className="demo-banner"
          style={{
            background: "#e8f5ed",
            borderColor: "#b8e2c8",
            color: "#1f6e4e",
          }}
        >
          <CheckCircle2 size={18} />
          <div>
            <strong>Server Action Confirmed &amp; Audit-Logged</strong>
            <span>{notice}</span>
          </div>
        </div>
      )}
      {error && (
        <div
          className="demo-banner"
          style={{
            background: "#fcebed",
            borderColor: "#f5c2c7",
            color: "#a63b4a",
          }}
        >
          <AlertTriangle size={18} />
          <div>
            <strong>Backend Validation / API Error</strong>
            <span>{error}</span>
          </div>
        </div>
      )}

      {/* Real Database KPI Metrics Row with Generous Spacing */}
      <section
        className="stats-grid"
        style={{
          display: "grid",
          gridTemplateColumns: "repeat(auto-fit, minmax(220px, 1fr))",
          gap: "18px",
          marginBottom: "4px",
        }}
      >
        <article
          className="stat-card"
          style={{
            background: "#fff",
            padding: "20px",
            borderRadius: "16px",
            border: "1px solid #eee7ee",
            boxShadow: "0 4px 14px rgba(82, 52, 95, 0.04)",
          }}
        >
          <span style={{ fontSize: "12px", color: "#877b8b", fontWeight: 700 }}>
            OPEN COMPLAINTS QUEUE
          </span>
          <div
            style={{
              display: "flex",
              alignItems: "center",
              justifyContent: "space-between",
              gap: "10px",
              marginTop: "10px",
            }}
          >
            <strong
              style={{
                fontSize: "30px",
                fontWeight: 800,
                color: "#31263a",
              }}
            >
              {metrics.openComplaintsCount}
            </strong>
            <StatusPill
              tone={metrics.urgentP1Count > 0 ? "urgent" : "green"}
            >
              {metrics.urgentP1Count} Open Urgent P1
            </StatusPill>
          </div>
        </article>

        <article
          className="stat-card"
          style={{
            background: "#fff",
            padding: "20px",
            borderRadius: "16px",
            border: "1px solid #eee7ee",
            boxShadow: "0 4px 14px rgba(82, 52, 95, 0.04)",
          }}
        >
          <span style={{ fontSize: "12px", color: "#877b8b", fontWeight: 700 }}>
            TOTAL / ANONYMOUS VS CONFIDENTIAL
          </span>
          <div
            style={{
              display: "flex",
              alignItems: "baseline",
              gap: "8px",
              marginTop: "10px",
              flexWrap: "wrap",
            }}
          >
            <strong
              style={{
                fontSize: "30px",
                fontWeight: 800,
                color: "#52345f",
              }}
            >
              {metrics.totalComplaints}
            </strong>
            <small style={{ fontSize: "13px", color: "#877b8b", fontWeight: 600 }}>
              ({metrics.anonymousPercentage}% Anonymous /{" "}
              {metrics.confidentialPercentage}% Confidential)
            </small>
          </div>
        </article>

        <article
          className="stat-card"
          style={{
            background: "#fff",
            padding: "20px",
            borderRadius: "16px",
            border: "1px solid #eee7ee",
            boxShadow: "0 4px 14px rgba(82, 52, 95, 0.04)",
          }}
        >
          <span style={{ fontSize: "12px", color: "#877b8b", fontWeight: 700 }}>
            DUPLICATE CLUSTERS &amp; SAFEGUARDS
          </span>
          <div
            style={{
              display: "flex",
              alignItems: "center",
              justifyContent: "space-between",
              gap: "10px",
              marginTop: "10px",
            }}
          >
            <strong
              style={{
                fontSize: "30px",
                fontWeight: 800,
                color: "#9a6918",
              }}
            >
              {metrics.duplicateClustersCount}
            </strong>
            <StatusPill tone="amber">
              {metrics.flaggedMaliciousAbuseCount} Abuse Flagged
            </StatusPill>
          </div>
        </article>

        <article
          className="stat-card"
          style={{
            background: "#fff",
            padding: "20px",
            borderRadius: "16px",
            border: "1px solid #eee7ee",
            boxShadow: "0 4px 14px rgba(82, 52, 95, 0.04)",
          }}
        >
          <span style={{ fontSize: "12px", color: "#877b8b", fontWeight: 700 }}>
            MEDIAN TRIAGE HOURS
          </span>
          <div
            style={{
              display: "flex",
              alignItems: "center",
              justifyContent: "space-between",
              gap: "10px",
              marginTop: "10px",
            }}
          >
            <strong
              style={{
                fontSize: "30px",
                fontWeight: 800,
                color: "#39785c",
              }}
            >
              {metrics.medianTriageHours} hrs
            </strong>
            <StatusPill tone="green">Live Metric</StatusPill>
          </div>
        </article>
      </section>

      {/* Sub-Module Navigation Tabs with Generous Bottom Padding */}
      <div
        style={{
          display: "flex",
          gap: "12px",
          flexWrap: "wrap",
          borderBottom: "1px solid #eee7ee",
          paddingBottom: "16px",
        }}
      >
        {visibleTabs.map((tab) => {
          const Icon = tab.icon;
          const active = activeTab === tab.id;
          return (
            <button className="button button--secondary"
              key={tab.id}
              type="button"
              onClick={() => setActiveTab(tab.id as typeof activeTab)}
              style={{
                display: "inline-flex",
                alignItems: "center",
                gap: "8px",
                padding: "11px 18px",
                borderRadius: "999px",
                border: active ? "2px solid #631d76" : "1px solid #e5d8e8",
                background: active ? "#631d76" : "#fff",
                color: active ? "#fff" : "#52345f",
                fontWeight: 700,
                fontSize: "13px",
                cursor: "pointer",
              }}
            >
              <Icon size={15} />
              {tab.label}
            </button>
          );
        })}
      </div>

      {/* TAB 1: TRIAGE QUEUE & CASE WORKFLOW */}
      {activeTab === "queue" && (
        <div
          style={{
            display: "grid",
            gridTemplateColumns: selectedComplaint ? "1.1fr 1.05fr" : "1fr",
            gap: "24px",
            alignItems: "start",
          }}
        >
          {/* Left Column: Filterable & Paginated Queue */}
          <div
            style={{
              background: "#fff",
              borderRadius: "18px",
              border: "1px solid #eee7ee",
              padding: "22px",
            }}
          >
            <div
              style={{
                display: "flex",
                gap: "10px",
                flexWrap: "wrap",
                marginBottom: "18px",
              }}
            >
              <div
                style={{
                  display: "flex",
                  alignItems: "center",
                  gap: "8px",
                  flex: 1,
                  minWidth: "200px",
                  border: "1px solid #e2d4e6",
                  borderRadius: "10px",
                  padding: "8px 12px",
                }}
              >
                <Search size={16} />
                <input
                  value={searchQuery}
                  onChange={(e) => {
                    setSearchQuery(e.target.value);
                    setPage(1);
                  }}
                  placeholder="Search #SKH ref, category, @target..."
                  style={{ border: 0, outline: 0, width: "100%", fontSize: "13px" }}
                />
              </div>
              <select
                value={statusFilter}
                onChange={(e) => {
                  setStatusFilter(e.target.value);
                  setPage(1);
                }}
                style={{
                  padding: "8px 12px",
                  borderRadius: "10px",
                  border: "1px solid #e2d4e6",
                  fontSize: "13px",
                  fontWeight: 600,
                }}
              >
                <option value="ALL">All 7 Statuses</option>
                {ALL_STATUSES.map((st) => (
                  <option key={st} value={st}>
                    {formatStatusLabel(st)}
                  </option>
                ))}
              </select>
              <select
                value={priorityFilter}
                onChange={(e) => {
                  setPriorityFilter(e.target.value);
                  setPage(1);
                }}
                style={{
                  padding: "8px 12px",
                  borderRadius: "10px",
                  border: "1px solid #e2d4e6",
                  fontSize: "13px",
                  fontWeight: 600,
                }}
              >
                <option value="ALL">All Priorities</option>
                <option value="P1_URGENT">P1 Urgent</option>
                <option value="P2_HIGH">P2 High</option>
                <option value="P3_STANDARD">P3 Standard</option>
                <option value="P4_ROUTINE">P4 Routine</option>
              </select>
              <select
                value={modeFilter}
                onChange={(e) => {
                  setModeFilter(e.target.value);
                  setPage(1);
                }}
                style={{
                  padding: "8px 12px",
                  borderRadius: "10px",
                  border: "1px solid #e2d4e6",
                  fontSize: "13px",
                  fontWeight: 600,
                }}
              >
                <option value="ALL">All Modes</option>
                <option value="ANONYMOUS">Anonymous Only</option>
                <option value="CONFIDENTIAL">Confidential Only</option>
              </select>
              <select
                value={categoryFilter}
                onChange={(e) => {
                  setCategoryFilter(e.target.value);
                  setPage(1);
                }}
                style={{
                  padding: "8px 12px",
                  borderRadius: "10px",
                  border: "1px solid #e2d4e6",
                  fontSize: "13px",
                  fontWeight: 600,
                }}
              >
                <option value="ALL">All Categories</option>
                {categories.map((cat) => (
                  <option key={cat.slug} value={cat.slug}>
                    {cat.name}
                  </option>
                ))}
              </select>
            </div>

            {complaints.length === 0 ? (
              <div
                style={{
                  padding: "36px 20px",
                  textAlign: "center",
                  background: "#fdf9fc",
                  borderRadius: "14px",
                  border: "1px dashed #dcc8e6",
                }}
              >
                <strong style={{ display: "block", fontSize: "15px", color: "#52345f" }}>
                  No Complaints Found in Database
                </strong>
                <p style={{ margin: "6px 0 0 0", fontSize: "13px", color: "#6e6275" }}>
                  No fabricated records are displayed. Submit a complaint from the Sakhi mobile app or adjust your filters above, then click Refresh Queue.
                </p>
              </div>
            ) : (
              <div style={{ display: "flex", flexDirection: "column", gap: "14px" }}>
                {complaints.map((item) => {
                  const isSelected =
                    item.referenceNumber === selectedComplaint?.referenceNumber;
                  const msgCount = item.complainantMessages?.length ?? 0;
                  return (
                    <div
                      key={item.id}
                      onClick={() => {
                        setSelectedRef(item.referenceNumber);
                        syncComplaintEditor(item, data?.authorisedReviewers);
                      }}
                      style={{
                        padding: "18px",
                        borderRadius: "16px",
                        border: isSelected
                          ? "2px solid #631d76"
                          : "1px solid #eee7ee",
                        background: isSelected ? "#fdf7fb" : "#fff",
                        cursor: "pointer",
                      }}
                    >
                      <div
                        style={{
                          display: "flex",
                          justifyContent: "space-between",
                          alignItems: "center",
                          gap: "8px",
                          flexWrap: "wrap",
                          marginBottom: "10px",
                        }}
                      >
                        <div
                          style={{
                            display: "flex",
                            alignItems: "center",
                            gap: "8px",
                            flexWrap: "wrap",
                          }}
                        >
                          <strong
                            style={{
                              fontFamily: "monospace",
                              fontSize: "14.5px",
                              color: "#31263a",
                            }}
                          >
                            {item.referenceNumber}
                          </strong>
                          <StatusPill
                            tone={
                              item.reportingMode === "ANONYMOUS"
                                ? "neutral"
                                : "rose"
                            }
                          >
                            {item.reportingMode === "ANONYMOUS"
                              ? "Anonymous"
                              : "Confidential"}
                          </StatusPill>
                          <StatusPill
                            tone={
                              item.priority === "P1_URGENT" ? "urgent" : "amber"
                            }
                          >
                            {formatPriorityLabel(item.priority)} •{" "}
                            {formatSeverityLabel(item.severity)}
                          </StatusPill>
                          {msgCount > 0 && (
                            <StatusPill tone="green">
                              {msgCount} Message{msgCount === 1 ? "" : "s"}
                            </StatusPill>
                          )}
                        </div>
                        <StatusPill
                          tone={
                            item.status === "ACTION_TAKEN"
                              ? "green"
                              : item.status === "REJECTED_WITH_REASON"
                                ? "urgent"
                                : "rose"
                          }
                        >
                          {formatStatusLabel(item.status)}
                        </StatusPill>
                      </div>
                      <div
                        style={{
                          fontWeight: 700,
                          fontSize: "14.5px",
                          color: "#31263a",
                          marginBottom: "6px",
                        }}
                      >
                        {item.categoryTitle}{" "}
                        {item.linkedTargetHandle
                          ? `• Target: ${item.linkedTargetHandle}`
                          : ""}
                      </div>
                      <p
                        style={{
                          margin: "0 0 10px 0",
                          fontSize: "13px",
                          color: "#6e6275",
                          lineHeight: 1.5,
                        }}
                      >
                        {item.description}
                      </p>
                      <div
                        style={{
                          display: "flex",
                          justifyContent: "space-between",
                          flexWrap: "wrap",
                          gap: "8px",
                          fontSize: "12px",
                          color: "#877b8b",
                        }}
                      >
                        <span>
                          Identity Vault:{" "}
                          <strong>
                            {formatCleanText(
                              item.confidentialAccountVaultStatus ?? "Protected",
                            )}
                          </strong>
                        </span>
                        <span>
                          Assigned:{" "}
                          <strong>
                            {item.assignedReviewerName ?? "Unassigned"}
                          </strong>{" "}
                          • Evidence:{" "}
                          <strong>
                            {item.evidenceFiles.length} Scrubbed File(s)
                          </strong>
                        </span>
                      </div>
                    </div>
                  );
                })}
              </div>
            )}

            {/* Pagination Footer */}
            <div
              style={{
                display: "flex",
                justifyContent: "space-between",
                alignItems: "center",
                marginTop: "18px",
                paddingTop: "14px",
                borderTop: "1px solid #f0e8f3",
                fontSize: "12.5px",
                color: "#6e6275",
              }}
            >
              <span>
                Page <strong>{pagination.page}</strong> of{" "}
                <strong>{pagination.totalPages}</strong> ({pagination.totalItems}{" "}
                matching complaint(s))
              </span>
              <div style={{ display: "flex", gap: "8px" }}>
                <button
                  type="button"
                  className="secondary-button"
                  disabled={pagination.page <= 1 || loading}
                  onClick={() => setPage((p) => Math.max(1, p - 1))}
                >
                  <ChevronLeft size={14} /> Prev
                </button>
                <button
                  type="button"
                  className="secondary-button"
                  disabled={pagination.page >= pagination.totalPages || loading}
                  onClick={() => setPage((p) => p + 1)}
                >
                  Next <ChevronRight size={14} />
                </button>
              </div>
            </div>
          </div>

          {/* Right Column: Selected Case Inspector */}
          {selectedComplaint && (
            <div style={{ display: "flex", flexDirection: "column", gap: "18px" }}>
              {/* Card 1: Assignment & Severity Classification (Real DB Reviewers Only!) */}
              <div
                style={{
                  background: "#fff",
                  borderRadius: "18px",
                  border: "1px solid #eee7ee",
                  padding: "22px",
                }}
              >
                <div
                  style={{
                    display: "flex",
                    justifyContent: "space-between",
                    alignItems: "center",
                    flexWrap: "wrap",
                    gap: "8px",
                    marginBottom: "14px",
                  }}
                >
                  <h3 style={{ margin: 0, fontSize: "16.5px" }}>
                    <UserCheck
                      size={16}
                      style={{ verticalAlign: "middle", marginRight: "6px" }}
                    />
                    Assign Reviewer &amp; Classify (
                    {selectedComplaint.referenceNumber})
                  </h3>
                  {isSuperAdmin ? (
                    <Link
                      to="/admin-users"
                      style={{
                        fontSize: "12px",
                        fontWeight: 700,
                        color: "#631d76",
                        textDecoration: "underline",
                      }}
                    >
                      + Add / Manage Reviewers
                    </Link>
                  ) : (
                    <StatusPill tone="green">Authorised Officer</StatusPill>
                  )}
                </div>
                <div
                  style={{
                    display: "grid",
                    gridTemplateColumns: "1fr 1fr",
                    gap: "12px",
                    marginBottom: "14px",
                  }}
                >
                  <label style={{ fontSize: "12.5px", fontWeight: 700 }}>
                    Authorised Reviewer (Real DB Accounts)
                    <select
                      value={selectedReviewerId}
                      onChange={(e) => setSelectedReviewerId(e.target.value)}
                      style={{
                        width: "100%",
                        marginTop: "6px",
                        padding: "9px 10px",
                        borderRadius: "10px",
                        border: "1px solid #dcd0e0",
                        fontWeight: 600,
                      }}
                    >
                      {(data?.authorisedReviewers ?? []).map((r) => (
                        <option key={r.id} value={r.id}>
                          {r.name}
                        </option>
                      ))}
                    </select>
                  </label>
                  <label style={{ fontSize: "12.5px", fontWeight: 700 }}>
                    Severity &amp; Priority
                    <div style={{ display: "flex", gap: "8px", marginTop: "6px" }}>
                      <select
                        value={selectedSeverity}
                        onChange={(e) => setSelectedSeverity(e.target.value)}
                        style={{
                          flex: 1,
                          padding: "9px 10px",
                          borderRadius: "10px",
                          border: "1px solid #dcd0e0",
                          fontWeight: 600,
                        }}
                      >
                        <option value="S1_CRITICAL">S1 Critical</option>
                        <option value="S2_HIGH">S2 High</option>
                        <option value="S3_MODERATE">S3 Moderate</option>
                        <option value="S4_LOW">S4 Low</option>
                      </select>
                      <select
                        value={selectedPriority}
                        onChange={(e) => setSelectedPriority(e.target.value)}
                        style={{
                          flex: 1,
                          padding: "9px 10px",
                          borderRadius: "10px",
                          border: "1px solid #dcd0e0",
                          fontWeight: 600,
                        }}
                      >
                        <option value="P1_URGENT">P1 Urgent (&lt;4h)</option>
                        <option value="P2_HIGH">P2 High (&lt;12h)</option>
                        <option value="P3_STANDARD">P3 Standard (&lt;24h)</option>
                        <option value="P4_ROUTINE">P4 Routine (&lt;72h)</option>
                      </select>
                    </div>
                  </label>
                </div>
                <button className="button button--secondary"
                  type="button"
                  disabled={submitting}
                  onClick={() => void handleAssignAndClassify()}
                  style={{
                    width: "100%",
                    padding: "11px",
                    borderRadius: "999px",
                    border: 0,
                    background: "#631d76",
                    color: "#fff",
                    fontWeight: 700,
                    cursor: "pointer",
                  }}
                >
                  Save Assignment &amp; Classification
                </button>
              </div>

              {/* Card 2: Complainant Two-Way Messages & Appeal Requests (FIXED FLAW #1!) */}
              <div
                style={{
                  background: "#fff",
                  borderRadius: "18px",
                  border: "2px solid #d8b4e8",
                  padding: "22px",
                }}
              >
                <div
                  style={{
                    display: "flex",
                    justifyContent: "space-between",
                    alignItems: "center",
                    marginBottom: "10px",
                  }}
                >
                  <h3 style={{ margin: 0, fontSize: "16.5px", color: "#4a155b" }}>
                    <MessageSquare
                      size={16}
                      style={{ verticalAlign: "middle", marginRight: "6px" }}
                    />
                    Complainant Two-Way Messages &amp; Appeal Thread (
                    {selectedComplaint.complainantMessages?.length ?? 0})
                  </h3>
                  <StatusPill tone="rose">Encrypted Thread</StatusPill>
                </div>
                <p
                  style={{
                    margin: "0 0 12px 0",
                    fontSize: "12.5px",
                    color: "#6e6275",
                  }}
                >
                  All follow-up replies, clarifications, and reopen/appeal
                  reasons sent by the user for{" "}
                  <strong>{selectedComplaint.referenceNumber}</strong> appear
                  below in real time:
                </p>

                {(!selectedComplaint.complainantMessages ||
                  selectedComplaint.complainantMessages.length === 0) ? (
                  <div
                    style={{
                      padding: "16px",
                      borderRadius: "12px",
                      background: "#fdf9fc",
                      border: "1px dashed #dcc8e6",
                      fontSize: "12.5px",
                      color: "#6e6275",
                      marginBottom: "12px",
                    }}
                  >
                    No follow-up messages or appeals have been sent on this
                    report yet. You can send a message to the complainant below.
                  </div>
                ) : (
                  <div
                    style={{
                      display: "flex",
                      flexDirection: "column",
                      gap: "10px",
                      maxHeight: "280px",
                      overflowY: "auto",
                      marginBottom: "14px",
                      paddingRight: "4px",
                    }}
                  >
                    {selectedComplaint.complainantMessages.map((msg) => {
                      const isReviewer = msg.senderRole === "SAFETY_REVIEWER";
                      const isAppeal = msg.senderLabel
                        .toLowerCase()
                        .includes("appeal");
                      return (
                        <div
                          key={msg.id}
                          style={{
                            padding: "12px 14px",
                            borderRadius: "14px",
                            background: isAppeal
                              ? "#fff4f6"
                              : isReviewer
                                ? "#f6ecfa"
                                : "#eefaf3",
                            border: isAppeal
                              ? "1px solid #f3b4c4"
                              : isReviewer
                                ? "1px solid #dec4ea"
                                : "1px solid #bce3cc",
                          }}
                        >
                          <div
                            style={{
                              display: "flex",
                              justifyContent: "space-between",
                              alignItems: "center",
                              gap: "8px",
                              marginBottom: "6px",
                              fontSize: "12px",
                            }}
                          >
                            <strong
                              style={{
                                color: isAppeal
                                  ? "#a61e42"
                                  : isReviewer
                                    ? "#631d76"
                                    : "#1f6e4e",
                              }}
                            >
                              {formatCleanText(msg.senderLabel)}
                            </strong>
                            <span style={{ color: "#877b8b", fontSize: "11.5px" }}>
                              {formatMessageTime(msg.createdAt)}
                            </span>
                          </div>
                          <div
                            style={{
                              fontSize: "13.5px",
                              color: "#31263a",
                              lineHeight: 1.45,
                              whiteSpace: "pre-wrap",
                            }}
                          >
                            {msg.message}
                          </div>
                        </div>
                      );
                    })}
                  </div>
                )}

                <div style={{ display: "flex", gap: "8px" }}>
                  <input
                    value={directReplyText}
                    onChange={(e) => setDirectReplyText(e.target.value)}
                    placeholder="Write a direct encrypted reply to the complainant..."
                    style={{
                      flex: 1,
                      padding: "10px 14px",
                      borderRadius: "999px",
                      border: "1px solid #d6c2df",
                      fontSize: "13px",
                    }}
                    onKeyDown={(e) => {
                      if (e.key === "Enter" && !e.shiftKey) {
                        e.preventDefault();
                        void handleSendDirectMessageToComplainant();
                      }
                    }}
                  />
                  <button className="button button--secondary"
                    type="button"
                    disabled={submitting}
                    onClick={() => void handleSendDirectMessageToComplainant()}
                    style={{
                      padding: "10px 18px",
                      borderRadius: "999px",
                      border: 0,
                      background: "#631d76",
                      color: "#fff",
                      fontWeight: 700,
                      fontSize: "12.5px",
                      cursor: "pointer",
                      display: "inline-flex",
                      alignItems: "center",
                      gap: "6px",
                    }}
                  >
                    <Send size={14} /> Send Reply
                  </button>
                </div>
              </div>

              {/* Card 3: Enforced 7-Status Transition (Clean Human Labels, Zero Underscores!) */}
              <div
                style={{
                  background: "#fff",
                  borderRadius: "18px",
                  border: "1px solid #eee7ee",
                  padding: "22px",
                }}
              >
                <h3 style={{ margin: "0 0 6px 0", fontSize: "16.5px" }}>
                  Update Status (Current:{" "}
                  {formatStatusLabel(selectedComplaint.status)})
                </h3>
                <p
                  style={{
                    margin: "0 0 12px 0",
                    fontSize: "12.5px",
                    color: "#6e6275",
                  }}
                >
                  Valid transitions from{" "}
                  <strong>{formatStatusLabel(selectedComplaint.status)}</strong>{" "}
                  are shown below:
                </p>
                <div
                  style={{
                    display: "flex",
                    gap: "8px",
                    flexWrap: "wrap",
                    marginBottom: "14px",
                  }}
                >
                  {(
                    VALID_NEXT_STATUSES[selectedComplaint.status] ?? ALL_STATUSES
                  ).map((st) => (
                    <button className="button button--secondary"
                      key={st}
                      type="button"
                      onClick={() => setNextStatus(st)}
                      style={{
                        padding: "8px 14px",
                        borderRadius: "999px",
                        fontSize: "12.5px",
                        fontWeight: 700,
                        cursor: "pointer",
                        border:
                          nextStatus === st
                            ? "2px solid #b94776"
                            : "1px solid #e2d4e6",
                        background: nextStatus === st ? "#fbeaf1" : "#fff",
                        color: nextStatus === st ? "#9b315d" : "#52345f",
                      }}
                    >
                      {formatStatusLabel(st)}
                    </button>
                  ))}
                </div>
                {nextStatus === "REJECTED_WITH_REASON" && (
                  <input
                    value={rejectionCode}
                    onChange={(e) => setRejectionCode(e.target.value)}
                    placeholder="Mandatory Rejection Reason Code"
                    style={{
                      width: "100%",
                      padding: "9px 12px",
                      borderRadius: "10px",
                      border: "1px solid #e2d4e6",
                      marginBottom: "10px",
                      fontSize: "13px",
                    }}
                  />
                )}
                <textarea
                  value={publicMessage}
                  onChange={(e) => setPublicMessage(e.target.value)}
                  placeholder={
                    nextStatus === "ADDITIONAL_INFO_REQUIRED"
                      ? "Required: Enter follow-up question for complainant..."
                      : "Optional status update message for the complainant..."
                  }
                  rows={2}
                  style={{
                    width: "100%",
                    padding: "10px 12px",
                    borderRadius: "10px",
                    border: "1px solid #e2d4e6",
                    marginBottom: "12px",
                    fontSize: "13px",
                  }}
                />
                <button className="button button--secondary"
                  type="button"
                  disabled={submitting}
                  onClick={() => void handleUpdateStatus()}
                  style={{
                    width: "100%",
                    padding: "11px",
                    borderRadius: "999px",
                    border: 0,
                    background: "#b94776",
                    color: "#fff",
                    fontWeight: 700,
                    cursor: "pointer",
                  }}
                >
                  Commit Status Transition ({formatStatusLabel(nextStatus)})
                </button>
              </div>

              {/* Card 4: Separated Private Internal Notes & Immutable Audit Trail */}
              <div
                style={{
                  background: "#fff",
                  borderRadius: "18px",
                  border: "1px solid #eee7ee",
                  padding: "22px",
                }}
              >
                <h3 style={{ margin: "0 0 8px 0", fontSize: "16.5px" }}>
                  <Lock
                    size={15}
                    style={{ verticalAlign: "middle", marginRight: "6px" }}
                  />
                  Private Internal Reviewer Notes (Never Visible to Users)
                </h3>
                <textarea
                  value={internalNoteText}
                  onChange={(e) => setInternalNoteText(e.target.value)}
                  placeholder="Add confidential internal investigation note..."
                  rows={2}
                  style={{
                    width: "100%",
                    padding: "10px",
                    borderRadius: "10px",
                    border: "1px solid #f3ce8a",
                    background: "#fff9ee",
                    marginBottom: "10px",
                    fontSize: "13px",
                  }}
                />
                <div style={{ display: "flex", gap: "8px", marginBottom: "14px" }}>
                  <select
                    value={noteVisibilityRole}
                    onChange={(e) => setNoteVisibilityRole(e.target.value)}
                    style={{
                      padding: "8px 10px",
                      borderRadius: "8px",
                      border: "1px solid #dcd0e0",
                      fontSize: "12px",
                      fontWeight: 600,
                    }}
                  >
                    <option value="SENIOR_REVIEWER">
                      Authorised Reviewers &amp; Above
                    </option>
                    <option value="SUPER_ADMIN">Super Admin Only</option>
                  </select>
                  <button className="button button--secondary"
                    type="button"
                    disabled={submitting}
                    onClick={() => void handleAddInternalNote()}
                    style={{
                      flex: 1,
                      padding: "8px 14px",
                      borderRadius: "999px",
                      border: 0,
                      background: "#52345f",
                      color: "#fff",
                      fontWeight: 700,
                      fontSize: "12.5px",
                      cursor: "pointer",
                    }}
                  >
                    Append Internal Note
                  </button>
                </div>

                {selectedComplaint.internalNotes.map((n) => (
                  <div
                    key={n.id}
                    style={{
                      background: "#fff9ee",
                      border: "1px solid #f3ce8a",
                      borderRadius: "10px",
                      padding: "10px 12px",
                      marginBottom: "8px",
                      fontSize: "12.5px",
                    }}
                  >
                    <strong>
                      [
                      {n.visibilityRole === "SUPER_ADMIN"
                        ? "Super Admin Only"
                        : "Authorised Reviewer"}{" "}
                      • {n.reviewerName}]:
                    </strong>{" "}
                    {n.noteText}
                  </div>
                ))}

                <h4
                  style={{
                    margin: "16px 0 8px 0",
                    fontSize: "12.5px",
                    textTransform: "uppercase",
                    color: "#877b8b",
                  }}
                >
                  <FileClock
                    size={14}
                    style={{ verticalAlign: "middle", marginRight: "4px" }}
                  />
                  Immutable Audit History
                </h4>
                <div
                  style={{
                    display: "flex",
                    flexDirection: "column",
                    gap: "6px",
                    fontSize: "12px",
                  }}
                >
                  {selectedComplaint.auditHistory.map((aud) => (
                    <div
                      key={aud.id}
                      style={{
                        display: "flex",
                        justifyContent: "space-between",
                        gap: "8px",
                        borderBottom: "1px solid #f3edf5",
                        paddingBottom: "6px",
                      }}
                    >
                      <span>
                        <strong>{aud.auditCode}</strong> •{" "}
                        {formatCleanText(aud.summary)}
                      </span>
                      <span style={{ color: "#877b8b" }}>
                        {formatCleanText(aud.actorLabel)}
                      </span>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          )}
        </div>
      )}

      {/* TAB 2: CONTROLLED EVIDENCE VAULT */}
      {activeTab === "vault" && (
        <div
          style={{
            background: "#fff",
            borderRadius: "18px",
            border: "1px solid #eee7ee",
            padding: "24px",
          }}
        >
          {!selectedComplaint ? (
            <p style={{ margin: 0, color: "#6e6275" }}>
              Select a complaint in the Triage Queue first to inspect its evidence vault.
            </p>
          ) : (
            <>
              <div
                style={{
                  display: "flex",
                  justifyContent: "space-between",
                  alignItems: "center",
                  marginBottom: "16px",
                }}
              >
                <div>
                  <h2 style={{ margin: 0, fontSize: "20px" }}>
                    Controlled Evidence Viewer &amp; Watermarked Download Vault
                  </h2>
                  <p
                    style={{
                      margin: "4px 0 0 0",
                      color: "#6e6275",
                      fontSize: "13.5px",
                    }}
                  >
                    Inspecting Case{" "}
                    <strong>{selectedComplaint.referenceNumber}</strong>. All
                    uploaded files have EXIF GPS and device metadata stripped on
                    upload and are blurred by default.
                  </p>
                </div>
                <StatusPill tone="green">SHA-256 Integrity Verified</StatusPill>
              </div>

              <div style={{ marginBottom: "18px" }}>
                <label
                  style={{
                    fontSize: "13px",
                    fontWeight: 700,
                    display: "block",
                    marginBottom: "6px",
                  }}
                >
                  Mandatory Audit Justification (min 10 chars) for Viewing or
                  Watermarked Export:
                </label>
                <input
                  value={exportReason}
                  onChange={(e) => setExportReason(e.target.value)}
                  style={{
                    width: "100%",
                    padding: "10px 14px",
                    borderRadius: "10px",
                    border: "1px solid #d6c2df",
                    fontSize: "13.5px",
                  }}
                />
              </div>

              {selectedComplaint.evidenceFiles.length === 0 ? (
                <p style={{ color: "#6e6275" }}>
                  This complaint was submitted without binary attachments.
                </p>
              ) : (
                <div
                  style={{
                    display: "grid",
                    gridTemplateColumns:
                      "repeat(auto-fit, minmax(300px, 1fr))",
                    gap: "16px",
                  }}
                >
                  {selectedComplaint.evidenceFiles.map((ev) => {
                    const watermark = revealedEvidenceIds[ev.id];
                    return (
                      <div
                        key={ev.id}
                        style={{
                          background: "#2a1132",
                          color: "#fff",
                          borderRadius: "16px",
                          padding: "20px",
                        }}
                      >
                        <div
                          style={{
                            display: "flex",
                            justifyContent: "space-between",
                            marginBottom: "10px",
                          }}
                        >
                          <strong style={{ fontFamily: "monospace" }}>
                            {ev.fileName}
                          </strong>
                          <StatusPill tone={ev.isPurged ? "urgent" : "green"}>
                            {ev.isPurged ? "Purged by User" : "EXIF Purged ✓"}
                          </StatusPill>
                        </div>
                        <div
                          style={{
                            background: "rgba(255,255,255,0.09)",
                            border: "1.5px dashed rgba(255,255,255,0.3)",
                            borderRadius: "12px",
                            padding: "24px",
                            textAlign: "center",
                            marginBottom: "12px",
                          }}
                        >
                          {watermark ? (
                            <div>
                              <Eye size={28} />
                              <div style={{ fontWeight: 800, marginTop: "6px" }}>
                                Evidence Revealed in Audit-Logged Session
                              </div>
                              <div
                                style={{
                                  fontFamily: "monospace",
                                  fontSize: "11.5px",
                                  color: "#f5c6d8",
                                  marginTop: "6px",
                                }}
                              >
                                {watermark}
                              </div>
                            </div>
                          ) : (
                            <div>
                              <Lock size={28} />
                              <div style={{ fontWeight: 800, marginTop: "6px" }}>
                                Blurred by Default for Survivor Privacy
                              </div>
                              <div
                                style={{
                                  fontSize: "12px",
                                  color: "#dec4ea",
                                  marginTop: "4px",
                                }}
                              >
                                SHA-256: {ev.sha256Digest.slice(0, 24)}...
                              </div>
                            </div>
                          )}
                        </div>
                        <div style={{ display: "flex", gap: "10px" }}>
                          <button className="button button--secondary"
                            type="button"
                            disabled={submitting || Boolean(ev.isPurged)}
                            onClick={() =>
                              void handleControlledEvidenceAccess(
                                ev.id,
                                "REVEAL_VIEWER",
                              )
                            }
                            style={{
                              flex: 1,
                              padding: "10px",
                              borderRadius: "999px",
                              border: 0,
                              background: "#c83e73",
                              color: "#fff",
                              fontWeight: 700,
                              fontSize: "12.5px",
                              cursor: "pointer",
                            }}
                          >
                            Reveal Evidence (Logs Audit)
                          </button>
                          <button className="button button--secondary"
                            type="button"
                            disabled={submitting || Boolean(ev.isPurged)}
                            onClick={() =>
                              void handleControlledEvidenceAccess(
                                ev.id,
                                "WATERMARKED_DOWNLOAD",
                              )
                            }
                            style={{
                              flex: 1,
                              padding: "10px",
                              borderRadius: "999px",
                              border: "1px solid #dec4ea",
                              background: "transparent",
                              color: "#fff",
                              fontWeight: 700,
                              fontSize: "12.5px",
                              cursor: "pointer",
                            }}
                          >
                            Watermarked Export
                          </button>
                        </div>
                      </div>
                    );
                  })}
                </div>
              )}
            </>
          )}
        </div>
      )}

      {/* TAB 3: DUPLICATE & REPEAT-OFFENDER CLUSTER MERGE */}
      {activeTab === "duplicates" && (
        <div
          style={{
            background: "#fff",
            borderRadius: "18px",
            border: "1px solid #eee7ee",
            padding: "24px",
          }}
        >
          <h2 style={{ margin: "0 0 6px 0", fontSize: "20px" }}>
            Duplicate Complaint &amp; Repeat-Offender Cluster Engine
          </h2>
          <p
            style={{
              margin: "0 0 18px 0",
              color: "#6e6275",
              fontSize: "13.5px",
            }}
          >
            Merge corroborating or duplicate reports targeting the same handle or
            incident into a primary investigation reference number.
          </p>

          <div
            style={{
              display: "grid",
              gridTemplateColumns: "1fr 1fr 1fr",
              gap: "14px",
              marginBottom: "18px",
            }}
          >
            <label style={{ fontSize: "12.5px", fontWeight: 700 }}>
              Primary Investigation Reference #
              <input
                value={mergePrimaryRef}
                onChange={(e) => setMergePrimaryRef(e.target.value)}
                placeholder="#SKH-ANON-2026-..."
                style={{
                  width: "100%",
                  marginTop: "6px",
                  padding: "10px 12px",
                  borderRadius: "10px",
                  border: "1px solid #dcd0e0",
                }}
              />
            </label>
            <label style={{ fontSize: "12.5px", fontWeight: 700 }}>
              Duplicate Reference #(s) (comma-separated)
              <input
                value={mergeDuplicateRefsInput}
                onChange={(e) => setMergeDuplicateRefsInput(e.target.value)}
                placeholder="#SKH-ANON-2026-..."
                style={{
                  width: "100%",
                  marginTop: "6px",
                  padding: "10px 12px",
                  borderRadius: "10px",
                  border: "1px solid #dcd0e0",
                }}
              />
            </label>
            <label style={{ fontSize: "12.5px", fontWeight: 700 }}>
              Cluster ID (Optional)
              <input
                value={mergeClusterId}
                onChange={(e) => setMergeClusterId(e.target.value)}
                placeholder="CLUST-209"
                style={{
                  width: "100%",
                  marginTop: "6px",
                  padding: "10px 12px",
                  borderRadius: "10px",
                  border: "1px solid #dcd0e0",
                }}
              />
            </label>
          </div>

          <button className="button button--secondary"
            type="button"
            disabled={submitting}
            onClick={() => void handleMergeCluster()}
            style={{
              padding: "12px 24px",
              borderRadius: "999px",
              border: 0,
              background: "#631d76",
              color: "#fff",
              fontWeight: 700,
              cursor: "pointer",
            }}
          >
            <GitMerge
              size={16}
              style={{ verticalAlign: "middle", marginRight: "8px" }}
            />
            Merge Duplicate Cluster on Backend
          </button>
        </div>
      )}

      {/* TAB 4: ABUSE & MALICIOUS-REPORT GUARD */}
      {activeTab === "malicious" && (
        <div
          style={{
            background: "#fff",
            borderRadius: "18px",
            border: "1px solid #eee7ee",
            padding: "24px",
          }}
        >
          <h2 style={{ margin: "0 0 8px 0", fontSize: "20px" }}>
            Abuse &amp; Malicious-Report Safeguards
          </h2>
          <p
            style={{
              margin: "0 0 18px 0",
              color: "#6e6275",
              fontSize: "13.5px",
            }}
          >
            Protects innocent members and women-owned businesses from bad-faith
            spam floods using blinded cryptographic rate-limit buckets—without
            unmasking anonymous users.
          </p>

          <div
            style={{
              display: "grid",
              gridTemplateColumns: "1fr 160px 1.5fr",
              gap: "14px",
              marginBottom: "18px",
            }}
          >
            <label style={{ fontSize: "12.5px", fontWeight: 700 }}>
              Target Complaint Reference #
              <input
                value={maliciousTargetRef}
                onChange={(e) => setMaliciousTargetRef(e.target.value)}
                placeholder="#SKH-ANON-2026-..."
                style={{
                  width: "100%",
                  marginTop: "6px",
                  padding: "10px 12px",
                  borderRadius: "10px",
                  border: "1px solid #dcd0e0",
                }}
              />
            </label>
            <label style={{ fontSize: "12.5px", fontWeight: 700 }}>
              Cooldown (Hours)
              <input
                type="number"
                min={1}
                max={720}
                value={maliciousCooldownHours}
                onChange={(e) =>
                  setMaliciousCooldownHours(Number(e.target.value))
                }
                style={{
                  width: "100%",
                  marginTop: "6px",
                  padding: "10px 12px",
                  borderRadius: "10px",
                  border: "1px solid #dcd0e0",
                }}
              />
            </label>
            <label style={{ fontSize: "12.5px", fontWeight: 700 }}>
              Audit Justification Reason
              <input
                value={maliciousReason}
                onChange={(e) => setMaliciousReason(e.target.value)}
                style={{
                  width: "100%",
                  marginTop: "6px",
                  padding: "10px 12px",
                  borderRadius: "10px",
                  border: "1px solid #dcd0e0",
                }}
              />
            </label>
          </div>

          <button className="button button--secondary"
            type="button"
            disabled={submitting}
            onClick={() => void handleMaliciousSafeguard()}
            style={{
              padding: "11px 22px",
              borderRadius: "999px",
              border: 0,
              background: "#c92a49",
              color: "#fff",
              fontWeight: 700,
              cursor: "pointer",
            }}
          >
            Reject as Malicious &amp; Throttle Blinded Bucket
          </button>
        </div>
      )}

      {/* TAB 5: CONFIGURABLE CATEGORIES & RETENTION POLICY (SUPER ADMIN ONLY) */}
      {activeTab === "config" && isSuperAdmin && (
        <div
          style={{
            display: "grid",
            gridTemplateColumns: "1.25fr 1fr",
            gap: "22px",
            alignItems: "start",
          }}
        >
          <div
            style={{
              background: "#fff",
              borderRadius: "18px",
              border: "1px solid #eee7ee",
              padding: "22px",
            }}
          >
            <h3 style={{ margin: "0 0 14px 0", fontSize: "17px" }}>
              Configurable Complaint Categories (Synced Live to App)
            </h3>
            <div
              style={{
                display: "grid",
                gridTemplateColumns: "1fr 1fr",
                gap: "10px",
                marginBottom: "16px",
              }}
            >
              {categories.map((cat) => (
                <div
                  key={cat.slug}
                  style={{
                    padding: "10px 12px",
                    borderRadius: "10px",
                    border: "1px solid #eee7ee",
                    display: "flex",
                    justifyContent: "space-between",
                    alignItems: "center",
                    gap: "8px",
                  }}
                >
                  <div>
                    <strong style={{ fontSize: "13px", display: "block" }}>
                      {cat.displayOrder}. {cat.name}
                    </strong>
                    <small style={{ fontSize: "11px", color: "#877b8b" }}>
                      {formatPriorityLabel(cat.defaultPriority)} •{" "}
                      {formatSeverityLabel(cat.defaultSeverity)}
                    </small>
                  </div>
                  <button className="button button--secondary"
                    type="button"
                    disabled={submitting}
                    onClick={() => void handleToggleCategory(cat)}
                    style={{
                      padding: "5px 10px",
                      borderRadius: "999px",
                      border: "1px solid #dcd0e0",
                      background: cat.isEnabled ? "#e8f5ed" : "#f5f2f6",
                      color: cat.isEnabled ? "#1f6e4e" : "#6e6275",
                      fontSize: "11px",
                      fontWeight: 800,
                      cursor: "pointer",
                    }}
                  >
                    {cat.isEnabled ? "Enabled (Toggle)" : "Off (Toggle)"}
                  </button>
                </div>
              ))}
            </div>
            <div
              style={{
                display: "grid",
                gridTemplateColumns: "1fr 1fr auto",
                gap: "8px",
              }}
            >
              <input
                value={newCatName}
                onChange={(e) => setNewCatName(e.target.value)}
                placeholder="New category title..."
                style={{
                  padding: "8px 12px",
                  borderRadius: "8px",
                  border: "1px solid #dcd0e0",
                  fontSize: "13px",
                }}
              />
              <input
                value={newCatDesc}
                onChange={(e) => setNewCatDesc(e.target.value)}
                placeholder="Short description..."
                style={{
                  padding: "8px 12px",
                  borderRadius: "8px",
                  border: "1px solid #dcd0e0",
                  fontSize: "13px",
                }}
              />
              <button className="button button--secondary"
                type="button"
                disabled={submitting}
                onClick={() => void handleAddCategory()}
                style={{
                  padding: "8px 16px",
                  borderRadius: "999px",
                  border: 0,
                  background: "#631d76",
                  color: "#fff",
                  fontWeight: 700,
                  fontSize: "12.5px",
                  cursor: "pointer",
                }}
              >
                <Plus size={14} style={{ verticalAlign: "middle" }} /> Save
              </button>
            </div>
          </div>

          <div
            style={{
              background: "#fff",
              borderRadius: "18px",
              border: "1px solid #eee7ee",
              padding: "22px",
            }}
          >
            <h3 style={{ margin: "0 0 14px 0", fontSize: "17px" }}>
              Configurable Retention &amp; Deletion Policies (DPDP Compliant)
            </h3>
            <div
              style={{
                display: "flex",
                flexDirection: "column",
                gap: "12px",
                marginBottom: "16px",
              }}
            >
              <label style={{ fontSize: "13px", fontWeight: 700 }}>
                Closed Case Raw Evidence Media Auto-Purge (Days)
                <input
                  type="number"
                  min={7}
                  max={3650}
                  value={closedRetentionDays}
                  onChange={(e) =>
                    setClosedRetentionDays(Number(e.target.value))
                  }
                  style={{
                    width: "100%",
                    marginTop: "4px",
                    padding: "8px 12px",
                    borderRadius: "8px",
                    border: "1px solid #dcd0e0",
                  }}
                />
              </label>
              <label style={{ fontSize: "13px", fontWeight: 700 }}>
                Rejected / Non-Actionable Report Auto-Purge (Days)
                <input
                  type="number"
                  min={7}
                  max={3650}
                  value={rejectedRetentionDays}
                  onChange={(e) =>
                    setRejectedRetentionDays(Number(e.target.value))
                  }
                  style={{
                    width: "100%",
                    marginTop: "4px",
                    padding: "8px 12px",
                    borderRadius: "8px",
                    border: "1px solid #dcd0e0",
                  }}
                />
              </label>
              <label style={{ fontSize: "13px", fontWeight: 700 }}>
                Server Technical Rate-Limit Logs Rotation (Days)
                <input
                  type="number"
                  min={1}
                  max={365}
                  value={logRetentionDays}
                  onChange={(e) => setLogRetentionDays(Number(e.target.value))}
                  style={{
                    width: "100%",
                    marginTop: "4px",
                    padding: "8px 12px",
                    borderRadius: "8px",
                    border: "1px solid #dcd0e0",
                  }}
                />
              </label>
            </div>
            <button className="button button--secondary"
              type="button"
              disabled={submitting}
              onClick={() => void handleSaveRetentionPolicy()}
              style={{
                width: "100%",
                padding: "11px",
                borderRadius: "999px",
                border: 0,
                background: "#39785c",
                color: "#fff",
                fontWeight: 700,
                cursor: "pointer",
              }}
            >
              Save DPDP Retention Policy
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
