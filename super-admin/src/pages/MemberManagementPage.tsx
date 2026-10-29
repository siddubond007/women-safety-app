import { useCallback, useEffect, useRef, useState, type FormEvent } from "react";
import {
  AlertCircle,
  CheckCircle2,
  ChevronLeft,
  ChevronRight,
  Copy,
  Eye,
  EyeOff,
  RefreshCw,
  Search,
  ShieldCheck,
  Users,
  X,
} from "lucide-react";
import { Link, useNavigate } from "react-router-dom";
import { StatusPill } from "../components/StatusPill";
import { adminApi, AdminApiError } from "../services/api/adminApi";
import { adminAuthService } from "../services/auth/adminAuthService";

type AccountStatus =
  | "PENDING_VERIFICATION"
  | "ACTIVE"
  | "RESTRICTED"
  | "SUSPENDED"
  | "DELETED";
type VerificationStatus = "UNVERIFIED" | "VERIFIED" | "REJECTED";
type EligibilityStatus =
  | "UNVERIFIED"
  | "VERIFIED"
  | "REJECTED"
  | "PENDING_MANUAL_REVIEW"
  | "VERIFICATION_IN_PROGRESS"
  | "REVERIFICATION_REQUIRED"
  | "TEMPORARILY_RESTRICTED"
  | "APPROVED";

type Member = {
  id: string;
  reference: string;
  displayName: string;
  username?: string | null;
  dateOfBirth: string | null;
  ageYears?: number | null;
  email?: string;
  emailMasked: string;
  phoneMasked: string;
  phoneE164?: string;
  phoneFormatted?: string;
  bio?: string | null;
  locationCity?: string | null;
  interests?: string[];
  avatarAsset?: string | null;
  twoFactorEnabled?: boolean;
  registeredAt: string;
  lastActiveAt: string | null;
  accountStatus: AccountStatus;
  verificationStatus: VerificationStatus;
  eligibilityStatus: EligibilityStatus | string;
  profileComplete: boolean;
  eligibilitySubmissionId?: string | null;
  eligibilitySubmissionStatus: string | null;
  eligibilitySubmittedAt: string | null;
  eligibilityReviewedAt: string | null;
  reviewerLabel?: string | null;
  decisionReason?: string | null;
  consentVersion?: string | null;
  consentAcceptedAt?: string | null;
  counts?: {
    postsCount: number;
    commentsCount: number;
    emergencyContactsCount: number;
    sosEventsCount: number;
  };
};

type Member360Detail = Member & {
  consents?: Array<{
    id: string;
    termsVersion: string;
    privacyVersion: string;
    optionalUpdatesAccepted: boolean;
    acceptedAt: string;
  }>;
  eligibilitySubmissions?: Array<{
    id: string;
    status: string;
    consentVersion: string;
    submittedAt: string;
    reviewedAt: string | null;
    reviewerLabel: string | null;
    decisionReason: string | null;
  }>;
  counts?: {
    postsCount: number;
    commentsCount: number;
    emergencyContactsCount: number;
    sosEventsCount: number;
    reportsAgainstCount?: number;
    reportsSubmittedCount?: number;
  };
  posts?: Array<{
    id: string;
    content: string;
    imageAsset?: string | null;
    categoryBadge?: string | null;
    feedSection?: string;
    status: string;
    likesCount: number;
    commentsCount: number;
    createdAt: string;
  }>;
  reportsAgainstMember?: Array<{
    id: string;
    source: string;
    targetHandle: string;
    postId: string | null;
    reason: string;
    status: string;
    reviewerNotes: string | null;
    createdAt: string;
  }>;
  reportsByMember?: Array<{
    id: string;
    targetHandle: string;
    postId: string | null;
    reason: string;
    status: string;
    createdAt: string;
  }>;
  emergencyContacts?: Array<{
    id: string;
    name: string;
    relationship: string;
    phoneE164: string;
  }>;
  sosEvents?: Array<{
    id: string;
    eventType: string;
    status: string;
    locationLabel: string;
    createdAt: string;
  }>;
  auditEvents?: Array<{
    id: string;
    actorType: string;
    action: string;
    targetType: string;
    outcome: string;
    createdAt: string;
  }>;
};

type MemberDirectory = {
  total: number;
  page: number;
  pageSize: number;
  summary: {
    totalAccounts: number;
    activeAccounts: number;
    pendingAccounts: number;
    verifiedAccounts: number;
    rejectedAccounts: number;
    pendingManualReviews: number;
  };
  items: Member[];
};

const accountLabels: Record<AccountStatus, string> = {
  PENDING_VERIFICATION: "Pending",
  ACTIVE: "Active",
  RESTRICTED: "Restricted",
  SUSPENDED: "Suspended",
  DELETED: "Deleted",
};
const verificationLabels: Record<VerificationStatus, string> = {
  UNVERIFIED: "Unverified",
  VERIFIED: "Verified",
  REJECTED: "Rejected",
};
const eligibilityLabels: Record<string, string> = {
  UNVERIFIED: "Not Verified",
  VERIFIED: "Verified",
  REJECTED: "Rejected",
  PENDING_MANUAL_REVIEW: "Pending Manual Review",
  VERIFICATION_IN_PROGRESS: "Verification In Progress",
  REVERIFICATION_REQUIRED: "Reverification Required",
  TEMPORARILY_RESTRICTED: "Temporarily Restricted",
  APPROVED: "Approved (Verified)",
};

const accountTone = (
  status: AccountStatus,
): "green" | "amber" | "urgent" | "neutral" =>
  status === "ACTIVE"
    ? "green"
    : status === "PENDING_VERIFICATION"
      ? "amber"
      : status === "RESTRICTED" ||
          status === "SUSPENDED" ||
          status === "DELETED"
        ? "urgent"
        : "neutral";

const verificationTone = (
  status: VerificationStatus,
): "green" | "amber" | "urgent" =>
  status === "VERIFIED"
    ? "green"
    : status === "REJECTED"
      ? "urgent"
      : "amber";

const eligibilityTone = (
  status: string,
): "green" | "amber" | "urgent" | "neutral" =>
  status === "VERIFIED" || status === "APPROVED"
    ? "green"
    : status === "REJECTED"
      ? "urgent"
      : status === "UNVERIFIED"
        ? "neutral"
        : "amber";

const SHORT_DATE_FMT = new Intl.DateTimeFormat("en-IN", {
  day: "2-digit",
  month: "short",
  year: "numeric",
});

const DATE_TIME_FMT = new Intl.DateTimeFormat("en-IN", {
  day: "2-digit",
  month: "short",
  year: "numeric",
  hour: "2-digit",
  minute: "2-digit",
});

const formatDate = (value: string | null) => {
  if (!value) return "Never";
  const d = new Date(value);
  return Number.isNaN(d.getTime()) ? "Never" : SHORT_DATE_FMT.format(d);
};

const formatDateTime = (value: string) => {
  if (!value) return "Not available";
  const d = new Date(value);
  return Number.isNaN(d.getTime()) ? "Not available" : DATE_TIME_FMT.format(d);
};

const initials = (name: string) =>
  name
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0]?.toUpperCase() ?? "")
    .join("") || "SK";

export function MemberManagementPage({
  isStagingTest = false,
}: {
  isStagingTest?: boolean;
}) {
  const navigate = useNavigate();
  const [data, setData] = useState<MemberDirectory | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [searchDraft, setSearchDraft] = useState("");
  const [search, setSearch] = useState("");
  const [accountFilter, setAccountFilter] = useState("");
  const [verificationFilter, setVerificationFilter] = useState("");
  const [page, setPage] = useState(1);
  const [refresh, setRefresh] = useState(0);

  // Phone number visibility controls (Global + Per-Row)
  const [showAllPhones, setShowAllPhones] = useState(false);
  const [visibleRowIds, setVisibleRowIds] = useState<Record<string, boolean>>({});

  // Selected Member 360 Drawer state + fast in-memory 360 cache for 0ms drawer open
  const member360CacheRef = useRef<Record<string, Member360Detail>>({});
  const [selected, setSelected] = useState<Member | null>(null);
  const [detail360, setDetail360] = useState<Member360Detail | null>(null);
  const [loadingDetail, setLoadingDetail] = useState(false);
  const [accountStatus, setAccountStatus] = useState<AccountStatus>(
    "PENDING_VERIFICATION",
  );
  const [verificationStatus, setVerificationStatus] =
    useState<VerificationStatus>("UNVERIFIED");
  const [selectedPreset, setSelectedPreset] = useState<string>("VERIFIED");
  const [reason, setReason] = useState(
    "Admin eligibility and account status override via Super Admin panel.",
  );
  const [saving, setSaving] = useState(false);
  const [quickSavingId, setQuickSavingId] = useState<string | null>(null);
  const [actionError, setActionError] = useState("");
  const [notice, setNotice] = useState("");

  const load = useCallback(async () => {
    setLoading(true);
    setError("");
    try {
      const params = new URLSearchParams({
        page: String(page),
        pageSize: "25",
      });
      if (search) params.set("search", search);
      if (accountFilter) params.set("accountStatus", accountFilter);
      if (verificationFilter)
        params.set("verificationStatus", verificationFilter);
      const result = await adminApi<MemberDirectory>(
        "/admin-review/members?" + params.toString(),
      );
      setData(result);
    } catch (cause) {
      if (cause instanceof AdminApiError && cause.statusCode === 401) {
        adminAuthService.signOut();
        navigate("/login", { replace: true });
        return;
      }
      setError(
        cause instanceof Error
          ? cause.message
          : "The member directory could not be loaded.",
      );
    } finally {
      setLoading(false);
    }
  }, [page, search, accountFilter, verificationFilter, navigate]);

  useEffect(() => {
    let active = true;
    void Promise.resolve().then(() => {
      if (active) void load();
    });
    return () => {
      active = false;
    };
  }, [load, refresh]);

  async function openEditor(member: Member) {
    const cached = member360CacheRef.current[member.id];
    setSelected(member);
    setDetail360(cached ?? member);
    setAccountStatus(member.accountStatus);
    setVerificationStatus(member.verificationStatus);
    setSelectedPreset(
      member.verificationStatus === "VERIFIED"
        ? "VERIFIED"
        : member.verificationStatus === "REJECTED"
          ? "REJECTED"
          : "PENDING_MANUAL_REVIEW",
    );
    setReason(
      "Admin eligibility and account status override via Super Admin panel.",
    );
    setActionError("");
    setLoadingDetail(!cached);
    try {
      const full = await adminApi<Member360Detail>(
        "/admin-review/members/" + encodeURIComponent(member.id),
      );
      member360CacheRef.current[member.id] = full;
      setDetail360(full);
    } catch {
      // Keep base member fields if 360 endpoint is still deploying
    } finally {
      setLoadingDetail(false);
    }
  }

  function toggleRowPhone(id: string) {
    setVisibleRowIds((prev) => ({
      ...prev,
      [id]: !(prev[id] ?? showAllPhones),
    }));
  }

  function isPhoneVisible(id: string): boolean {
    if (id in visibleRowIds) return visibleRowIds[id]!;
    return showAllPhones;
  }

  function copyPhone(phone: string) {
    void navigator.clipboard?.writeText(phone);
    setNotice(`Copied mobile number ${phone} to clipboard.`);
  }

  async function applyQuickPreset(
    member: Member,
    preset:
      | "VERIFIED"
      | "PENDING_MANUAL_REVIEW"
      | "VERIFICATION_IN_PROGRESS"
      | "INCOMPLETE"
      | "REVERIFICATION_REQUIRED"
      | "TEMPORARILY_RESTRICTED"
      | "REJECTED",
  ) {
    setQuickSavingId(member.id);
    setSaving(true);
    setError("");
    setActionError("");
    const nextAccountStatus: AccountStatus =
      preset === "VERIFIED"
        ? "ACTIVE"
        : preset === "TEMPORARILY_RESTRICTED"
          ? "RESTRICTED"
          : "PENDING_VERIFICATION";
    const nextVerificationStatus: VerificationStatus =
      preset === "VERIFIED"
        ? "VERIFIED"
        : preset === "REJECTED"
          ? "REJECTED"
          : "UNVERIFIED";

    try {
      try {
        await adminApi(
          "/admin-review/members/" +
            encodeURIComponent(member.id) +
            "/eligibility-override",
          {
            method: "PATCH",
            body: {
              preset,
              accountStatus: nextAccountStatus,
              verificationStatus: nextVerificationStatus,
              reason:
                reason.trim().length >= 10
                  ? reason.trim()
                  : `Admin set ${member.displayName} to ${preset} from Super Admin portal.`,
            },
          },
        );
      } catch {
        // Fallback to /state with allowStagingOverride: true
        await adminApi(
          "/admin-review/members/" + encodeURIComponent(member.id) + "/state",
          {
            method: "PATCH",
            body: {
              accountStatus: nextAccountStatus,
              verificationStatus: nextVerificationStatus,
              allowStagingOverride: true,
              reason:
                reason.trim().length >= 10
                  ? reason.trim()
                  : `Admin set ${member.displayName} to ${preset} from Super Admin portal.`,
            },
          },
        );
      }

      setAccountStatus(nextAccountStatus);
      setVerificationStatus(nextVerificationStatus);
      setSelectedPreset(preset);
      setNotice(
        preset === "VERIFIED"
          ? `✅ Verified & Activated ${member.displayName} (${member.phoneFormatted ?? member.phoneE164 ?? member.phoneMasked})! They now have full Sakhi Home & Community access.`
          : `Updated ${member.displayName} to ${preset} (${nextAccountStatus} / ${nextVerificationStatus}).`,
      );
      await load();
      if (selected && selected.id === member.id) {
        const refreshed = await adminApi<Member360Detail>(
          "/admin-review/members/" + encodeURIComponent(member.id),
        ).catch(() => null);
        if (refreshed) setDetail360(refreshed);
      }
    } catch (cause) {
      if (cause instanceof AdminApiError && cause.statusCode === 401) {
        adminAuthService.signOut();
        navigate("/login", { replace: true });
        return;
      }
      const msg =
        cause instanceof Error
          ? cause.message
          : "Could not update member verification state.";
      setError(msg);
      setActionError(msg);
    } finally {
      setQuickSavingId(null);
      setSaving(false);
    }
  }

  async function saveState(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!selected) return;
    const safeReason =
      reason.trim().length >= 10
        ? reason.trim()
        : "Updated account and eligibility status via Super Admin 360 profile drawer.";
    setSaving(true);
    setActionError("");
    try {
      try {
        await adminApi(
          "/admin-review/members/" +
            encodeURIComponent(selected.id) +
            "/eligibility-override",
          {
            method: "PATCH",
            body: {
              preset: selectedPreset,
              accountStatus,
              verificationStatus,
              reason: safeReason,
            },
          },
        );
      } catch {
        await adminApi(
          "/admin-review/members/" + encodeURIComponent(selected.id) + "/state",
          {
            method: "PATCH",
            body: {
              accountStatus,
              verificationStatus,
              allowStagingOverride: true,
              reason: safeReason,
            },
          },
        );
      }
      setNotice(
        `Saved state (${accountStatus} / ${verificationStatus}) for ${selected.displayName}. Tap "Check account state again" in the mobile app!`,
      );
      setSelected(null);
      await load();
    } catch (cause) {
      if (cause instanceof AdminApiError && cause.statusCode === 401) {
        adminAuthService.signOut();
        navigate("/login", { replace: true });
        return;
      }
      setActionError(
        cause instanceof Error
          ? cause.message
          : "The state change was not saved.",
      );
    } finally {
      setSaving(false);
    }
  }

  const summary = data?.summary;
  const totalPages = data
    ? Math.max(1, Math.ceil(data.total / data.pageSize))
    : 1;
  const activeDetail = (detail360 ?? selected) as any;

  return (
    <div className="members-page">
      <div className="members-breadcrumb">
        <Link to="/dashboard">Overview dashboard</Link>
        <span>/</span>
        <strong>Members &amp; accounts</strong>
      </div>
      <section className="page-heading members-page-heading">
        <div>
          <div className="eyebrow">
            <span className="eyebrow-line" /> PEOPLE &amp; TRUST • MODULE 1 &amp; ADMIN 360° CONTROL
          </div>
          <h1>Members, Phone Numbers &amp; Eligibility Control</h1>
          <p>
            View all registered users, inspect their full mobile numbers and 360° profile details, and change any user’s eligibility or verification status (Verified, Pending, Incomplete, Restricted, or Rejected) at any stage—even while Decentro DigiLocker KYC is pending.
          </p>
        </div>
        <div className="members-heading-meta" style={{ display: "flex", gap: 10, flexWrap: "wrap" }}>
          <StatusPill tone="green">
            <span className="status-pill__dot" /> LIVE POSTGRESQL
          </StatusPill>
          <button
            type="button"
            className="button button--secondary"
            onClick={() => {
              setShowAllPhones((prev) => !prev);
              setVisibleRowIds({});
            }}
          >
            {showAllPhones ? <EyeOff size={15} /> : <Eye size={15} />}
            {showAllPhones ? "Mask Mobile Numbers" : "Show All Mobile Numbers"}
          </button>
        </div>
      </section>

      {notice && (
        <div className="member-toast" role="status">
          <CheckCircle2 size={17} />
          <span>{notice}</span>
          <button className="button button--secondary"
            type="button"
            onClick={() => setNotice("")}
            aria-label="Dismiss notice"
          >
            <X size={15} />
          </button>
        </div>
      )}
      {error && (
        <div className="admin-error-banner" role="alert">
          <AlertCircle size={17} />
          <span>{error}</span>
          <button
            type="button"
            className="button button--secondary"
            onClick={() => setRefresh((value) => value + 1)}
          >
            Retry
          </button>
        </div>
      )}

      <section className="member-summary" aria-label="Live database summary">
        <SummaryCard
          icon={Users}
          label="Total registered users"
          value={summary?.totalAccounts}
          tone="rose"
        />
        <SummaryCard
          icon={CheckCircle2}
          label="Active accounts"
          value={summary?.activeAccounts}
          tone="green"
        />
        <SummaryCard
          icon={ShieldCheck}
          label="Verified female members"
          value={summary?.verifiedAccounts}
          tone="violet"
        />
        <SummaryCard
          icon={AlertCircle}
          label="Pending / Unverified users"
          value={
            summary
              ? (summary.pendingAccounts ?? 0) +
                (summary.pendingManualReviews ?? 0)
              : undefined
          }
          tone="amber"
        />
      </section>

      <section className="panel member-directory-panel">
        <div className="member-directory-heading">
          <div>
            <span className="panel-kicker">ALL REGISTERED USERS (CLICK ANY USER FOR 360° PROFILE &amp; STATUS OVERRIDE)</span>
            <h2>Member directory</h2>
            <p>
              {data
                ? `Showing ${data.items.length} of ${data.total} registered members`
                : "Loading database records…"}
            </p>
          </div>
          <div style={{ display: "flex", gap: 8 }}>
            <button
              className="button button--secondary"
              type="button"
              onClick={() => setShowAllPhones((prev) => !prev)}
            >
              {showAllPhones ? <EyeOff size={14} /> : <Eye size={14} />}
              {showAllPhones ? "Hide Numbers" : "See All Numbers"}
            </button>
            <button
              className="button button--secondary"
              type="button"
              onClick={() => setRefresh((value) => value + 1)}
              disabled={loading}
            >
              <RefreshCw size={14} /> Refresh
            </button>
          </div>
        </div>

        <form
          className="member-filter-toolbar member-directory-filter-toolbar"
          onSubmit={(event) => {
            event.preventDefault();
            setPage(1);
            setSearch(searchDraft.trim());
          }}
        >
          <label className="member-search-field">
            <Search size={15} />
            <input
              type="search"
              value={searchDraft}
              onChange={(event) => setSearchDraft(event.target.value)}
              placeholder="Search name, +91 mobile number, email, or ID"
              aria-label="Search members"
            />
          </label>
          <label className="member-filter-select">
            <span>Account state</span>
            <select
              value={accountFilter}
              onChange={(event) => {
                setPage(1);
                setAccountFilter(event.target.value);
              }}
            >
              <option value="">All accounts</option>
              <option value="PENDING_VERIFICATION">Pending</option>
              <option value="ACTIVE">Active</option>
              <option value="RESTRICTED">Restricted</option>
              <option value="SUSPENDED">Suspended</option>
              <option value="DELETED">Deleted</option>
            </select>
          </label>
          <label className="member-filter-select">
            <span>Verification</span>
            <select
              value={verificationFilter}
              onChange={(event) => {
                setPage(1);
                setVerificationFilter(event.target.value);
              }}
            >
              <option value="">All verification states</option>
              <option value="UNVERIFIED">Unverified / Pending</option>
              <option value="VERIFIED">Verified</option>
              <option value="REJECTED">Rejected</option>
            </select>
          </label>
          <button className="button button--primary" type="submit">
            <Search size={14} /> Search
          </button>
        </form>

        <div className="member-table-scroll">
          <table className="member-table">
            <thead>
              <tr>
                <th>Member (Click for Full Profile)</th>
                <th>Mobile Number (+91)</th>
                <th>DOB &amp; Email</th>
                <th>Account</th>
                <th>Verification</th>
                <th>Eligibility Status</th>
                <th>Instant Admin Actions</th>
              </tr>
            </thead>
            <tbody>
              {loading && (
                <tr>
                  <td colSpan={7} className="member-empty-cell">
                    Loading records from the database…
                  </td>
                </tr>
              )}
              {!loading && !error && data?.items.length === 0 && (
                <tr>
                  <td colSpan={7} className="member-empty-cell">
                    No database records matched these filters.
                  </td>
                </tr>
              )}
              {!loading &&
                data?.items.map((member) => {
                  const isVerifiedActive =
                    member.accountStatus === "ACTIVE" &&
                    member.verificationStatus === "VERIFIED";
                  const phoneVisible = isPhoneVisible(member.id);
                  const fullPhone =
                    member.phoneFormatted ??
                    member.phoneE164 ??
                    member.phoneMasked;
                  return (
                    <tr key={member.id}>
                      <td>
                        <button
                          className="member-identity-button"
                          type="button"
                          onClick={() => void openEditor(member)}
                          title="Click to inspect full profile & change status"
                        >
                          <span className="member-avatar">
                            {initials(member.displayName)}
                          </span>
                          <span className="member-identity-copy">
                            <strong>{member.displayName}</strong>
                            <small>
                              {member.reference}
                              {member.locationCity
                                ? ` · ${member.locationCity}`
                                : ""}
                            </small>
                          </span>
                        </button>
                      </td>
                      <td>
                        <div
                          style={{
                            display: "flex",
                            alignItems: "center",
                            gap: 6,
                          }}
                        >
                          <strong style={{ fontFamily: "monospace", fontSize: 13.5 }}>
                            {phoneVisible ? fullPhone : member.phoneMasked}
                          </strong>
                          <button
                            type="button"
                            className="icon-button"
                            style={{ width: 26, height: 26 }}
                            onClick={() => toggleRowPhone(member.id)}
                            title={
                              phoneVisible
                                ? "Hide mobile number"
                                : "Show full mobile number"
                            }
                          >
                            {phoneVisible ? (
                              <EyeOff size={13} />
                            ) : (
                              <Eye size={13} />
                            )}
                          </button>
                          {member.phoneE164 && (
                            <button
                              type="button"
                              className="icon-button"
                              style={{ width: 26, height: 26 }}
                              onClick={() => copyPhone(member.phoneE164!)}
                              title="Copy phone number"
                            >
                              <Copy size={13} />
                            </button>
                          )}
                        </div>
                      </td>
                      <td>
                        <div>
                          <strong>
                            {member.dateOfBirth ?? "DOB not set"}
                            {member.ageYears != null
                              ? ` (${member.ageYears} yrs)`
                              : ""}
                          </strong>
                          <small className="member-subline">
                            {phoneVisible
                              ? (member.email ?? member.emailMasked)
                              : member.emailMasked}
                          </small>
                        </div>
                      </td>
                      <td>
                        <StatusPill tone={accountTone(member.accountStatus)}>
                          {accountLabels[member.accountStatus]}
                        </StatusPill>
                      </td>
                      <td>
                        <StatusPill
                          tone={verificationTone(member.verificationStatus)}
                        >
                          {verificationLabels[member.verificationStatus]}
                        </StatusPill>
                      </td>
                      <td>
                        <StatusPill
                          tone={eligibilityTone(String(member.eligibilityStatus))}
                        >
                          {eligibilityLabels[String(member.eligibilityStatus)] ??
                            member.eligibilityStatus}
                        </StatusPill>
                        <small className="member-subline">
                          {member.eligibilitySubmittedAt
                            ? "Submitted " +
                              formatDate(member.eligibilitySubmittedAt)
                            : member.profileComplete
                              ? "Registered · Ready for override"
                              : "Profile incomplete"}
                        </small>
                      </td>
                      <td>
                        <div
                          style={{
                            display: "flex",
                            gap: "6px",
                            flexWrap: "wrap",
                          }}
                        >
                          <button
                            className={
                              isVerifiedActive
                                ? "button button--secondary"
                                : "button button--primary"
                            }
                            type="button"
                            disabled={quickSavingId === member.id}
                            onClick={() =>
                              void applyQuickPreset(
                                member,
                                isVerifiedActive
                                  ? "PENDING_MANUAL_REVIEW"
                                  : "VERIFIED",
                              )
                            }
                          >
                            {quickSavingId === member.id
                              ? "Saving…"
                              : isVerifiedActive
                                ? "Set Pending"
                                : "Verify & Activate"}
                          </button>
                          <button
                            className="button button--secondary"
                            type="button"
                            onClick={() => void openEditor(member)}
                          >
                            Full Profile &amp; Status
                          </button>
                        </div>
                      </td>
                    </tr>
                  );
                })}
            </tbody>
          </table>
        </div>

        <div className="member-pagination">
          <span>
            Page {data?.page ?? page} of {totalPages}
          </span>
          <div>
            <button
              className="button button--secondary"
              type="button"
              disabled={loading || page <= 1}
              onClick={() => setPage((value) => Math.max(1, value - 1))}
            >
              <ChevronLeft size={14} /> Previous
            </button>
            <button
              className="button button--secondary"
              type="button"
              disabled={loading || page >= totalPages}
              onClick={() =>
                setPage((value) => Math.min(totalPages, value + 1))
              }
            >
              Next <ChevronRight size={14} />
            </button>
          </div>
        </div>
      </section>

      {/* Full 360° Member Profile Inspector & Instant Eligibility Override Drawer */}
      {selected && activeDetail && (
        <div
          className="member-drawer-overlay"
          role="presentation"
          onMouseDown={(event) => {
            if (event.target === event.currentTarget && !saving)
              setSelected(null);
          }}
        >
          <aside
            className="member-detail-drawer"
            role="dialog"
            aria-modal="true"
            aria-labelledby="state-editor-title"
          >
            <header className="member-drawer-header">
              <div>
                <span className="panel-kicker">
                  MEMBER 360° PROFILE &amp; ELIGIBILITY CONTROL
                </span>
                <span className="member-drawer-ref">
                  {activeDetail.reference}
                  {isStagingTest ? " · STAGING" : ""}
                </span>
              </div>
              <button
                className="member-drawer-close"
                type="button"
                onClick={() => setSelected(null)}
                aria-label="Close profile inspector"
                disabled={saving}
              >
                <X size={19} />
              </button>
            </header>

            <form
              id="member-state-form"
              onSubmit={saveState}
              className="member-drawer-form"
            >
              <div className="member-drawer-scroll">
                <div className="member-detail-profile">
                  <span className="member-avatar member-avatar--large">
                    {initials(activeDetail.displayName)}
                  </span>
                  <h2 id="state-editor-title">{activeDetail.displayName}</h2>
                  <p style={{ fontWeight: 700, color: "#5A1868" }}>
                    {activeDetail.phoneFormatted ??
                      activeDetail.phoneE164 ??
                      activeDetail.phoneMasked}{" "}
                    · {activeDetail.email ?? activeDetail.emailMasked}
                  </p>
                  <div style={{ display: "flex", gap: 8, justifyContent: "center", flexWrap: "wrap" }}>
                    <StatusPill
                      tone={activeDetail.profileComplete ? "green" : "amber"}
                    >
                      {activeDetail.profileComplete
                        ? "Profile complete"
                        : "Profile incomplete"}
                    </StatusPill>
                    <StatusPill
                      tone={verificationTone(activeDetail.verificationStatus)}
                    >
                      {(verificationLabels as Record<string, string>)[activeDetail.verificationStatus] ?? activeDetail.verificationStatus}
                    </StatusPill>
                  </div>
                </div>

                {/* Instant One-Click Eligibility Override Buttons (SRS Section 3.3) */}
                <section className="member-detail-section">
                  <h3>One-Click Eligibility Status Override (SRS Section 3.3)</h3>
                  <p className="member-section-description" style={{ marginBottom: 10 }}>
                    Even if Decentro DigiLocker KYC is pending or not yet started, click any status below to immediately update this user’s eligibility in PostgreSQL:
                  </p>
                  <div
                    style={{
                      display: "grid",
                      gridTemplateColumns: "1fr 1fr",
                      gap: 8,
                    }}
                  >
                    <button
                      type="button"
                      className="button button--primary"
                      disabled={saving}
                      onClick={() => void applyQuickPreset(selected, "VERIFIED")}
                    >
                      ✅ Verified (Unlock App)
                    </button>
                    <button
                      type="button"
                      className="button button--secondary"
                      disabled={saving}
                      onClick={() =>
                        void applyQuickPreset(selected, "PENDING_MANUAL_REVIEW")
                      }
                    >
                      ⏳ Pending Manual Review
                    </button>
                    <button
                      type="button"
                      className="button button--secondary"
                      disabled={saving}
                      onClick={() =>
                        void applyQuickPreset(
                          selected,
                          "VERIFICATION_IN_PROGRESS",
                        )
                      }
                    >
                      🔄 Verification In Progress
                    </button>
                    <button
                      type="button"
                      className="button button--secondary"
                      disabled={saving}
                      onClick={() =>
                        void applyQuickPreset(selected, "INCOMPLETE")
                      }
                    >
                      📝 Incomplete / Unverified
                    </button>
                    <button
                      type="button"
                      className="button button--secondary"
                      disabled={saving}
                      onClick={() =>
                        void applyQuickPreset(
                          selected,
                          "REVERIFICATION_REQUIRED",
                        )
                      }
                    >
                      🔁 Reverification Required
                    </button>
                    <button
                      type="button"
                      className="button button--secondary"
                      disabled={saving}
                      onClick={() =>
                        void applyQuickPreset(selected, "TEMPORARILY_RESTRICTED")
                      }
                    >
                      ⚠️ Temporarily Restricted
                    </button>
                    <button
                      type="button"
                      className="button button--secondary"
                      style={{ gridColumn: "1 / -1", color: "#C92A49" }}
                      disabled={saving}
                      onClick={() => void applyQuickPreset(selected, "REJECTED")}
                    >
                      ❌ Reject Eligibility (Verification Failed)
                    </button>
                  </div>
                </section>

                {/* Complete Registration & Profile Details */}
                <section className="member-detail-section">
                  <h3>Complete Member Profile &amp; Registration Details</h3>
                  {loadingDetail && (
                    <p style={{ fontSize: 12, color: "#6E6275" }}>
                      Loading extended 360° telemetry…
                    </p>
                  )}
                  <dl className="member-detail-list">
                    <div>
                      <dt>Full Mobile Number</dt>
                      <dd>
                        <strong>
                          {activeDetail.phoneFormatted ??
                            activeDetail.phoneE164 ??
                            activeDetail.phoneMasked}
                        </strong>
                      </dd>
                    </div>
                    <div>
                      <dt>Full Email Address</dt>
                      <dd>{activeDetail.email ?? activeDetail.emailMasked}</dd>
                    </div>
                    <div>
                      <dt>Date of Birth &amp; Age</dt>
                      <dd>
                        {activeDetail.dateOfBirth ?? "Not provided"}
                        {activeDetail.ageYears != null
                          ? ` (${activeDetail.ageYears} years old)`
                          : ""}
                      </dd>
                    </div>
                    <div>
                      <dt>City / Location</dt>
                      <dd>{activeDetail.locationCity ?? "Not specified"}</dd>
                    </div>
                    <div>
                      <dt>Bio</dt>
                      <dd>{activeDetail.bio ?? "No bio added yet"}</dd>
                    </div>
                    <div>
                      <dt>Interests</dt>
                      <dd>
                        {activeDetail.interests &&
                        activeDetail.interests.length > 0
                          ? activeDetail.interests.join(", ")
                          : "None selected"}
                      </dd>
                    </div>
                    <div>
                      <dt>Registered At</dt>
                      <dd>{formatDateTime(activeDetail.registeredAt)}</dd>
                    </div>
                    <div>
                      <dt>Last Active Session</dt>
                      <dd>
                        {activeDetail.lastActiveAt
                          ? formatDateTime(activeDetail.lastActiveAt)
                          : "No recent activity"}
                      </dd>
                    </div>
                    <div>
                      <dt>Terms &amp; Privacy Consent</dt>
                      <dd>
                        {activeDetail.consentVersion ?? "Accepted"}
                        {activeDetail.consentAcceptedAt
                          ? ` (${formatDateTime(activeDetail.consentAcceptedAt)})`
                          : ""}
                      </dd>
                    </div>
                    {activeDetail.counts && (
                      <div>
                        <dt>Platform Activity</dt>
                        <dd>
                          {activeDetail.counts.postsCount} Posts ·{" "}
                          {activeDetail.counts.commentsCount} Comments ·{" "}
                          {activeDetail.counts.emergencyContactsCount} Emergency
                          Contacts · {activeDetail.counts.sosEventsCount} SOS
                          Events ·{" "}
                          {activeDetail.counts.reportsAgainstCount ??
                            detail360?.reportsAgainstMember?.length ??
                            0}{" "}
                          Reports Against
                        </dd>
                      </div>
                    )}
                    <div>
                      <dt>Username Handle</dt>
                      <dd>
                        <strong>{activeDetail.username ?? "Auto-assigned"}</strong>
                      </dd>
                    </div>
                    <div>
                      <dt>Account UUID</dt>
                      <dd style={{ overflowWrap: "anywhere", fontSize: 11.5 }}>
                        {activeDetail.id}
                      </dd>
                    </div>
                  </dl>
                  <div style={{ marginTop: 12 }}>
                    <button
                      type="button"
                      className="secondary-button"
                      onClick={() => {
                        try {
                          window.localStorage.setItem(
                            "sakhi_admin_publisher_account_id",
                            activeDetail.id,
                          );
                        } catch {
                          // Ignore storage errors
                        }
                        setNotice(
                          `Linked ${activeDetail.displayName} (${activeDetail.username ?? activeDetail.reference}) as the Official Admin Publisher account for Community announcements!`,
                        );
                      }}
                    >
                      ✨ Set as Official Admin Post Publisher Account
                    </button>
                  </div>
                </section>

                {/* Member's Created Community Posts (Flaw 26 Fix) */}
                <section className="member-detail-section">
                  <h3>
                    Member’s Community Posts ({detail360?.posts?.length ?? 0})
                  </h3>
                  {(detail360?.posts ?? []).length === 0 ? (
                    <p
                      className="member-section-description"
                      style={{ margin: 0 }}
                    >
                      No community posts published by this member yet.
                    </p>
                  ) : (
                    <div
                      style={{
                        display: "grid",
                        gap: 10,
                        marginTop: 8,
                        maxHeight: 260,
                        overflowY: "auto",
                      }}
                    >
                      {(detail360?.posts ?? []).map((post) => (
                        <div
                          key={post.id}
                          style={{
                            padding: 12,
                            borderRadius: 12,
                            background: "#faf5fb",
                            border: "1px solid #ead8e8",
                            fontSize: 12.5,
                          }}
                        >
                          <div
                            style={{
                              display: "flex",
                              justifyContent: "space-between",
                              alignItems: "center",
                              gap: 8,
                              marginBottom: 6,
                            }}
                          >
                            <strong>
                              {post.categoryBadge ||
                                post.feedSection ||
                                "Community"}
                            </strong>
                            <StatusPill
                              tone={
                                post.status === "REMOVED_BY_MODERATOR"
                                  ? "urgent"
                                  : "green"
                              }
                            >
                              {post.status.replace(/_/g, " ")}
                            </StatusPill>
                          </div>
                          <p
                            style={{
                              margin: "0 0 6px 0",
                              color: "#36253d",
                              lineHeight: 1.45,
                            }}
                          >
                            {post.content}
                          </p>
                          <div
                            style={{
                              display: "flex",
                              justifyContent: "space-between",
                              color: "#7c6b83",
                              fontSize: 11.5,
                            }}
                          >
                            <span>
                              {post.likesCount} reactions · {post.commentsCount}{" "}
                              comments
                            </span>
                            <span>{formatDateTime(post.createdAt)}</span>
                          </div>
                        </div>
                      ))}
                    </div>
                  )}
                </section>

                {/* Reports & Complaints Filed Against Member (Flaw 26 Fix) */}
                <section className="member-detail-section">
                  <h3>
                    Reports &amp; Complaints Against Member (
                    {detail360?.reportsAgainstMember?.length ?? 0})
                  </h3>
                  {(detail360?.reportsAgainstMember ?? []).length === 0 ? (
                    <p
                      className="member-section-description"
                      style={{ margin: 0 }}
                    >
                      Clean trust record — 0 reports or complaints filed against
                      this member.
                    </p>
                  ) : (
                    <div style={{ display: "grid", gap: 8, marginTop: 8 }}>
                      {(detail360?.reportsAgainstMember ?? []).map((rep) => (
                        <div
                          key={rep.id}
                          style={{
                            padding: 11,
                            borderRadius: 11,
                            background: "#fff5f7",
                            border: "1px solid #f0cdd6",
                            fontSize: 12.5,
                          }}
                        >
                          <div
                            style={{
                              display: "flex",
                              justifyContent: "space-between",
                              gap: 8,
                            }}
                          >
                            <strong>
                              {rep.source.replace(/_/g, " ")} ·{" "}
                              {rep.targetHandle}
                            </strong>
                            <StatusPill tone="urgent">{rep.status}</StatusPill>
                          </div>
                          <p style={{ margin: "4px 0", color: "#4a2533" }}>
                            {rep.reason}
                          </p>
                          <small style={{ color: "#8a6878" }}>
                            Filed {formatDateTime(rep.createdAt)}
                          </small>
                        </div>
                      ))}
                    </div>
                  )}
                </section>

                {/* Reports Submitted By Member */}
                {(detail360?.reportsByMember ?? []).length > 0 && (
                  <section className="member-detail-section">
                    <h3>
                      Reports Submitted By Member (
                      {detail360?.reportsByMember?.length ?? 0})
                    </h3>
                    <div style={{ display: "grid", gap: 8, marginTop: 8 }}>
                      {(detail360?.reportsByMember ?? []).map((rep) => (
                        <div
                          key={rep.id}
                          style={{
                            padding: 10,
                            borderRadius: 10,
                            background: "#fdfafd",
                            border: "1px solid #eee2f0",
                            fontSize: 12,
                          }}
                        >
                          <strong>Target: {rep.targetHandle}</strong> ·{" "}
                          {rep.reason} ({rep.status})
                        </div>
                      ))}
                    </div>
                  </section>
                )}

                {/* Custom State Dropdown Editor */}
                <section className="member-detail-section">
                  <h3>Custom Account &amp; Verification State Form</h3>
                  <label className="member-filter-select">
                    <span>Account status</span>
                    <select
                      value={accountStatus}
                      onChange={(event) =>
                        setAccountStatus(event.target.value as AccountStatus)
                      }
                    >
                      <option value="PENDING_VERIFICATION">
                        Pending verification
                      </option>
                      <option value="ACTIVE">Active (Unlocked)</option>
                      <option value="RESTRICTED">Temporarily Restricted</option>
                      <option value="SUSPENDED">Suspended</option>
                      <option value="DELETED">Deleted</option>
                    </select>
                  </label>
                  <label className="member-filter-select">
                    <span>Verification / Eligibility status</span>
                    <select
                      value={verificationStatus}
                      onChange={(event) =>
                        setVerificationStatus(
                          event.target.value as VerificationStatus,
                        )
                      }
                    >
                      <option value="UNVERIFIED">
                        Unverified / Pending / Incomplete
                      </option>
                      <option value="VERIFIED">
                        Verified (Female Eligibility Confirmed)
                      </option>
                      <option value="REJECTED">
                        Rejected / Verification Failed
                      </option>
                    </select>
                  </label>
                  <label className="member-filter-select">
                    <span>Reason for audit log</span>
                    <textarea
                      minLength={10}
                      maxLength={500}
                      required
                      value={reason}
                      onChange={(event) => setReason(event.target.value)}
                      placeholder="Explain why this account state is being updated."
                      rows={2}
                    />
                  </label>
                  {actionError && (
                    <div className="admin-error-banner" role="alert">
                      <AlertCircle size={16} />
                      <span>{actionError}</span>
                    </div>
                  )}
                </section>
              </div>
            </form>

            <footer className="member-drawer-footer">
              <button
                className="button button--secondary"
                type="button"
                onClick={() => setSelected(null)}
                disabled={saving}
              >
                Close
              </button>
              <button
                className="button button--primary"
                type="submit"
                form="member-state-form"
                disabled={saving}
              >
                {saving ? "Saving…" : "Save Database State"}
              </button>
            </footer>
          </aside>
        </div>
      )}
    </div>
  );
}

function SummaryCard({
  icon: Icon,
  label,
  value,
  tone,
}: {
  icon: typeof Users;
  label: string;
  value?: number;
  tone: "rose" | "green" | "amber" | "violet";
}) {
  return (
    <article className={"member-summary-card member-summary-card--" + tone}>
      <span className="member-summary-icon">
        <Icon size={18} />
      </span>
      <span className="member-summary-copy">
        <small>{label}</small>
        <strong>
          {value === undefined ? "—" : value.toLocaleString("en-IN")}
        </strong>
      </span>
    </article>
  );
}
