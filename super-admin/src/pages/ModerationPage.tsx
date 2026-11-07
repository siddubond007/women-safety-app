import { useCallback, useEffect, useMemo, useState } from "react";
import {
  AlertTriangle,
  BookOpen,
  CheckCircle2,
  Eye,
  Filter,
  Image as ImageIcon,
  Lock,
  MessageSquareText,
  Plus,
  RefreshCw,
  Search,
  ShieldAlert,
  Sparkles,
  Trash2,
  UserCheck,
  X,
} from "lucide-react";
import { StatusPill } from "../components/StatusPill";
import { adminApi, API_BASE_URL } from "../services/api/adminApi";
import { adminAuthService } from "../services/auth/adminAuthService";

interface TargetPostEvidence {
  id: string;
  authorAccountId?: string;
  authorName?: string;
  authorUsername?: string;
  content: string;
  imageAsset?: string | null;
  categoryBadge?: string;
  status?: string;
  createdAt?: string;
}

interface TargetCommentEvidence {
  id: string;
  postId?: string;
  authorName?: string;
  content: string;
  isRemovedByModerator?: boolean;
}

interface TargetProfileEvidence {
  accountId: string;
  displayName: string;
  username: string;
  avatarAsset?: string;
  bio?: string;
  location?: string;
  accountStatus: string;
  verificationStatus: string;
}

interface InternalNoteItem {
  id: string;
  author: string;
  note: string;
  createdAt: string;
}

interface EnrichedReportItem {
  id: string;
  targetHandle: string;
  targetType?: string;
  postId?: string | null;
  commentId?: string | null;
  category?: string;
  reason: string;
  details?: string | null;
  status: string;
  priority?: string;
  severity?: string;
  assignedReviewerId?: string | null;
  assignedReviewerName?: string | null;
  appealStatus?: string | null;
  appealReason?: string | null;
  internalNotes?: InternalNoteItem[];
  repeatOffenderCount?: number;
  targetPost?: TargetPostEvidence | null;
  targetComment?: TargetCommentEvidence | null;
  targetProfile?: TargetProfileEvidence | null;
  evidenceUrls?: string[];
  reviewerNotes?: string | null;
  reviewedBy?: string | null;
  reviewedAt?: string | null;
  createdAt: string;
}

interface WellnessResourceItem {
  id: string;
  slug: string;
  category: string;
  title: string;
  subtitle: string;
  durationLabel?: string | null;
  thumbAsset?: string | null;
  createdAt?: string;
}

interface OperationsPayload {
  counts: {
    totalAccounts: number;
    totalPosts: number;
    totalGroups: number;
    totalReports: number;
    totalBlocks: number;
    totalSosEvents: number;
    totalMediaUploads: number;
  };
  healthDataIsolation?: {
    enforced: boolean;
    adminAccessBlocked: boolean;
    rlsPolicyActive: boolean;
    policyNote: string;
  };
  reports: EnrichedReportItem[];
  wellnessResources?: WellnessResourceItem[];
  sosEvents: Array<{
    id: string;
    eventType: string;
    status: string;
    locationLabel: string;
    createdAt: string;
  }>;
  auditEvents: Array<{
    id: string;
    actorType: string;
    action: string;
    targetType: string;
    outcome: string;
    createdAt: string;
  }>;
}

type QueueTab =
  | "ALL"
  | "SUBMITTED"
  | "UNDER_REVIEW"
  | "PRIORITY"
  | "ASSIGNED_TO_ME"
  | "ESCALATED"
  | "ACTION_TAKEN"
  | "DISMISSED";

function resolveAuthorizedMediaEndpoint(rawUrl: string): {
  endpointUrl: string;
  requiresAdminAuthHeader: boolean;
} {
  const trimmed = (rawUrl ?? "").trim();
  if (!trimmed) {
    return { endpointUrl: "", requiresAdminAuthHeader: false };
  }
  const match = /\/media\/object\/([a-zA-Z0-9_-]+)/.exec(trimmed);
  if (match && match[1]) {
    return {
      endpointUrl: `${API_BASE_URL}/admin-review/media/${encodeURIComponent(match[1])}/preview`,
      requiresAdminAuthHeader: true,
    };
  }
  if (trimmed.startsWith("/api/v1/admin-review/media/")) {
    return {
      endpointUrl: `${API_BASE_URL.replace(/\/api\/v1$/, "")}${trimmed}`,
      requiresAdminAuthHeader: true,
    };
  }
  if (trimmed.startsWith("http://") || trimmed.startsWith("https://")) {
    return { endpointUrl: trimmed, requiresAdminAuthHeader: false };
  }
  if (trimmed.startsWith("/api/v1/")) {
    return {
      endpointUrl: `${API_BASE_URL.replace(/\/api\/v1$/, "")}${trimmed}`,
      requiresAdminAuthHeader: true,
    };
  }
  return { endpointUrl: trimmed, requiresAdminAuthHeader: false };
}

function AuthorizedMediaPreview({
  rawUrl,
  alt,
  style,
}: {
  rawUrl: string;
  alt: string;
  style?: React.CSSProperties;
}) {
  const { endpointUrl, requiresAdminAuthHeader } =
    resolveAuthorizedMediaEndpoint(rawUrl);
  const [preview, setPreview] = useState<{
    rawUrl: string;
    objectUrl: string;
    contentType: string;
    failed: boolean;
  } | null>(null);

  useEffect(() => {
    if (!endpointUrl || !requiresAdminAuthHeader) return;

    let active = true;
    let revokeUrl: string | null = null;
    const token = adminAuthService.getToken() ?? "";
    const headers: Record<string, string> = {};
    if (token) {
      headers["x-sakhi-admin-token"] = token;
      headers["x-sakhi-admin-review-token"] = token;
      headers["Authorization"] = `Bearer ${token}`;
    }

    fetch(endpointUrl, { method: "GET", headers })
      .then(async (res) => {
        if (!res.ok) {
          throw new Error(`HTTP ${res.status}`);
        }
        const contentType = res.headers.get("content-type") || "image/jpeg";
        const blob = await res.blob();
        if (!active) return;
        revokeUrl = URL.createObjectURL(blob);
        setPreview({
          rawUrl,
          objectUrl: revokeUrl,
          contentType,
          failed: false,
        });
      })
      .catch(() => {
        if (active) {
          setPreview({
            rawUrl,
            objectUrl: "",
            contentType: "",
            failed: true,
          });
        }
      });

    return () => {
      active = false;
      if (revokeUrl) URL.revokeObjectURL(revokeUrl);
    };
  }, [rawUrl, endpointUrl, requiresAdminAuthHeader]);

  const currentPreview = preview?.rawUrl === rawUrl ? preview : null;
  const objectUrl = requiresAdminAuthHeader
    ? currentPreview?.objectUrl ?? ""
    : endpointUrl;
  const contentType = requiresAdminAuthHeader
    ? currentPreview?.contentType ?? "image/jpeg"
    : endpointUrl.toLowerCase().endsWith(".mp4")
      ? "video/mp4"
      : "image/jpeg";
  const failed = currentPreview?.failed === true;

  if (!endpointUrl) {
    return (
      <div
        style={{
          padding: "8px 10px",
          borderRadius: 8,
          background: "#F9FAFB",
          border: "1px solid #E5E7EB",
          color: "#6B7280",
          fontSize: 11.5,
        }}
      >
        No evidence file was supplied.
      </div>
    );
  }

  if (failed) {
    return (
      <div
        style={{
          padding: "8px 10px",
          borderRadius: 8,
          background: "#FEF2F2",
          border: "1px solid #FECACA",
          color: "#991B1B",
          fontSize: 11.5,
          fontWeight: 600,
        }}
      >
        Submitted evidence file unavailable or removed from storage.
      </div>
    );
  }

  if (!objectUrl) {
    return (
      <div
        style={{
          padding: "8px 10px",
          borderRadius: 8,
          background: "#F9FAFB",
          border: "1px solid #E5E7EB",
          color: "#6B7280",
          fontSize: 11.5,
        }}
      >
        Loading authorized evidence preview…
      </div>
    );
  }

  if (contentType.startsWith("video/") || rawUrl.toLowerCase().endsWith(".mp4")) {
    return <video src={objectUrl} controls style={style} />;
  }

  return <img src={objectUrl} alt={alt} style={style} />;
}

export function ModerationPage({ section = "moderation" }: { section?: string }) {
  const [data, setData] = useState<OperationsPayload | null>(null);
  const [driveStatus, setDriveStatus] = useState<Record<string, unknown> | null>(null);
  const [loading, setLoading] = useState(true);
  const [notice, setNotice] = useState("");
  const [error, setError] = useState("");
  const [reviewerComments, setReviewerComments] = useState<Record<string, string>>({});

  // Queue filtering & triage state
  const [activeQueueTab, setActiveQueueTab] = useState<QueueTab>("ALL");
  const [searchQuery, setSearchQuery] = useState("");
  const [targetTypeFilter, setTargetTypeFilter] = useState<string>("ALL");
  const [selectedReportId, setSelectedReportId] = useState<string | null>(null);

  // Triage drawer form state
  const [triagePriority, setTriagePriority] = useState("P1_HIGH");
  const [triageSeverity, setTriageSeverity] = useState("S2_HIGH");
  const [triageAssignee, setTriageAssignee] = useState("");
  const [triageAppealStatus, setTriageAppealStatus] = useState("");
  const [triageInternalNote, setTriageInternalNote] = useState("");

  // Wellness content management form state (SRS 12.3)
  const [wellnessTitle, setWellnessTitle] = useState("");
  const [wellnessCategory, setWellnessCategory] = useState("Period Pain Help");
  const [wellnessSubtitle, setWellnessSubtitle] = useState("");
  const [wellnessDuration, setWellnessDuration] = useState("4 min read");

  const currentReviewerLabel =
    adminAuthService.getProfile()?.reviewerLabel || "Trust & Safety Reviewer";

  const fetchOperations = useCallback(async () => {
    const [ops, drive] = await Promise.all([
      adminApi<OperationsPayload>("/admin-review/operations"),
      fetch(`${API_BASE_URL}/integrations/google-drive/status`)
        .then((r) => r.json())
        .catch(() => null),
    ]);
    return { ops, drive };
  }, []);

  const load = useCallback(async () => {
    setLoading(true);
    setError("");
    try {
      const { ops, drive } = await fetchOperations();
      setData(ops);
      setDriveStatus(drive);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Failed to load operations data.");
    } finally {
      setLoading(false);
    }
  }, [fetchOperations]);

  useEffect(() => {
    let active = true;

    fetchOperations()
      .then(({ ops, drive }) => {
        if (active) {
          setData(ops);
          setDriveStatus(drive);
          setError("");
        }
      })
      .catch((e: unknown) => {
        if (active) {
          setError(e instanceof Error ? e.message : "Failed to load operations data.");
        }
      })
      .finally(() => {
        if (active) setLoading(false);
      });

    return () => {
      active = false;
    };
  }, [fetchOperations]);

  const selectedReport = useMemo(() => {
    if (!data || !selectedReportId) return null;
    return data.reports.find((r) => r.id === selectedReportId) ?? null;
  }, [data, selectedReportId]);

  const filteredReports = useMemo(() => {
    const list = data?.reports ?? [];
    const q = searchQuery.trim().toLowerCase();
    return list.filter((rep) => {
      const status = (rep.status ?? "SUBMITTED").toUpperCase();
      const prio = (rep.priority ?? "P2_NORMAL").toUpperCase();
      if (activeQueueTab === "SUBMITTED" && status !== "SUBMITTED") return false;
      if (activeQueueTab === "UNDER_REVIEW" && status !== "UNDER_REVIEW") return false;
      if (
        activeQueueTab === "PRIORITY" &&
        prio !== "P0_CRITICAL" &&
        prio !== "P1_HIGH"
      ) {
        return false;
      }
      if (
        activeQueueTab === "ASSIGNED_TO_ME" &&
        !(rep.assignedReviewerName ?? "")
          .toLowerCase()
          .includes(currentReviewerLabel.toLowerCase())
      ) {
        return false;
      }
      if (activeQueueTab === "ESCALATED" && status !== "ESCALATED") return false;
      if (activeQueueTab === "ACTION_TAKEN" && status !== "ACTION_TAKEN") return false;
      if (activeQueueTab === "DISMISSED" && status !== "DISMISSED") return false;

      if (
        targetTypeFilter !== "ALL" &&
        (rep.targetType ?? "POST").toUpperCase() !== targetTypeFilter
      ) {
        return false;
      }

      if (q) {
        const hay = [
          rep.id,
          rep.targetHandle,
          rep.reason,
          rep.details ?? "",
          rep.category ?? "",
          rep.targetPost?.content ?? "",
          rep.targetComment?.content ?? "",
          rep.targetProfile?.displayName ?? "",
        ]
          .join(" ")
          .toLowerCase();
        if (!hay.includes(q)) return false;
      }
      return true;
    });
  }, [data?.reports, activeQueueTab, searchQuery, targetTypeFilter, currentReviewerLabel]);

  async function resolveReport(reportId: string, actionType: string) {
    const customNote = (reviewerComments[reportId] ?? "").trim();
    const resolvedReason =
      customNote.length >= 3
        ? customNote
        : `Action ${actionType} recorded by Trust & Safety reviewer.`;
    try {
      await adminApi(`/admin-review/reports/${reportId}/resolve`, {
        method: "POST",
        body: {
          actionType,
          reason: resolvedReason,
        },
      });
      setNotice(`Report ${reportId.slice(0, 8)} updated with ${actionType}.`);
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not resolve report.");
    }
  }

  async function saveReportTriage(reportId: string, assignToSelf = false) {
    try {
      const assignedName = assignToSelf
        ? currentReviewerLabel
        : triageAssignee.trim() || null;
      await adminApi(`/admin-review/moderation/reports/${reportId}/triage`, {
        method: "PATCH",
        body: {
          priority: triagePriority,
          severity: triageSeverity,
          assignedReviewerName: assignedName,
          appealStatus: triageAppealStatus || null,
          internalNote: triageInternalNote.trim() || undefined,
          status:
            selectedReport?.status === "SUBMITTED" && assignToSelf
              ? "UNDER_REVIEW"
              : selectedReport?.status,
        },
      });
      setTriageInternalNote("");
      setNotice(
        assignToSelf
          ? `Assigned report ${reportId.slice(0, 8)} to ${currentReviewerLabel}.`
          : `Saved triage metadata & internal notes for report ${reportId.slice(0, 8)}.`,
      );
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not update report triage.");
    }
  }

  async function saveWellnessResource() {
    if (!wellnessTitle.trim() || !wellnessSubtitle.trim()) {
      setError("Enter both an article title and summary before publishing.");
      return;
    }
    try {
      await adminApi("/admin-review/wellness-resources", {
        method: "POST",
        body: {
          title: wellnessTitle.trim(),
          category: wellnessCategory.trim(),
          subtitle: wellnessSubtitle.trim(),
          durationLabel: wellnessDuration.trim() || "4 min read",
        },
      });
      setWellnessTitle("");
      setWellnessSubtitle("");
      setNotice("Published educational & wellness resource to the Sakhi catalog.");
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not save wellness resource.");
    }
  }

  async function removeWellnessResource(resourceId: string) {
    try {
      await adminApi(`/admin-review/wellness-resources/${resourceId}`, {
        method: "DELETE",
      });
      setNotice("Removed educational & wellness resource.");
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not remove wellness resource.");
    }
  }

  async function verifyRemoteDrive() {
    try {
      const res = await fetch(`${API_BASE_URL}/integrations/google-drive/status?verify=true`).then((r) =>
        r.json(),
      );
      setDriveStatus(res);
      setNotice("Completed live Google Drive OAuth & root folder verification.");
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not verify Google Drive.");
    }
  }

  return (
    <div className="dashboard-page">
      <section className="page-heading">
        <div>
          <div className="eyebrow">
            <span className="eyebrow-line" /> TRUST, SAFETY &amp; PLATFORM OPERATIONS
          </div>
          <h1>
            {section === "emergency"
              ? "SOS & Emergency Telemetry"
              : section === "integrations"
                ? "Integrations & Google Drive Storage Health"
                : section === "audit"
                  ? "Audit Trail & Security Events"
                  : section === "wellness"
                    ? "Educational & Wellness Content Governance"
                    : section === "action-center"
                      ? "Trust & Safety Action Center"
                      : "Trust & Safety Moderation Queue"}
          </h1>
          <p>
            Confidential member reports with full post/media evidence preview, reviewer triage, SOS telemetry, and strict reproductive health privacy isolation.
          </p>
        </div>
        <div className="heading-meta">
          <StatusPill tone="green">CONFIDENTIAL QUEUE</StatusPill>
          <button
            className="button button--secondary"
            type="button"
            onClick={() => void load()}
            disabled={loading}
          >
            <RefreshCw size={14} /> Refresh
          </button>
        </div>
      </section>

      {notice && (
        <div className="member-toast" role="status" style={{ marginBottom: 16 }}>
          <CheckCircle2 size={17} />
          <span>{notice}</span>
        </div>
      )}
      {error && (
        <div className="panel" role="alert" style={{ padding: 16, marginBottom: 16 }}>
          <strong>Error:</strong> {error}
        </div>
      )}

      {/* SRS 9.4 & 12.2 Health Data Isolation Guarantee Banner */}
      {data?.healthDataIsolation && (
        <section
          className="panel"
          style={{
            marginBottom: 20,
            padding: "14px 18px",
            background: "linear-gradient(135deg, #FDF2F8 0%, #F5F3FF 100%)",
            border: "1px solid #FBCFE8",
            display: "flex",
            alignItems: "center",
            justifyContent: "space-between",
            gap: 16,
          }}
        >
          <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
            <Lock size={20} color="#9D174D" />
            <div>
              <strong style={{ color: "#831843", fontSize: 13.5 }}>
                Strict Health &amp; Cycle Data Isolation Active (SRS Sections 9.4 &amp; 12.2)
              </strong>
              <div style={{ fontSize: 12.5, color: "#6B7280", marginTop: 2 }}>
                {data.healthDataIsolation.policyNote}
              </div>
            </div>
          </div>
          <StatusPill tone="green">RLS &amp; OWNER-ISOLATED</StatusPill>
        </section>
      )}

      {/* Educational & Wellness Content Section (SRS 12.3) */}
      {section === "wellness" && data && (
        <section className="panel queue-panel" style={{ marginBottom: 20 }}>
          <div className="panel-heading">
            <div>
              <span className="panel-kicker">SRS SECTION 12.3 — EDUCATIONAL &amp; WELLNESS CONTENT</span>
              <h2>Period Pain Help, Cycle Science &amp; Mental Wellness Guides ({data.wellnessResources?.length ?? 0})</h2>
              <p>
                Publish and curate non-personal educational articles, cramp relief guides, and meditation resources without accessing any member health logs.
              </p>
            </div>
            <BookOpen size={20} />
          </div>

          <div
            style={{
              display: "grid",
              gridTemplateColumns: "repeat(auto-fit, minmax(220px, 1fr))",
              gap: 12,
              padding: "16px 20px",
              background: "#FAF5FF",
              borderRadius: 12,
              marginBottom: 16,
            }}
          >
            <input
              type="text"
              placeholder="Article Title (e.g., Heat Therapy for Cramps)"
              value={wellnessTitle}
              onChange={(e) => setWellnessTitle(e.target.value)}
              style={{ padding: "8px 12px", borderRadius: 8, border: "1px solid #DFC9E3" }}
            />
            <select
              value={wellnessCategory}
              onChange={(e) => setWellnessCategory(e.target.value)}
              style={{ padding: "8px 12px", borderRadius: 8, border: "1px solid #DFC9E3" }}
            >
              <option value="Period Pain Help">Period Pain Help</option>
              <option value="Cycle Science">Cycle Science</option>
              <option value="Clinical Guidance">Clinical Guidance</option>
              <option value="Mental Wellness">Mental Wellness</option>
              <option value="Self-Care & Nutrition">Self-Care &amp; Nutrition</option>
            </select>
            <input
              type="text"
              placeholder="Read / Session Duration (e.g., 4 min read)"
              value={wellnessDuration}
              onChange={(e) => setWellnessDuration(e.target.value)}
              style={{ padding: "8px 12px", borderRadius: 8, border: "1px solid #DFC9E3" }}
            />
            <input
              type="text"
              placeholder="Evidence-based summary & medical guidance..."
              value={wellnessSubtitle}
              onChange={(e) => setWellnessSubtitle(e.target.value)}
              style={{
                gridColumn: "1 / -1",
                padding: "8px 12px",
                borderRadius: 8,
                border: "1px solid #DFC9E3",
              }}
            />
            <div>
              <button
                className="button button--primary"
                type="button"
                onClick={() => void saveWellnessResource()}
              >
                <Plus size={14} /> Publish Educational Guide
              </button>
            </div>
          </div>

          <div className="table-scroll">
            <table className="operations-table">
              <thead>
                <tr>
                  <th>Title</th>
                  <th>Category</th>
                  <th>Summary</th>
                  <th>Duration</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                {(data.wellnessResources ?? []).map((res) => (
                  <tr key={res.id}>
                    <td>
                      <strong>{res.title}</strong>
                      <div style={{ fontSize: 11, color: "#6E6275" }}>slug: {res.slug}</div>
                    </td>
                    <td>
                      <StatusPill tone="green">{res.category}</StatusPill>
                    </td>
                    <td>{res.subtitle}</td>
                    <td>{res.durationLabel ?? "4 min read"}</td>
                    <td>
                      <button
                        className="button button--secondary"
                        type="button"
                        onClick={() => void removeWellnessResource(res.id)}
                      >
                        <Trash2 size={13} /> Remove
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>
      )}

      {driveStatus && (
        <section className="panel queue-panel" style={{ marginBottom: 20 }}>
          <div className="panel-heading">
            <div>
              <span className="panel-kicker">PRIVATE GOOGLE DRIVE STORAGE</span>
              <h2>Google Drive Hierarchy &amp; OAuth Connection</h2>
              <p>
                Root folder: <code>{String(driveStatus.storageFolder ?? "Sakhi Media")}</code> · Configured:{" "}
                <strong>{String(Boolean(driveStatus.configured))}</strong> · Connected:{" "}
                <strong>{String(Boolean(driveStatus.connected))}</strong>
              </p>
            </div>
            <button className="button button--primary" type="button" onClick={() => void verifyRemoteDrive()}>
              Verify Remote Google Drive
            </button>
          </div>
        </section>
      )}

      {data && (
        <>
          <section className="panel queue-panel" style={{ marginBottom: 20 }}>
            <div className="panel-heading">
              <div>
                <span className="panel-kicker">SRS SECTION 5.4 &amp; 12.1 — MODERATION TRIAGE</span>
                <h2>
                  Confidential Content &amp; Member Reports ({filteredReports.length} / {data.reports.length})
                </h2>
                <p>
                  Inspect reported post text, attached photos/videos, comments, member profile history, and execute auditable moderation actions.
                </p>
              </div>
              <ShieldAlert size={20} />
            </div>

            {/* Queue Tabs */}
            <div
              style={{
                display: "flex",
                gap: 8,
                flexWrap: "wrap",
                padding: "0 20px 14px 20px",
                borderBottom: "1px solid #F3E8FF",
              }}
            >
              {(
                [
                  { id: "ALL", label: `All (${data.reports.length})` },
                  {
                    id: "SUBMITTED",
                    label: `New (${data.reports.filter((r) => r.status === "SUBMITTED").length})`,
                  },
                  {
                    id: "UNDER_REVIEW",
                    label: `Under Review (${data.reports.filter((r) => r.status === "UNDER_REVIEW").length})`,
                  },
                  {
                    id: "PRIORITY",
                    label: `High Priority (${data.reports.filter((r) => r.priority === "P0_CRITICAL" || r.priority === "P1_HIGH").length})`,
                  },
                  { id: "ASSIGNED_TO_ME", label: "Assigned to Me" },
                  {
                    id: "ESCALATED",
                    label: `Escalated (${data.reports.filter((r) => r.status === "ESCALATED").length})`,
                  },
                  {
                    id: "ACTION_TAKEN",
                    label: `Resolved (${data.reports.filter((r) => r.status === "ACTION_TAKEN").length})`,
                  },
                  {
                    id: "DISMISSED",
                    label: `Dismissed (${data.reports.filter((r) => r.status === "DISMISSED").length})`,
                  },
                ] as Array<{ id: QueueTab; label: string }>
              ).map((tab) => (
                <button
                  key={tab.id}
                  type="button"
                  onClick={() => setActiveQueueTab(tab.id)}
                  className={
                    activeQueueTab === tab.id ? "button button--primary" : "button button--secondary"
                  }
                  style={{ padding: "6px 12px", fontSize: 12.5 }}
                >
                  {tab.label}
                </button>
              ))}
            </div>

            {/* Search & Target Type Filter Bar */}
            <div
              style={{
                display: "flex",
                gap: 12,
                flexWrap: "wrap",
                alignItems: "center",
                padding: "14px 20px",
              }}
            >
              <div style={{ display: "flex", alignItems: "center", gap: 8, flex: 1, minWidth: 240 }}>
                <Search size={15} color="#6E6275" />
                <input
                  type="text"
                  placeholder="Search by @handle, post text, report ID, or reason..."
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  style={{
                    width: "100%",
                    padding: "8px 12px",
                    borderRadius: 8,
                    border: "1px solid #DFC9E3",
                    fontSize: 13,
                  }}
                />
              </div>
              <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
                <Filter size={15} color="#6E6275" />
                <select
                  value={targetTypeFilter}
                  onChange={(e) => setTargetTypeFilter(e.target.value)}
                  style={{
                    padding: "8px 12px",
                    borderRadius: 8,
                    border: "1px solid #DFC9E3",
                    fontSize: 13,
                  }}
                >
                  <option value="ALL">All Target Types</option>
                  <option value="POST">Posts &amp; Photos</option>
                  <option value="COMMENT">Comments</option>
                  <option value="MEMBER">Member Profiles</option>
                  <option value="BUSINESS">Business Pages</option>
                  <option value="DIRECT_MESSAGE">Direct Messages</option>
                </select>
              </div>
            </div>

            <div className="table-scroll">
              <table className="operations-table">
                <thead>
                  <tr>
                    <th>Target &amp; History</th>
                    <th>Reason &amp; Reported Content Preview</th>
                    <th>Priority &amp; Status</th>
                    <th>Submitted</th>
                    <th>Reviewer Decision &amp; Triage</th>
                  </tr>
                </thead>
                <tbody>
                  {filteredReports.length === 0 && (
                    <tr>
                      <td colSpan={5} className="member-empty-cell">
                        No moderation reports match the selected queue filter.
                      </td>
                    </tr>
                  )}
                  {filteredReports.map((rep) => {
                    const hasMedia =
                      Boolean(rep.targetPost?.imageAsset) ||
                      (rep.evidenceUrls && rep.evidenceUrls.length > 0);
                    const previewMediaUrl =
                      rep.targetPost?.imageAsset || rep.evidenceUrls?.[0] || "";
                    return (
                      <tr key={rep.id}>
                        <td>
                          <strong>{rep.targetHandle}</strong>
                          <div style={{ fontSize: 11.5, color: "#6E6275", marginTop: 2 }}>
                            Type: <strong>{rep.targetType ?? "POST"}</strong>
                            {rep.category ? ` · ${rep.category}` : ""}
                          </div>
                          {(rep.repeatOffenderCount ?? 1) > 1 && (
                            <div
                              style={{
                                marginTop: 4,
                                display: "inline-flex",
                                alignItems: "center",
                                gap: 4,
                                padding: "2px 8px",
                                borderRadius: 999,
                                background: "#FEE2E2",
                                color: "#991B1B",
                                fontSize: 11,
                                fontWeight: 700,
                              }}
                            >
                              <AlertTriangle size={11} /> {rep.repeatOffenderCount}x Repeat Reports
                            </div>
                          )}
                          {rep.assignedReviewerName && (
                            <div style={{ fontSize: 11, color: "#6D28D9", marginTop: 4 }}>
                              Assigned: {rep.assignedReviewerName}
                            </div>
                          )}
                        </td>
                        <td style={{ maxWidth: 360 }}>
                          <div style={{ fontWeight: 600 }}>{rep.reason}</div>
                          {rep.details && (
                            <small style={{ color: "#6E6275", display: "block", marginTop: 2 }}>
                              Reporter Note: {rep.details}
                            </small>
                          )}
                          {rep.targetPost && (
                            <div
                              style={{
                                marginTop: 8,
                                padding: "8px 10px",
                                borderRadius: 8,
                                background: "#FDF2F8",
                                border: "1px solid #FBCFE8",
                                fontSize: 12,
                              }}
                            >
                              <div style={{ fontWeight: 700, color: "#831843", marginBottom: 2 }}>
                                Reported Post ({rep.targetPost.categoryBadge ?? "Community"}):
                              </div>
                              <div style={{ color: "#374151" }}>
                                {rep.targetPost.content
                                  ? rep.targetPost.content.slice(0, 140)
                                  : "(Media-only post)"}
                              </div>
                              {hasMedia && previewMediaUrl && (
                                <div
                                  style={{
                                    marginTop: 6,
                                    display: "flex",
                                    alignItems: "center",
                                    gap: 8,
                                  }}
                                >
                                  <AuthorizedMediaPreview
                                  key={previewMediaUrl}

                                    rawUrl={previewMediaUrl}
                                    alt="Reported post media preview"
                                    style={{
                                      width: 56,
                                      height: 56,
                                      objectFit: "cover",
                                      borderRadius: 6,
                                      border: "1px solid #F9A8D4",
                                    }}
                                  />
                                  <span style={{ fontSize: 11, color: "#9D174D", fontWeight: 600 }}>
                                    <ImageIcon size={12} style={{ verticalAlign: "middle" }} /> Attached Media Evidence
                                  </span>
                                </div>
                              )}
                            </div>
                          )}
                          {rep.targetComment && (
                            <div
                              style={{
                                marginTop: 6,
                                padding: "6px 10px",
                                borderRadius: 8,
                                background: "#F5F3FF",
                                fontSize: 12,
                              }}
                            >
                              <strong>Reported Comment:</strong> “{rep.targetComment.content}”
                            </div>
                          )}
                        </td>
                        <td>
                          <div style={{ display: "flex", flexDirection: "column", gap: 6 }}>
                            <StatusPill
                              tone={
                                rep.status === "SUBMITTED" || rep.status === "ESCALATED"
                                  ? "amber"
                                  : "green"
                              }
                            >
                              {rep.status}
                            </StatusPill>
                            <span style={{ fontSize: 11.5, color: "#6E6275" }}>
                              {rep.priority ?? "P2_NORMAL"} · {rep.severity ?? "S3_MEDIUM"}
                            </span>
                          </div>
                        </td>
                        <td>{new Date(rep.createdAt).toLocaleString("en-IN")}</td>
                        <td>
                          <div style={{ display: "flex", flexDirection: "column", gap: 8, minWidth: 280 }}>
                            <div style={{ display: "flex", alignItems: "center", gap: 6 }}>
                              <MessageSquareText size={14} color="#6E6275" />
                              <input
                                type="text"
                                placeholder="Reviewer decision note / comment..."
                                value={reviewerComments[rep.id] ?? ""}
                                onChange={(e) =>
                                  setReviewerComments((prev) => ({
                                    ...prev,
                                    [rep.id]: e.target.value,
                                  }))
                                }
                                style={{
                                  width: "100%",
                                  padding: "6px 10px",
                                  borderRadius: 8,
                                  border: "1px solid #DFC9E3",
                                  fontSize: 12.5,
                                }}
                              />
                            </div>
                            <div style={{ display: "flex", gap: 6, flexWrap: "wrap" }}>
                              <button
                                className="button button--primary"
                                type="button"
                                onClick={() => {
                                  setSelectedReportId(rep.id);
                                  setTriagePriority(rep.priority ?? "P2_NORMAL");
                                  setTriageSeverity(rep.severity ?? "S3_MEDIUM");
                                  setTriageAssignee(rep.assignedReviewerName ?? "");
                                  setTriageAppealStatus(rep.appealStatus ?? "");
                                  setTriageInternalNote("");
                                }}
                              >
                                <Eye size={13} /> Inspect Evidence &amp; Triage
                              </button>
                              <button
                                className="button button--secondary"
                                type="button"
                                onClick={() => void resolveReport(rep.id, "REMOVE_POST")}
                              >
                                Remove Post
                              </button>
                              <button
                                className="button button--secondary"
                                type="button"
                                onClick={() => void resolveReport(rep.id, "WARN_MEMBER")}
                              >
                                Warn
                              </button>
                              <button
                                className="button button--secondary"
                                type="button"
                                onClick={() => void resolveReport(rep.id, "SUSPEND_MEMBER")}
                              >
                                Suspend
                              </button>
                              <button
                                className="button button--secondary"
                                type="button"
                                onClick={() => void resolveReport(rep.id, "DISMISS_REPORT")}
                              >
                                Dismiss
                              </button>
                            </div>
                          </div>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          </section>

          {/* Report & Evidence Detail Drawer / Modal */}
          {selectedReport && (
            <section
              className="panel"
              role="dialog"
              aria-label="Report Evidence & Triage Detail"
              style={{
                marginBottom: 24,
                padding: 24,
                border: "2px solid #EC4899",
                background: "#FFFFFF",
                boxShadow: "0 16px 40px rgba(131, 24, 67, 0.12)",
              }}
            >
              <div
                style={{
                  display: "flex",
                  justifyContent: "space-between",
                  alignItems: "flex-start",
                  marginBottom: 16,
                }}
              >
                <div>
                  <span className="panel-kicker">REPORT &amp; EVIDENCE DETAIL DRAWER</span>
                  <h2 style={{ margin: "4px 0" }}>
                    Report #{selectedReport.id.slice(0, 8)} — Target: {selectedReport.targetHandle}
                  </h2>
                  <p style={{ margin: 0, color: "#6E6275", fontSize: 13 }}>
                    Category: <strong>{selectedReport.category ?? "SAFETY_CONCERN"}</strong> · Target Type:{" "}
                    <strong>{selectedReport.targetType ?? "POST"}</strong> · Repeat Reports on Target:{" "}
                    <strong>{selectedReport.repeatOffenderCount ?? 1}</strong>
                  </p>
                </div>
                <button
                  className="button button--secondary"
                  type="button"
                  onClick={() => setSelectedReportId(null)}
                >
                  <X size={15} /> Close Drawer
                </button>
              </div>

              <div
                style={{
                  display: "grid",
                  gridTemplateColumns: "repeat(auto-fit, minmax(300px, 1fr))",
                  gap: 20,
                }}
              >
                {/* Left Column: Reported Post, Photo/Video Evidence & Profile Context */}
                <div style={{ display: "flex", flexDirection: "column", gap: 14 }}>
                  <div
                    style={{
                      padding: 16,
                      borderRadius: 12,
                      background: "#FDF2F8",
                      border: "1px solid #FBCFE8",
                    }}
                  >
                    <h3 style={{ marginTop: 0, fontSize: 14, color: "#831843" }}>
                      1. Reported Content &amp; Media Evidence
                    </h3>
                    <p style={{ fontSize: 13, margin: "6px 0" }}>
                      <strong>Report Reason:</strong> {selectedReport.reason}
                    </p>
                    {selectedReport.details && (
                      <p style={{ fontSize: 13, margin: "6px 0", color: "#4B5563" }}>
                        <strong>Reporter Context:</strong> {selectedReport.details}
                      </p>
                    )}

                    {selectedReport.targetPost ? (
                      <div
                        style={{
                          marginTop: 10,
                          padding: 12,
                          borderRadius: 10,
                          background: "#FFFFFF",
                          border: "1px solid #F9A8D4",
                        }}
                      >
                        <div style={{ fontSize: 12, color: "#6B7280", marginBottom: 4 }}>
                          Post ID: <code>{selectedReport.targetPost.id}</code> · Author:{" "}
                          <strong>{selectedReport.targetPost.authorName}</strong> (
                          {selectedReport.targetPost.authorUsername}) · Status:{" "}
                          <strong>{selectedReport.targetPost.status}</strong>
                        </div>
                        <div style={{ fontSize: 13.5, color: "#111827", whiteSpace: "pre-wrap" }}>
                          {selectedReport.targetPost.content || "(No caption text — media post)"}
                        </div>
                        {selectedReport.targetPost.imageAsset && (
                          <div style={{ marginTop: 12 }}>
                            <div
                              style={{
                                fontSize: 12,
                                fontWeight: 700,
                                color: "#9D174D",
                                marginBottom: 6,
                              }}
                            >
                              Authorized Reported Image / Video Preview:
                            </div>
                            <AuthorizedMediaPreview
                              rawUrl={selectedReport.targetPost.imageAsset}
                              alt="Reported Post Evidence"
                              style={{
                                width: "100%",
                                maxHeight: 280,
                                objectFit: "contain",
                                borderRadius: 10,
                                background: "#F9FAFB",
                                border: "1px solid #E5E7EB",
                              }}
                            />
                          </div>
                        )}
                      </div>
                    ) : (
                      <div style={{ fontSize: 12.5, color: "#6B7280", marginTop: 8 }}>
                        No post linked or post was already purged.
                      </div>
                    )}

                    {selectedReport.targetComment && (
                      <div
                        style={{
                          marginTop: 10,
                          padding: 12,
                          borderRadius: 10,
                          background: "#FFFFFF",
                          border: "1px solid #DDD6FE",
                        }}
                      >
                        <div style={{ fontSize: 12, color: "#6D28D9", fontWeight: 700 }}>
                          Reported Comment by {selectedReport.targetComment.authorName}:
                        </div>
                        <div style={{ fontSize: 13, marginTop: 4 }}>
                          “{selectedReport.targetComment.content}”
                        </div>
                      </div>
                    )}
                  </div>

                  {selectedReport.targetProfile && (
                    <div
                      style={{
                        padding: 16,
                        borderRadius: 12,
                        background: "#F5F3FF",
                        border: "1px solid #DDD6FE",
                      }}
                    >
                      <h3 style={{ marginTop: 0, fontSize: 14, color: "#4C1D95" }}>
                        2. Reported Member Profile Context
                      </h3>
                      <div style={{ fontSize: 13 }}>
                        <strong>{selectedReport.targetProfile.displayName}</strong> (
                        {selectedReport.targetProfile.username})
                      </div>
                      <div style={{ fontSize: 12, color: "#6B7280", marginTop: 4 }}>
                        Account Status: <strong>{selectedReport.targetProfile.accountStatus}</strong> ·
                        Verification: <strong>{selectedReport.targetProfile.verificationStatus}</strong> ·
                        Location: {selectedReport.targetProfile.location || "Hidden"}
                      </div>
                      {selectedReport.targetProfile.bio && (
                        <div style={{ fontSize: 12.5, marginTop: 6, color: "#374151" }}>
                          Bio: {selectedReport.targetProfile.bio}
                        </div>
                      )}
                    </div>
                  )}
                </div>

                {/* Right Column: Triage Assignment, Internal Notes & Enforcement Actions */}
                <div style={{ display: "flex", flexDirection: "column", gap: 14 }}>
                  <div
                    style={{
                      padding: 16,
                      borderRadius: 12,
                      background: "#F9FAFB",
                      border: "1px solid #E5E7EB",
                    }}
                  >
                    <div
                      style={{
                        display: "flex",
                        justifyContent: "space-between",
                        alignItems: "center",
                        marginBottom: 10,
                      }}
                    >
                      <h3 style={{ margin: 0, fontSize: 14 }}>3. Triage, Priority &amp; Assignment</h3>
                      <button
                        className="button button--secondary"
                        type="button"
                        onClick={() => void saveReportTriage(selectedReport.id, true)}
                      >
                        <UserCheck size={13} /> Assign to Me
                      </button>
                    </div>

                    <div
                      style={{
                        display: "grid",
                        gridTemplateColumns: "1fr 1fr",
                        gap: 10,
                        marginBottom: 10,
                      }}
                    >
                      <label style={{ fontSize: 12 }}>
                        Priority
                        <select
                          value={triagePriority}
                          onChange={(e) => setTriagePriority(e.target.value)}
                          style={{
                            width: "100%",
                            padding: "6px 8px",
                            borderRadius: 8,
                            border: "1px solid #D1D5DB",
                            marginTop: 4,
                          }}
                        >
                          <option value="P0_CRITICAL">P0 — Critical Safety</option>
                          <option value="P1_HIGH">P1 — High Priority</option>
                          <option value="P2_NORMAL">P2 — Normal</option>
                          <option value="P3_LOW">P3 — Low</option>
                        </select>
                      </label>
                      <label style={{ fontSize: 12 }}>
                        Severity
                        <select
                          value={triageSeverity}
                          onChange={(e) => setTriageSeverity(e.target.value)}
                          style={{
                            width: "100%",
                            padding: "6px 8px",
                            borderRadius: 8,
                            border: "1px solid #D1D5DB",
                            marginTop: 4,
                          }}
                        >
                          <option value="S1_CRITICAL">S1 — Critical Harm</option>
                          <option value="S2_HIGH">S2 — Severe Violation</option>
                          <option value="S3_MEDIUM">S3 — Moderate</option>
                          <option value="S4_LOW">S4 — Minor</option>
                        </select>
                      </label>
                      <label style={{ fontSize: 12 }}>
                        Assigned Reviewer
                        <input
                          type="text"
                          value={triageAssignee}
                          onChange={(e) => setTriageAssignee(e.target.value)}
                          placeholder="Unassigned"
                          style={{
                            width: "100%",
                            padding: "6px 8px",
                            borderRadius: 8,
                            border: "1px solid #D1D5DB",
                            marginTop: 4,
                          }}
                        />
                      </label>
                      <label style={{ fontSize: 12 }}>
                        Appeal Status
                        <select
                          value={triageAppealStatus}
                          onChange={(e) => setTriageAppealStatus(e.target.value)}
                          style={{
                            width: "100%",
                            padding: "6px 8px",
                            borderRadius: 8,
                            border: "1px solid #D1D5DB",
                            marginTop: 4,
                          }}
                        >
                          <option value="">No Appeal</option>
                          <option value="APPEAL_PENDING">Appeal Pending Review</option>
                          <option value="APPEAL_UPHELD">Appeal Upheld (Action Kept)</option>
                          <option value="APPEAL_OVERTURNED">Appeal Granted (Restored)</option>
                        </select>
                      </label>
                    </div>

                    <label style={{ fontSize: 12, display: "block", marginBottom: 8 }}>
                      Add Internal Reviewer Note (Confidential)
                      <textarea
                        rows={2}
                        value={triageInternalNote}
                        onChange={(e) => setTriageInternalNote(e.target.value)}
                        placeholder="Record investigation findings or policy citations..."
                        style={{
                          width: "100%",
                          padding: "8px",
                          borderRadius: 8,
                          border: "1px solid #D1D5DB",
                          marginTop: 4,
                        }}
                      />
                    </label>
                    <button
                      className="button button--primary"
                      type="button"
                      onClick={() => void saveReportTriage(selectedReport.id, false)}
                    >
                      Save Triage &amp; Note
                    </button>

                    {(selectedReport.internalNotes?.length ?? 0) > 0 && (
                      <div style={{ marginTop: 12 }}>
                        <strong style={{ fontSize: 12 }}>Internal Notes History:</strong>
                        {selectedReport.internalNotes!.map((n) => (
                          <div
                            key={n.id}
                            style={{
                              fontSize: 12,
                              padding: "6px 8px",
                              background: "#FFFFFF",
                              borderRadius: 6,
                              border: "1px solid #E5E7EB",
                              marginTop: 4,
                            }}
                          >
                            <strong>{n.author}:</strong> {n.note}{" "}
                            <span style={{ color: "#9CA3AF" }}>
                              ({new Date(n.createdAt).toLocaleString("en-IN")})
                            </span>
                          </div>
                        ))}
                      </div>
                    )}
                  </div>

                  <div
                    style={{
                      padding: 16,
                      borderRadius: 12,
                      background: "#FFF1F2",
                      border: "1px solid #FECDD3",
                    }}
                  >
                    <h3 style={{ marginTop: 0, fontSize: 14, color: "#9F1239" }}>
                      4. Execute Moderation &amp; Enforcement Decision
                    </h3>
                    <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
                      <button
                        className="button button--primary"
                        type="button"
                        onClick={() => void resolveReport(selectedReport.id, "REMOVE_POST")}
                      >
                        Remove Post
                      </button>
                      <button
                        className="button button--secondary"
                        type="button"
                        onClick={() => void resolveReport(selectedReport.id, "RESTORE_CONTENT")}
                      >
                        Restore Content
                      </button>
                      <button
                        className="button button--secondary"
                        type="button"
                        onClick={() => void resolveReport(selectedReport.id, "WARN_MEMBER")}
                      >
                        Warn Member
                      </button>
                      <button
                        className="button button--secondary"
                        type="button"
                        onClick={() => void resolveReport(selectedReport.id, "RESTRICT_MEMBER")}
                      >
                        Restrict Member
                      </button>
                      <button
                        className="button button--secondary"
                        type="button"
                        onClick={() => void resolveReport(selectedReport.id, "SUSPEND_MEMBER")}
                      >
                        Suspend Account
                      </button>
                      <button
                        className="button button--secondary"
                        type="button"
                        onClick={() => void resolveReport(selectedReport.id, "ESCALATE")}
                      >
                        Escalate (P0)
                      </button>
                      <button
                        className="button button--secondary"
                        type="button"
                        onClick={() => void resolveReport(selectedReport.id, "DISMISS_REPORT")}
                      >
                        Dismiss (No Violation)
                      </button>
                    </div>
                  </div>
                </div>
              </div>
            </section>
          )}

          <section className="panel queue-panel" style={{ marginBottom: 20 }}>
            <div className="panel-heading">
              <div>
                <span className="panel-kicker">EMERGENCY TELEMETRY</span>
                <h2>SOS &amp; Safety Check-In Events ({data.sosEvents.length})</h2>
                <p>Live emergency dispatches and safety check-in records from Module 4.</p>
              </div>
              <Sparkles size={18} />
            </div>
            <div className="table-scroll">
              <table className="operations-table">
                <thead>
                  <tr>
                    <th>Event ID</th>
                    <th>Type</th>
                    <th>Status</th>
                    <th>Location</th>
                    <th>Recorded At</th>
                  </tr>
                </thead>
                <tbody>
                  {data.sosEvents.length === 0 && (
                    <tr>
                      <td colSpan={5} className="member-empty-cell">
                        No SOS events recorded yet.
                      </td>
                    </tr>
                  )}
                  {data.sosEvents.map((ev) => (
                    <tr key={ev.id}>
                      <td>
                        <code>{ev.id.slice(0, 8)}</code>
                      </td>
                      <td>{ev.eventType}</td>
                      <td>
                        <StatusPill tone={ev.status === "ACTIVE" ? "urgent" : "green"}>{ev.status}</StatusPill>
                      </td>
                      <td>{ev.locationLabel}</td>
                      <td>{new Date(ev.createdAt).toLocaleString("en-IN")}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </section>

          <section className="panel queue-panel">
            <div className="panel-heading">
              <div>
                <span className="panel-kicker">SECURITY &amp; GOVERNANCE</span>
                <h2>Platform Audit Trail ({data.auditEvents.length})</h2>
                <p>Immutable log of member and administrator security actions.</p>
              </div>
            </div>
            <div className="table-scroll">
              <table className="operations-table">
                <thead>
                  <tr>
                    <th>Actor</th>
                    <th>Action</th>
                    <th>Target</th>
                    <th>Outcome</th>
                    <th>Timestamp</th>
                  </tr>
                </thead>
                <tbody>
                  {data.auditEvents.map((audit) => (
                    <tr key={audit.id}>
                      <td>{audit.actorType}</td>
                      <td>
                        <code>{audit.action}</code>
                      </td>
                      <td>{audit.targetType}</td>
                      <td>
                        <StatusPill tone="green">{audit.outcome}</StatusPill>
                      </td>
                      <td>{new Date(audit.createdAt).toLocaleString("en-IN")}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </section>
        </>
      )}
    </div>
  );
}
