import { useCallback, useEffect, useState, type FormEvent } from "react";
import { AlertCircle, CheckCircle2, ChevronLeft, ChevronRight, RefreshCw, Search, ShieldCheck, Users, X } from "lucide-react";
import { Link, useNavigate } from "react-router-dom";
import { StatusPill } from "../components/StatusPill";
import { adminApi, AdminApiError } from "../services/api/adminApi";
import { adminAuthService } from "../services/auth/adminAuthService";

type AccountStatus = "PENDING_VERIFICATION" | "ACTIVE" | "RESTRICTED" | "SUSPENDED" | "DELETED";
type VerificationStatus = "UNVERIFIED" | "VERIFIED" | "REJECTED";
type EligibilityStatus = "UNVERIFIED" | "VERIFIED" | "REJECTED" | "PENDING_MANUAL_REVIEW" | "APPROVED";
type Member = {
  id: string;
  reference: string;
  displayName: string;
  dateOfBirth: string | null;
  emailMasked: string;
  phoneMasked: string;
  phoneE164?: string;
  registeredAt: string;
  lastActiveAt: string | null;
  accountStatus: AccountStatus;
  verificationStatus: VerificationStatus;
  eligibilityStatus: EligibilityStatus;
  profileComplete: boolean;
  eligibilitySubmissionStatus: string | null;
  eligibilitySubmittedAt: string | null;
  eligibilityReviewedAt: string | null;
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
const eligibilityLabels: Record<EligibilityStatus, string> = {
  UNVERIFIED: "Not verified",
  VERIFIED: "Verified",
  REJECTED: "Rejected",
  PENDING_MANUAL_REVIEW: "Pending review",
  APPROVED: "Approved",
};
const accountTone = (status: AccountStatus): "green" | "amber" | "urgent" | "neutral" =>
  status === "ACTIVE" ? "green" : status === "PENDING_VERIFICATION" ? "amber" : status === "RESTRICTED" || status === "SUSPENDED" || status === "DELETED" ? "urgent" : "neutral";
const verificationTone = (status: VerificationStatus): "green" | "amber" | "urgent" =>
  status === "VERIFIED" ? "green" : status === "REJECTED" ? "urgent" : "amber";
const eligibilityTone = (status: EligibilityStatus): "green" | "amber" | "urgent" | "neutral" =>
  status === "VERIFIED" || status === "APPROVED" ? "green" : status === "REJECTED" ? "urgent" : status === "UNVERIFIED" ? "neutral" : "amber";
const formatDate = (value: string | null) => value ? new Intl.DateTimeFormat("en-IN", { day: "2-digit", month: "short", year: "numeric" }).format(new Date(value)) : "Never";
const formatDateTime = (value: string) => new Intl.DateTimeFormat("en-IN", { day: "2-digit", month: "short", year: "numeric", hour: "2-digit", minute: "2-digit" }).format(new Date(value));
const initials = (name: string) => name.split(/\s+/).filter(Boolean).slice(0, 2).map((part) => part[0]?.toUpperCase() ?? "").join("") || "SK";

export function MemberManagementPage({ isStagingTest = false }: { isStagingTest?: boolean }) {
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
  const [selected, setSelected] = useState<Member | null>(null);
  const [accountStatus, setAccountStatus] = useState<AccountStatus>("PENDING_VERIFICATION");
  const [verificationStatus, setVerificationStatus] = useState<VerificationStatus>("UNVERIFIED");
  const [reason, setReason] = useState("Updated account and verification state via Super Admin panel.");
  const [saving, setSaving] = useState(false);
  const [quickSavingId, setQuickSavingId] = useState<string | null>(null);
  const [actionError, setActionError] = useState("");
  const [notice, setNotice] = useState("");
  const load = useCallback(async () => {
    setLoading(true);
    setError("");
    try {
      const params = new URLSearchParams({ page: String(page), pageSize: "25" });
      if (search) params.set("search", search);
      if (accountFilter) params.set("accountStatus", accountFilter);
      if (verificationFilter) params.set("verificationStatus", verificationFilter);
      const result = await adminApi<MemberDirectory>("/admin-review/members?" + params.toString());
      setData(result);
    } catch (cause) {
      if (cause instanceof AdminApiError && cause.statusCode === 401) {
        adminAuthService.signOut();
        navigate("/login", { replace: true });
        return;
      }
      setError(cause instanceof Error ? cause.message : "The member directory could not be loaded.");
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

  function openEditor(member: Member) {
    setSelected(member);
    setAccountStatus(member.accountStatus);
    setVerificationStatus(member.verificationStatus);
    setReason("Updated account and verification state via Super Admin panel.");
    setActionError("");
  }

  function applyQuickApproval() {
    setAccountStatus("ACTIVE");
    setVerificationStatus("VERIFIED");
    setReason("Development test approval to unlock Sakhi Home screen.");
  }

  async function quickToggleVerify(member: Member) {
    const isCurrentlyVerified =
      member.accountStatus === "ACTIVE" && member.verificationStatus === "VERIFIED";
    const nextAccountStatus: AccountStatus = isCurrentlyVerified ? "PENDING_VERIFICATION" : "ACTIVE";
    const nextVerificationStatus: VerificationStatus = isCurrentlyVerified ? "UNVERIFIED" : "VERIFIED";
    setQuickSavingId(member.id);
    setError("");
    try {
      await adminApi("/admin-review/members/" + encodeURIComponent(member.id) + "/state", {
        method: "PATCH",
        body: {
          accountStatus: nextAccountStatus,
          verificationStatus: nextVerificationStatus,
          reason: isCurrentlyVerified
            ? "Reset member to Pending/Unverified from Super Admin table."
            : "Approved and verified member from Super Admin table to unlock Home access.",
        },
      });
      setNotice(
        isCurrentlyVerified
          ? `Set ${member.displayName} back to Pending / Unverified.`
          : `Verified & activated ${member.displayName}! Tap "Check account state again" in the mobile app to open the Home screen.`,
      );
      await load();
    } catch (cause) {
      if (cause instanceof AdminApiError && cause.statusCode === 401) {
        adminAuthService.signOut();
        navigate("/login", { replace: true });
        return;
      }
      setError(cause instanceof Error ? cause.message : "Could not update member verification state.");
    } finally {
      setQuickSavingId(null);
    }
  }

  async function saveState(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!selected) return;
    if (reason.trim().length < 10) {
      setActionError("Provide a reason containing at least 10 characters.");
      return;
    }
    setSaving(true);
    setActionError("");
    try {
      await adminApi("/admin-review/members/" + encodeURIComponent(selected.id) + "/state", {
        method: "PATCH",
        body: { accountStatus, verificationStatus, reason: reason.trim() },
      });
      setNotice(`Saved state (${accountStatus} / ${verificationStatus}) for ${selected.displayName}. Tap "Check account state again" in the mobile app!`);
      setSelected(null);
      await load();
    } catch (cause) {
      if (cause instanceof AdminApiError && cause.statusCode === 401) {
        adminAuthService.signOut();
        navigate("/login", { replace: true });
        return;
      }
      setActionError(cause instanceof Error ? cause.message : "The state change was not saved.");
    } finally {
      setSaving(false);
    }
  }

  const summary = data?.summary;
  const totalPages = data ? Math.max(1, Math.ceil(data.total / data.pageSize)) : 1;

  return (
    <div className="members-page">
      <div className="members-breadcrumb"><Link to="/dashboard">Overview dashboard</Link><span>/</span><strong>Members &amp; accounts</strong></div>
      <section className="page-heading members-page-heading">
        <div>
          <div className="eyebrow"><span className="eyebrow-line" /> PEOPLE &amp; TRUST</div>
          <h1>Members &amp; accounts</h1>
          <p>{isStagingTest ? "Read-only directory of persisted staging members. Submit and decide explicit eligibility requests through the review queue." : "Live member records from the development database, with local-only account-state troubleshooting controls."}</p>
        </div>
        <div className="members-heading-meta"><StatusPill tone="green"><span className="status-pill__dot" /> LIVE DATABASE</StatusPill><span>{isStagingTest ? "Eligibility decisions use the review workflow" : "Account-state overrides are local development only"}</span></div>
      </section>

      {notice && <div className="member-toast" role="status"><CheckCircle2 size={17} /><span>{notice}</span><button type="button" onClick={() => setNotice("")} aria-label="Dismiss notice"><X size={15} /></button></div>}
      {error && <div className="admin-error-banner" role="alert"><AlertCircle size={17} /><span>{error}</span><button type="button" className="button button--secondary" onClick={() => setRefresh((value) => value + 1)}>Retry</button></div>}

      <section className="member-summary" aria-label="Live database summary">
        <SummaryCard icon={Users} label="Total database accounts" value={summary?.totalAccounts} tone="rose" />
        <SummaryCard icon={CheckCircle2} label="Active accounts" value={summary?.activeAccounts} tone="green" />
        <SummaryCard icon={ShieldCheck} label="Verified accounts" value={summary?.verifiedAccounts} tone="violet" />
        <SummaryCard icon={AlertCircle} label="Pending eligibility reviews" value={summary?.pendingManualReviews} tone="amber" />
      </section>

      <section className="panel member-directory-panel">
        <div className="member-directory-heading">
          <div><span className="panel-kicker">POSTGRESQL RECORDS</span><h2>Member directory</h2><p>{data ? `Showing ${data.items.length} of ${data.total} matching records` : "Loading database records…"}</p></div>
          <button className="button button--secondary" type="button" onClick={() => setRefresh((value) => value + 1)} disabled={loading}><RefreshCw size={14} /> Refresh</button>
        </div>
        <form className="member-filter-toolbar member-directory-filter-toolbar" onSubmit={(event) => { event.preventDefault(); setPage(1); setSearch(searchDraft.trim()); }}>
          <label className="member-search-field"><Search size={15} /><input type="search" value={searchDraft} onChange={(event) => setSearchDraft(event.target.value)} placeholder="Search name, email, mobile or ID" aria-label="Search members" /></label>
          <label className="member-filter-select"><span>Account state</span><select value={accountFilter} onChange={(event) => { setPage(1); setAccountFilter(event.target.value); }}><option value="">All accounts</option><option value="PENDING_VERIFICATION">Pending</option><option value="ACTIVE">Active</option><option value="RESTRICTED">Restricted</option><option value="SUSPENDED">Suspended</option><option value="DELETED">Deleted</option></select></label>
          <label className="member-filter-select"><span>Verification</span><select value={verificationFilter} onChange={(event) => { setPage(1); setVerificationFilter(event.target.value); }}><option value="">All verification states</option><option value="UNVERIFIED">Unverified</option><option value="VERIFIED">Verified</option><option value="REJECTED">Rejected</option></select></label>
          <button className="button button--primary" type="submit"><Search size={14} /> Search</button>
        </form>

        <div className="member-table-scroll">
          <table className="member-table">
            <thead><tr><th>Member</th><th>Mobile</th><th>Registered</th><th>Account</th><th>Verification</th><th>Eligibility / review</th><th>{isStagingTest ? "Review" : "Local test actions"}</th></tr></thead>
            <tbody>
              {loading && <tr><td colSpan={7} className="member-empty-cell">Loading records from the database…</td></tr>}
              {!loading && !error && data?.items.length === 0 && <tr><td colSpan={7} className="member-empty-cell">No database records matched these filters.</td></tr>}
              {!loading && data?.items.map((member) => {
                const isVerifiedActive =
                  member.accountStatus === "ACTIVE" && member.verificationStatus === "VERIFIED";
                return (
                  <tr key={member.id}>
                    <td><button className="member-identity-button" type="button" onClick={() => openEditor(member)}><span className="member-avatar">{initials(member.displayName)}</span><span className="member-identity-copy"><strong>{member.displayName}</strong><small>{member.reference}</small></span></button></td>
                    <td><strong>{member.phoneMasked}</strong></td>
                    <td>{formatDate(member.registeredAt)}</td>
                    <td><StatusPill tone={accountTone(member.accountStatus)}>{accountLabels[member.accountStatus]}</StatusPill></td>
                    <td><StatusPill tone={verificationTone(member.verificationStatus)}>{verificationLabels[member.verificationStatus]}</StatusPill></td>
                    <td><StatusPill tone={eligibilityTone(member.eligibilityStatus)}>{eligibilityLabels[member.eligibilityStatus] ?? member.eligibilityStatus}</StatusPill><small className="member-subline">{member.eligibilitySubmittedAt ? "Submitted " + formatDate(member.eligibilitySubmittedAt) : member.profileComplete ? "No review submission" : "Profile incomplete"}</small></td>
                    <td>
                      {isStagingTest ? (
                        <Link className="button button--secondary" to="/verification">Review submissions</Link>
                      ) : (
                        <div style={{ display: "flex", gap: "8px", flexWrap: "wrap" }}>
                          <button
                            className={isVerifiedActive ? "button button--secondary" : "button button--primary"}
                            type="button"
                            disabled={quickSavingId === member.id}
                            onClick={() => void quickToggleVerify(member)}
                          >
                            {quickSavingId === member.id
                              ? "Updating…"
                              : isVerifiedActive
                                ? "Set Unverified"
                                : "Verify & Activate"}
                          </button>
                          <button className="button button--secondary" type="button" onClick={() => openEditor(member)}>Manage state</button>
                        </div>
                      )}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
        <div className="member-pagination"><span>Page {data?.page ?? page} of {totalPages}{data && data.total > 500 ? " · Results are paginated" : ""}</span><div><button className="button button--secondary" type="button" disabled={loading || page <= 1} onClick={() => setPage((value) => Math.max(1, value - 1))}><ChevronLeft size={14} /> Previous</button><button className="button button--secondary" type="button" disabled={loading || page >= totalPages} onClick={() => setPage((value) => Math.min(totalPages, value + 1))}>Next <ChevronRight size={14} /></button></div></div>
      </section>

      {selected && <div className="member-drawer-overlay" role="presentation" onMouseDown={(event) => { if (event.target === event.currentTarget && !saving) setSelected(null); }}>
        <aside className="member-detail-drawer" role="dialog" aria-modal="true" aria-labelledby="state-editor-title">
          <header className="member-drawer-header"><div><span className="panel-kicker">{isStagingTest ? "STAGING TEST · READ ONLY" : "LOCAL DEV / TEST ONLY"}</span><span className="member-drawer-ref">{selected.reference}</span></div><button className="member-drawer-close" type="button" onClick={() => setSelected(null)} aria-label="Close state editor" disabled={saving}><X size={19} /></button></header>
          <form id="member-state-form" onSubmit={isStagingTest ? undefined : saveState} className="member-drawer-form">
            <div className="member-drawer-scroll">
            <div className="member-detail-profile"><span className="member-avatar member-avatar--large">{initials(selected.displayName)}</span><h2 id="state-editor-title">{selected.displayName}</h2><p>{selected.phoneE164 ?? selected.phoneMasked} · {selected.emailMasked}</p><StatusPill tone={selected.profileComplete ? "green" : "amber"}>{selected.profileComplete ? "Profile complete" : "Profile incomplete"}</StatusPill></div>
            <section className="member-detail-section"><h3>Database record</h3><dl className="member-detail-list"><div><dt>Account UUID</dt><dd style={{ overflowWrap: "anywhere" }}>{selected.id}</dd></div><div><dt>Date of birth</dt><dd>{selected.dateOfBirth ?? "Not provided"}</dd></div><div><dt>Registered</dt><dd>{formatDateTime(selected.registeredAt)}</dd></div><div><dt>Last activity</dt><dd>{selected.lastActiveAt ? formatDateTime(selected.lastActiveAt) : "No activity recorded"}</dd></div><div><dt>Eligibility submitted</dt><dd>{selected.eligibilitySubmittedAt ? formatDateTime(selected.eligibilitySubmittedAt) : "No review submission"}</dd></div><div><dt>Eligibility reviewed</dt><dd>{selected.eligibilityReviewedAt ? formatDateTime(selected.eligibilityReviewedAt) : "Not reviewed"}</dd></div></dl></section>
            <section className="member-detail-section">
              <h3>Persisted account state</h3>
              {isStagingTest ? (
                <>
                  <dl className="member-detail-list">
                    <div><dt>Account status</dt><dd>{accountLabels[selected.accountStatus]}</dd></div>
                    <div><dt>Verification status</dt><dd>{verificationLabels[selected.verificationStatus]}</dd></div>
                    <div><dt>Eligibility</dt><dd>{eligibilityLabels[selected.eligibilityStatus] ?? selected.eligibilityStatus}</dd></div>
                  </dl>
                  <p className="member-section-description">Staging account state is read-only here. Review explicit submissions through the eligibility workflow; this directory cannot bypass that decision process.</p>
                  <Link className="button button--secondary" to="/verification">Open eligibility review</Link>
                </>
              ) : (
                <>
                  <label className="member-filter-select"><span>Account status</span><select value={accountStatus} onChange={(event) => setAccountStatus(event.target.value as AccountStatus)}><option value="PENDING_VERIFICATION">Pending verification</option><option value="ACTIVE">Active</option><option value="RESTRICTED">Restricted</option><option value="SUSPENDED">Suspended</option><option value="DELETED">Deleted</option></select></label>
                  <label className="member-filter-select"><span>Verification status</span><select value={verificationStatus} onChange={(event) => setVerificationStatus(event.target.value as VerificationStatus)}><option value="UNVERIFIED">Unverified</option><option value="VERIFIED">Verified</option><option value="REJECTED">Rejected</option></select></label>
                  <button className="button button--secondary" type="button" onClick={applyQuickApproval} disabled={saving}><CheckCircle2 size={14} /> Set Active + Verified</button>
                  <p className="member-section-description">Local development only. Staging eligibility outcomes must be recorded through the explicit review workflow.</p>
                  <label className="member-filter-select"><span>Reason for audit log (required)</span><textarea minLength={10} maxLength={500} required value={reason} onChange={(event) => setReason(event.target.value)} placeholder="Explain why this test account state is changing." rows={3} /></label>
                  {actionError && <div className="admin-error-banner" role="alert"><AlertCircle size={16} /><span>{actionError}</span></div>}
                </>
              )}
            </section>
            </div>
          </form>
          <footer className="member-drawer-footer">
            <button className="button button--secondary" type="button" onClick={() => setSelected(null)} disabled={saving}>Close</button>
            {!isStagingTest && <button className="button button--primary" type="submit" form="member-state-form" disabled={saving}>{saving ? "Saving…" : "Save database state"}</button>}
          </footer>
        </aside>
      </div>}
    </div>
  );
}

function SummaryCard({ icon: Icon, label, value, tone }: { icon: typeof Users; label: string; value?: number; tone: "rose" | "green" | "amber" | "violet" }) {
  return <article className={"member-summary-card member-summary-card--" + tone}><span className="member-summary-icon"><Icon size={18} /></span><span className="member-summary-copy"><small>{label}</small><strong>{value === undefined ? "—" : value.toLocaleString("en-IN")}</strong></span></article>;
}
