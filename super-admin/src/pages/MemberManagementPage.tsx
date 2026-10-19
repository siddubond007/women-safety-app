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

export function MemberManagementPage() {
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
  const [newName, setNewName] = useState("");
  const [newPhone, setNewPhone] = useState("+919845099111");
  const [newBio, setNewBio] = useState("Wellness & community member 💜");
  const [newVerified, setNewVerified] = useState(true);
  const [creatingMember, setCreatingMember] = useState(false);

  async function createNewMember(event: FormEvent) {
    event.preventDefault();
    if (!newName.trim() || !newPhone.trim()) return;
    setCreatingMember(true);
    setError("");
    try {
      const created = await adminApi<{ displayName: string; username: string }>("/admin-review/members/create", {
        method: "POST",
        body: {
          displayName: newName.trim(),
          phoneE164: newPhone.trim(),
          bio: newBio.trim(),
          verifyImmediately: newVerified,
        },
      });
      setNewName("");
      setNotice(`Created member ${created.displayName} (${created.username}) in PostgreSQL! They are now live in the mobile app.`);
      await load();
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : "Could not create member.");
    } finally {
      setCreatingMember(false);
    }
  }

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
  }, [page, search, accountFilter, verificationFilter, refresh, navigate]);

  useEffect(() => { void load(); }, [load]);

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
        method: "POST",
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
        method: "POST",
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
          <p>Live member records from the Sakhi development database. Verify any member here to unlock their mobile Home screen.</p>
        </div>
        <div className="members-heading-meta"><StatusPill tone="green"><span className="status-pill__dot" /> LIVE DATABASE</StatusPill><span>Click &ldquo;Verify &amp; Activate&rdquo; to unlock Home screen</span></div>
      </section>

      {notice && <div className="member-toast" role="status"><CheckCircle2 size={17} /><span>{notice}</span><button type="button" onClick={() => setNotice("")} aria-label="Dismiss notice"><X size={15} /></button></div>}
      {error && <div className="admin-error-banner" role="alert"><AlertCircle size={17} /><span>{error}</span><button type="button" className="button button--secondary" onClick={() => setRefresh((value) => value + 1)}>Retry</button></div>}

      <section className="member-summary" aria-label="Live database summary">
        <SummaryCard icon={Users} label="Total database accounts" value={summary?.totalAccounts} tone="rose" />
        <SummaryCard icon={CheckCircle2} label="Active accounts" value={summary?.activeAccounts} tone="green" />
        <SummaryCard icon={ShieldCheck} label="Verified accounts" value={summary?.verifiedAccounts} tone="violet" />
        <SummaryCard icon={AlertCircle} label="Pending eligibility reviews" value={summary?.pendingManualReviews} tone="amber" />
      </section>

      <section className="panel" style={{ marginBottom: 18 }}>
        <div className="member-directory-heading">
          <div><span className="panel-kicker">ADD LIVE DATABASE USER</span><h2>Create a new Sakhi member in PostgreSQL</h2><p>New members created here are immediately saved in <code>member_accounts</code>, <code>member_profiles</code>, and <code>community_directory_profiles</code>.</p></div>
        </div>
        <form className="member-filter-toolbar member-create-toolbar" onSubmit={createNewMember}>
          <label className="member-filter-select"><span>Display Name</span><input type="text" value={newName} onChange={(e) => setNewName(e.target.value)} placeholder="e.g. Divya Krishnan" required /></label>
          <label className="member-filter-select"><span>Mobile (E.164)</span><input type="text" value={newPhone} onChange={(e) => setNewPhone(e.target.value)} placeholder="+919845099111" required /></label>
          <label className="member-filter-select"><span>Bio</span><input type="text" value={newBio} onChange={(e) => setNewBio(e.target.value)} placeholder="Bio shown in app" /></label>
          <label className="member-filter-select"><span>Initial State</span><select value={newVerified ? "verified" : "pending"} onChange={(e) => setNewVerified(e.target.value === "verified")}><option value="verified">Active + Verified (Home Unlocked)</option><option value="pending">Pending Verification (In Review Queue)</option></select></label>
          <button className="button button--primary" type="submit" disabled={creatingMember}>{creatingMember ? "Creating…" : "+ Create Member"}</button>
        </form>
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
            <thead><tr><th>Member</th><th>Mobile</th><th>Registered</th><th>Account</th><th>Verification</th><th>Eligibility / review</th><th>Development access</th></tr></thead>
            <tbody>
              {loading && <tr><td colSpan={7} className="member-empty-cell">Loading records from the database…</td></tr>}
              {!loading && !error && data?.items.length === 0 && <tr><td colSpan={7} className="member-empty-cell">No database records matched these filters.</td></tr>}
              {!loading && data?.items.map((member) => {
                const isVerifiedActive =
                  member.accountStatus === "ACTIVE" && member.verificationStatus === "VERIFIED";
                return (
                  <tr key={member.id}>
                    <td><button className="member-identity-button" type="button" onClick={() => openEditor(member)}><span className="member-avatar">{initials(member.displayName)}</span><span className="member-identity-copy"><strong>{member.displayName}</strong><small>{member.reference}</small></span></button></td>
                    <td><strong>{member.phoneE164 ?? member.phoneMasked}</strong></td>
                    <td>{formatDate(member.registeredAt)}</td>
                    <td><StatusPill tone={accountTone(member.accountStatus)}>{accountLabels[member.accountStatus]}</StatusPill></td>
                    <td><StatusPill tone={verificationTone(member.verificationStatus)}>{verificationLabels[member.verificationStatus]}</StatusPill></td>
                    <td><StatusPill tone={eligibilityTone(member.eligibilityStatus)}>{eligibilityLabels[member.eligibilityStatus] ?? member.eligibilityStatus}</StatusPill><small className="member-subline">{member.eligibilitySubmittedAt ? "Submitted " + formatDate(member.eligibilitySubmittedAt) : member.profileComplete ? "No review submission" : "Profile incomplete"}</small></td>
                    <td>
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
          <header className="member-drawer-header"><div><span className="panel-kicker">LOCAL DEV / TEST ONLY</span><span className="member-drawer-ref">{selected.reference}</span></div><button className="member-drawer-close" type="button" onClick={() => setSelected(null)} aria-label="Close state editor" disabled={saving}><X size={19} /></button></header>
          <form id="member-state-form" onSubmit={saveState} className="member-drawer-form">
            <div className="member-drawer-scroll">
            <div className="member-detail-profile"><span className="member-avatar member-avatar--large">{initials(selected.displayName)}</span><h2 id="state-editor-title">{selected.displayName}</h2><p>{selected.phoneE164 ?? selected.phoneMasked} · {selected.emailMasked}</p><StatusPill tone={selected.profileComplete ? "green" : "amber"}>{selected.profileComplete ? "Profile complete" : "Profile incomplete"}</StatusPill></div>
            <section className="member-detail-section"><h3>Database record</h3><dl className="member-detail-list"><div><dt>Account UUID</dt><dd style={{ overflowWrap: "anywhere" }}>{selected.id}</dd></div><div><dt>Date of birth</dt><dd>{selected.dateOfBirth ?? "Not provided"}</dd></div><div><dt>Registered</dt><dd>{formatDateTime(selected.registeredAt)}</dd></div><div><dt>Last activity</dt><dd>{selected.lastActiveAt ? formatDateTime(selected.lastActiveAt) : "No activity recorded"}</dd></div><div><dt>Eligibility submitted</dt><dd>{selected.eligibilitySubmittedAt ? formatDateTime(selected.eligibilitySubmittedAt) : "No review submission"}</dd></div><div><dt>Eligibility reviewed</dt><dd>{selected.eligibilityReviewedAt ? formatDateTime(selected.eligibilityReviewedAt) : "Not reviewed"}</dd></div></dl></section>
            <section className="member-detail-section"><h3>Persisted account state</h3><label className="member-filter-select"><span>Account status</span><select value={accountStatus} onChange={(event) => setAccountStatus(event.target.value as AccountStatus)}><option value="PENDING_VERIFICATION">Pending verification</option><option value="ACTIVE">Active</option><option value="RESTRICTED">Restricted</option><option value="SUSPENDED">Suspended</option><option value="DELETED">Deleted</option></select></label><label className="member-filter-select"><span>Verification status</span><select value={verificationStatus} onChange={(event) => setVerificationStatus(event.target.value as VerificationStatus)}><option value="UNVERIFIED">Unverified</option><option value="VERIFIED">Verified</option><option value="REJECTED">Rejected</option></select></label>
              <button className="button button--secondary" type="button" onClick={applyQuickApproval} disabled={saving}><CheckCircle2 size={14} /> Set Active + Verified</button>
              <p className="member-section-description">Setting Account status to Active and Verification status to Verified immediately unlocks the Sakhi Home screen on the mobile app.</p>
              <label className="member-filter-select"><span>Reason for audit log (required)</span><textarea minLength={10} maxLength={500} required value={reason} onChange={(event) => setReason(event.target.value)} placeholder="Explain why this test account state is changing." rows={3} /></label>
              {actionError && <div className="admin-error-banner" role="alert"><AlertCircle size={16} /><span>{actionError}</span></div>}
            </section>
            </div>
          </form>
          <footer className="member-drawer-footer"><button className="button button--secondary" type="button" onClick={() => setSelected(null)} disabled={saving}>Cancel</button><button className="button button--primary" type="submit" form="member-state-form" disabled={saving}>{saving ? "Saving…" : "Save database state"}</button></footer>
        </aside>
      </div>}
    </div>
  );
}

function SummaryCard({ icon: Icon, label, value, tone }: { icon: typeof Users; label: string; value?: number; tone: "rose" | "green" | "amber" | "violet" }) {
  return <article className={"member-summary-card member-summary-card--" + tone}><span className="member-summary-icon"><Icon size={18} /></span><span className="member-summary-copy"><small>{label}</small><strong>{value === undefined ? "—" : value.toLocaleString("en-IN")}</strong></span></article>;
}
