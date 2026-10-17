import { useEffect, useMemo, useState, type FormEvent } from "react";
import {
  AlertCircle,
  ArrowDownUp,
  ArrowLeft,
  ArrowRight,
  Ban,
  Check,
  CheckCircle2,
  ChevronDown,
  ChevronLeft,
  ChevronRight,
  Clock3,
  Filter,
  LockKeyhole,
  MoreHorizontal,
  Search,
  ShieldAlert,
  ShieldCheck,
  UserRound,
  UserRoundCheck,
  Users,
  X,
} from "lucide-react";
import { Link } from "react-router-dom";
import { StatusPill } from "../components/StatusPill";
import { getMemberRepository } from "../services/repositories/members/memberRepository";
import { memberDataNotice } from "../services/mock/members/members";
import type {
  DemoMemberAction,
  MemberAccountStatus,
  MemberActionType,
  MemberAuditEntry,
  MemberQuery,
  MemberRecord,
  MemberSortField,
  MemberVerificationStatus,
  RegistrationPeriod,
} from "../types/member";

const PAGE_SIZE = 8;
const DEMO_REFERENCE_TIME = Date.parse("2026-10-15T12:00:00Z");

const accountLabels: Record<MemberAccountStatus, string> = {
  active: "Active",
  restricted: "Restricted",
  suspended: "Suspended",
  banned: "Banned",
};

const verificationLabels: Record<MemberVerificationStatus, string> = {
  verified: "Verified",
  pending: "Pending review",
  "in-progress": "In progress",
  failed: "Failed",
  "not-verified": "Not verified",
};

function accountTone(status: MemberAccountStatus): "green" | "amber" | "urgent" | "neutral" {
  if (status === "active") return "green";
  if (status === "restricted") return "amber";
  if (status === "suspended" || status === "banned") return "urgent";
  return "neutral";
}

function verificationTone(status: MemberVerificationStatus): "green" | "amber" | "urgent" | "neutral" {
  if (status === "verified") return "green";
  if (status === "pending" || status === "in-progress") return "amber";
  if (status === "failed") return "urgent";
  return "neutral";
}

function formatDate(value: string | null): string {
  if (!value) return "No recent activity";
  return new Intl.DateTimeFormat("en-IN", { day: "2-digit", month: "short", year: "numeric" }).format(new Date(value));
}

function formatDateTime(value: string): string {
  return new Intl.DateTimeFormat("en-IN", {
    day: "2-digit",
    month: "short",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  }).format(new Date(value));
}

export function MemberManagementPage() {
  const [members, setMembers] = useState<MemberRecord[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [loadError, setLoadError] = useState(false);
  const [retryCount, setRetryCount] = useState(0);
  const [query, setQuery] = useState("");
  const [accountStatus, setAccountStatus] = useState<MemberQuery["accountStatus"]>("all");
  const [verificationStatus, setVerificationStatus] = useState<MemberQuery["verificationStatus"]>("all");
  const [registrationPeriod, setRegistrationPeriod] = useState<RegistrationPeriod>("all");
  const [sortField, setSortField] = useState<MemberSortField>("registeredAt");
  const [sortDirection, setSortDirection] = useState<"asc" | "desc">("desc");
  const [page, setPage] = useState(1);
  const [selectedMemberId, setSelectedMemberId] = useState<string | null>(null);
  const [pendingAction, setPendingAction] = useState<MemberActionType | null>(null);
  const [actionReason, setActionReason] = useState("");
  const [durationHours, setDurationHours] = useState("168");
  const [actionError, setActionError] = useState("");
  const [isActing, setIsActing] = useState(false);
  const [auditEntries, setAuditEntries] = useState<MemberAuditEntry[]>([]);
  const [notice, setNotice] = useState("");

  useEffect(() => {
    let active = true;
    getMemberRepository()
      .list()
      .then((items) => {
        if (active) setMembers(items);
      })
      .catch(() => {
        if (active) setLoadError(true);
      })
      .finally(() => {
        if (active) setIsLoading(false);
      });
    return () => {
      active = false;
    };
  }, [retryCount]);

  const filteredMembers = useMemo(() => {
    const normalizedQuery = query.trim().toLowerCase();
    const cutoff = registrationPeriod === "all"
      ? null
      : DEMO_REFERENCE_TIME - Number(registrationPeriod) * 24 * 60 * 60 * 1000;

    return members
      .filter((member) => {
        const matchesSearch = !normalizedQuery || [
          member.reference,
          member.displayName,
          member.emailMasked,
          member.phoneMasked,
        ].some((value) => value.toLowerCase().includes(normalizedQuery));
        const matchesAccount = accountStatus === "all" || member.accountStatus === accountStatus;
        const matchesVerification = verificationStatus === "all" || member.verificationStatus === verificationStatus;
        const matchesPeriod = cutoff === null || new Date(member.registeredAt).getTime() >= cutoff;
        return matchesSearch && matchesAccount && matchesVerification && matchesPeriod;
      })
      .sort((a, b) => {
        let comparison = 0;
        if (sortField === "name") comparison = a.displayName.localeCompare(b.displayName);
        else if (sortField === "lastActiveAt") comparison = (a.lastActiveAt ?? "").localeCompare(b.lastActiveAt ?? "");
        else comparison = a.registeredAt.localeCompare(b.registeredAt);
        return sortDirection === "asc" ? comparison : -comparison;
      });
  }, [members, query, accountStatus, verificationStatus, registrationPeriod, sortField, sortDirection]);

  const totalPages = Math.max(1, Math.ceil(filteredMembers.length / PAGE_SIZE));
  const currentPage = Math.min(page, totalPages);
  const pageMembers = filteredMembers.slice((currentPage - 1) * PAGE_SIZE, currentPage * PAGE_SIZE);
  const selectedMember = members.find((member) => member.id === selectedMemberId) ?? null;
  const selectedAudit = selectedMember ? auditEntries.filter((entry) => entry.memberId === selectedMember.id) : [];
  const activeCount = members.filter((member) => member.accountStatus === "active").length;
  const pendingCount = members.filter((member) => member.verificationStatus === "pending" || member.verificationStatus === "in-progress").length;
  const restrictedCount = members.filter((member) => member.accountStatus === "restricted" || member.accountStatus === "suspended").length;

  function resetFilters() {
    setQuery("");
    setAccountStatus("all");
    setVerificationStatus("all");
    setRegistrationPeriod("all");
    setSortField("registeredAt");
    setSortDirection("desc");
    setPage(1);
  }

  function startAction(type: MemberActionType) {
    if (!selectedMember) return;
    setPendingAction(type);
    setActionReason("");
    setDurationHours("168");
    setActionError("");
  }

  async function confirmAction(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!selectedMember || !pendingAction) return;
    const reason = actionReason.trim();
    if (reason.length < 10) {
      setActionError("Enter a reason with at least 10 characters.");
      return;
    }
    if ((pendingAction === "restrict" || pendingAction === "suspend") && !durationHours) {
      setActionError("Choose a duration for this simulated action.");
      return;
    }

    setIsActing(true);
    setActionError("");
    const performedAt = new Date().toISOString();
    const action: DemoMemberAction = {
      memberId: selectedMember.id,
      type: pendingAction,
      reason,
      ...(pendingAction === "restrict" || pendingAction === "suspend" ? { durationHours: Number(durationHours) } : {}),
      performedAt,
      performedBy: "Demo Super Admin",
    };

    try {
      const updated = await getMemberRepository().simulateAction(action);
      setMembers((current) => current.map((member) => member.id === updated.id ? updated : member));
      const descriptions: Record<MemberActionType, string> = {
        warning: "Warning recorded in demo session",
        restrict: "Restriction simulated in demo session",
        suspend: "Suspension simulated in demo session",
        reinstate: "Reinstatement simulated in demo session",
      };
      const auditEntry: MemberAuditEntry = {
        ...action,
        id: "demo-audit-" + String(Date.now()),
        memberReference: updated.reference,
        description: descriptions[pendingAction],
        demoOnly: true,
      };
      setAuditEntries((current) => [auditEntry, ...current]);
      setPendingAction(null);
      setActionReason("");
      setNotice(descriptions[action.type] + " for " + updated.displayName + ". No production record was changed.");
    } catch {
      setActionError("The demo action could not be completed. No production record was changed.");
    } finally {
      setIsActing(false);
    }
  }

  return (
    <div className="members-page">
      <div className="members-breadcrumb"><Link to="/dashboard"><ArrowLeft size={14} /> Overview dashboard</Link><span>/</span><span>People &amp; trust</span><span>/</span><strong>Members &amp; accounts</strong></div>

      <section className="page-heading members-page-heading">
        <div>
          <div className="eyebrow"><span className="eyebrow-line" /> PEOPLE &amp; TRUST</div>
          <h1>Members &amp; accounts</h1>
          <p>Find member records, review account states and follow an auditable action workflow.</p>
        </div>
        <div className="members-heading-meta"><StatusPill tone="demo"><span className="status-pill__dot" /> DEMO DATA</StatusPill><span>Contact details are masked</span></div>
      </section>

      {notice && (
        <div className="member-toast" role="status">
          <CheckCircle2 size={17} /><span>{notice}</span><button type="button" onClick={() => setNotice("")} aria-label="Dismiss demo action notice"><X size={15} /></button>
        </div>
      )}

      <section className="member-summary" aria-label="Member summary">
        <SummaryCard icon={Users} label="Total sample members" value={members.length.toString()} tone="rose" />
        <SummaryCard icon={UserRoundCheck} label="Active accounts" value={activeCount.toString()} tone="green" />
        <SummaryCard icon={Clock3} label="Awaiting verification" value={pendingCount.toString()} tone="amber" />
        <SummaryCard icon={ShieldAlert} label="Restricted or suspended" value={restrictedCount.toString()} tone="violet" />
      </section>

      <section className="panel member-directory-panel">
        <div className="member-directory-heading">
          <div><span className="panel-kicker">DIRECTORY</span><h2>Member directory</h2><p>Search and filter fictional member records. Sensitive contact data remains masked.</p></div>
          <span className="member-total-pill"><Users size={14} /> {filteredMembers.length} results</span>
        </div>

        <div className="member-filter-toolbar">
          <label className="member-search-field">
            <Search size={17} />
            <input
              type="search"
              aria-label="Search members"
              placeholder="Search name, member ID or masked contact"
              value={query}
              onChange={(event) => { setQuery(event.target.value); setPage(1); }}
            />
            {query && <button type="button" aria-label="Clear member search" onClick={() => { setQuery(""); setPage(1); }}><X size={14} /></button>}
          </label>
          <label className="member-filter-select"><span>Account status</span><select aria-label="Filter by account status" value={accountStatus} onChange={(event) => { setAccountStatus(event.target.value as MemberQuery["accountStatus"]); setPage(1); }}><option value="all">All statuses</option><option value="active">Active</option><option value="restricted">Restricted</option><option value="suspended">Suspended</option><option value="banned">Banned</option></select><ChevronDown size={14} /></label>
          <label className="member-filter-select"><span>Verification</span><select aria-label="Filter by verification status" value={verificationStatus} onChange={(event) => { setVerificationStatus(event.target.value as MemberQuery["verificationStatus"]); setPage(1); }}><option value="all">All verification</option><option value="verified">Verified</option><option value="pending">Pending review</option><option value="in-progress">In progress</option><option value="failed">Failed</option><option value="not-verified">Not verified</option></select><ChevronDown size={14} /></label>
          <label className="member-filter-select member-filter-select--period"><span>Registered</span><select aria-label="Filter by registration period" value={registrationPeriod} onChange={(event) => { setRegistrationPeriod(event.target.value as RegistrationPeriod); setPage(1); }}><option value="all">Any time</option><option value="7">Last 7 days</option><option value="30">Last 30 days</option><option value="90">Last 90 days</option></select><ChevronDown size={14} /></label>
          <button className="button button--filter-reset" type="button" onClick={resetFilters}><Filter size={14} /> Reset</button>
        </div>

        <div className="member-directory-subbar"><span><span className="member-subbar-dot" /> Fictional data</span><label>Sort by <select aria-label="Sort member directory" value={sortField + ":" + sortDirection} onChange={(event) => { const [field, direction] = event.target.value.split(":") as [MemberSortField, "asc" | "desc"]; setSortField(field); setSortDirection(direction); setPage(1); }}><option value="registeredAt:desc">Newest registered</option><option value="registeredAt:asc">Oldest registered</option><option value="name:asc">Name A–Z</option><option value="name:desc">Name Z–A</option><option value="lastActiveAt:desc">Recently active</option><option value="lastActiveAt:asc">Least recently active</option></select><ArrowDownUp size={13} /></label></div>

        {isLoading ? (
          <div className="member-directory-state" aria-busy="true"><span className="dashboard-loading-mark"><Users size={22} /></span><h3>Loading sample members</h3><p>Preparing fictional directory records.</p></div>
        ) : loadError ? (
          <div className="member-directory-state" role="alert"><AlertCircle size={25} /><h3>Could not load member records</h3><p>The mock member source did not respond. No backend is configured.</p><button type="button" className="button button--secondary" onClick={() => { setIsLoading(true); setLoadError(false); setRetryCount((count) => count + 1); }}>Retry</button></div>
        ) : filteredMembers.length === 0 ? (
          <div className="member-directory-state"><Search size={24} /><h3>No members match these filters</h3><p>Try a different search term or clear your filters.</p><button type="button" className="button button--secondary" onClick={resetFilters}>Clear filters</button></div>
        ) : (
          <>
            <div className="member-table-scroll">
              <table className="member-table">
                <thead><tr><th>Member</th><th>Verification</th><th>Account status</th><th>Registered</th><th>Last active</th><th aria-label="View member details" /></tr></thead>
                <tbody>
                  {pageMembers.map((member) => (
                    <tr key={member.id}>
                      <td>
                        <button className="member-identity-button" type="button" onClick={() => setSelectedMemberId(member.id)}>
                          <span className="member-avatar">{member.initials}</span>
                          <span className="member-identity-copy"><strong>{member.displayName}</strong><small>{member.reference}</small></span>
                        </button>
                      </td>
                      <td><StatusPill tone={verificationTone(member.verificationStatus)}>{verificationLabels[member.verificationStatus]}</StatusPill></td>
                      <td><StatusPill tone={accountTone(member.accountStatus)} dot>{accountLabels[member.accountStatus]}</StatusPill></td>
                      <td><span className="member-table-date">{formatDate(member.registeredAt)}</span></td>
                      <td><span className={member.lastActiveAt ? "member-table-date" : "member-table-date member-table-date--empty"}>{formatDate(member.lastActiveAt)}</span></td>
                      <td><button className="member-row-open" type="button" onClick={() => setSelectedMemberId(member.id)} aria-label={"View " + member.displayName}><ArrowRight size={15} /></button></td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            <div className="member-pagination">
              <span>Showing <strong>{(currentPage - 1) * PAGE_SIZE + 1}–{Math.min(currentPage * PAGE_SIZE, filteredMembers.length)}</strong> of <strong>{filteredMembers.length}</strong> sample members</span>
              <div className="pagination-controls">
                <button type="button" className="pagination-arrow" disabled={currentPage <= 1} onClick={() => setPage((current) => Math.max(1, current - 1))} aria-label="Previous page"><ChevronLeft size={16} /></button>
                {Array.from({ length: totalPages }, (_, index) => index + 1).map((pageNumber) => <button type="button" className={"pagination-number" + (pageNumber === currentPage ? " pagination-number--active" : "")} aria-current={pageNumber === currentPage ? "page" : undefined} key={pageNumber} onClick={() => setPage(pageNumber)}>{pageNumber}</button>)}
                <button type="button" className="pagination-arrow" disabled={currentPage >= totalPages} onClick={() => setPage((current) => Math.min(totalPages, current + 1))} aria-label="Next page"><ChevronRight size={16} /></button>
              </div>
            </div>
          </>
        )}
      </section>

      <div className="member-privacy-note"><LockKeyhole size={15} /><span>{memberDataNotice}</span></div>

      {selectedMember && (
        <MemberDetailDrawer
          member={selectedMember}
          auditEntries={selectedAudit}
          onClose={() => setSelectedMemberId(null)}
          onAction={startAction}
        />
      )}

      {pendingAction && selectedMember && (
        <div className="member-modal-overlay" role="presentation" onMouseDown={(event) => { if (event.target === event.currentTarget && !isActing) setPendingAction(null); }}>
          <section className="member-action-modal" role="dialog" aria-modal="true" aria-labelledby="member-action-title">
            <div className="member-modal-heading"><span className={"member-modal-icon member-modal-icon--" + pendingAction}><ActionIcon action={pendingAction} size={20} /></span><button className="member-modal-close" type="button" aria-label="Close action dialog" disabled={isActing} onClick={() => setPendingAction(null)}><X size={18} /></button></div>
            <div className="member-modal-kicker">DEMO ACTION CONFIRMATION</div>
            <h2 id="member-action-title">{actionTitle(pendingAction)}</h2>
            <p className="member-modal-description">This will simulate an action for <strong>{selectedMember.displayName}</strong> ({selectedMember.reference}) in the current demo session only.</p>
            <div className="member-action-warning"><AlertCircle size={15} /><span>No real account will be changed, no notification will be sent and nothing will be persisted to a server.</span></div>
            <form onSubmit={confirmAction}>
              <label className="member-form-label" htmlFor="member-action-reason">Reason <span>Required</span></label>
              <textarea id="member-action-reason" value={actionReason} onChange={(event) => { setActionReason(event.target.value); setActionError(""); }} minLength={10} maxLength={500} rows={3} placeholder="Describe the reason for this administrative action…" required />
              <div className="member-form-helper"><span>Minimum 10 characters</span><span>{actionReason.length}/500</span></div>
              {(pendingAction === "restrict" || pendingAction === "suspend") && (
                <>
                  <label className="member-form-label" htmlFor="member-action-duration">Demo duration <span>Required</span></label>
                  <select id="member-action-duration" value={durationHours} onChange={(event) => setDurationHours(event.target.value)} required>
                    <option value="24">24 hours</option><option value="168">7 days</option><option value="720">30 days</option>
                  </select>
                  <p className="member-duration-note">Temporary duration only; permanent bans are deliberately excluded from this prototype.</p>
                </>
              )}
              {actionError && <p className="member-action-error" role="alert">{actionError}</p>}
              <div className="member-action-modal-footer"><button className="button button--secondary" type="button" disabled={isActing} onClick={() => setPendingAction(null)}>Cancel</button><button className="button button--primary" type="submit" disabled={isActing || actionReason.trim().length < 10}>{isActing ? "Simulating…" : "Confirm demo action"} <ArrowRight size={15} /></button></div>
            </form>
          </section>
        </div>
      )}
    </div>
  );
}

function SummaryCard({ icon: Icon, label, value, tone }: { icon: typeof Users; label: string; value: string; tone: "rose" | "green" | "amber" | "violet" }) {
  return <article className={"member-summary-card member-summary-card--" + tone}><span className="member-summary-icon"><Icon size={18} /></span><span className="member-summary-copy"><small>{label}</small><strong>{value}</strong></span></article>;
}

function ActionIcon({ action, size = 16 }: { action: MemberActionType; size?: number }) {
  if (action === "warning") return <AlertCircle size={size} />;
  if (action === "restrict") return <LockKeyhole size={size} />;
  if (action === "suspend") return <Ban size={size} />;
  return <CheckCircle2 size={size} />;
}

function actionTitle(action: MemberActionType): string {
  const titles: Record<MemberActionType, string> = {
    warning: "Issue a warning",
    restrict: "Restrict account",
    suspend: "Temporarily suspend account",
    reinstate: "Reinstate account",
  };
  return titles[action];
}

function MemberDetailDrawer({ member, auditEntries, onClose, onAction }: {
  member: MemberRecord;
  auditEntries: MemberAuditEntry[];
  onClose: () => void;
  onAction: (action: MemberActionType) => void;
}) {
  const canRestrict = member.accountStatus === "active";
  const canReinstate = member.accountStatus === "restricted" || member.accountStatus === "suspended";

  return (
    <div className="member-drawer-overlay" role="presentation" onMouseDown={(event) => { if (event.target === event.currentTarget) onClose(); }}>
      <aside className="member-detail-drawer" role="dialog" aria-modal="true" aria-labelledby="member-detail-title">
        <header className="member-drawer-header"><div><span className="panel-kicker">MEMBER RECORD</span><span className="member-drawer-ref">{member.reference}</span></div><button className="member-drawer-close" type="button" aria-label="Close member details" onClick={onClose}><X size={19} /></button></header>
        <div className="member-drawer-scroll">
          <div className="member-detail-profile"><span className="member-avatar member-avatar--large">{member.initials}</span><h2 id="member-detail-title">{member.displayName}</h2><p>{member.reference}</p><div className="member-detail-status"><StatusPill tone={accountTone(member.accountStatus)} dot>{accountLabels[member.accountStatus]}</StatusPill><StatusPill tone={verificationTone(member.verificationStatus)}>{verificationLabels[member.verificationStatus]}</StatusPill></div></div>

          <section className="member-detail-section"><h3><UserRound size={15} /> Account overview</h3><dl className="member-detail-list"><div><dt>Member reference</dt><dd>{member.reference}</dd></div><div><dt>Email</dt><dd>{member.emailMasked}</dd></div><div><dt>Phone</dt><dd>{member.phoneMasked}</dd></div><div><dt>Registered</dt><dd>{formatDateTime(member.registeredAt)}</dd></div><div><dt>Last active</dt><dd>{member.lastActiveAt ? formatDateTime(member.lastActiveAt) : "No recent activity"}</dd></div><div><dt>Warnings in demo</dt><dd>{member.warningCount}</dd></div>{member.restrictionReason && <div><dt>Latest restriction reason</dt><dd>{member.restrictionReason}</dd></div>}{member.restrictionExpiresAt && <div><dt>Demo expiry</dt><dd>{formatDateTime(member.restrictionExpiresAt)}</dd></div>}</dl></section>

          <section className="member-detail-section"><h3><ShieldCheck size={15} /> Account actions</h3><p className="member-section-description">Actions are simulated in memory and reset when the app session is refreshed.</p><div className="member-action-buttons"><button type="button" className="member-action-button member-action-button--warning" onClick={() => onAction("warning")}><AlertCircle size={16} /><span><strong>Issue warning</strong><small>Increment demo warning count</small></span><ArrowRight size={14} /></button>{canRestrict && <button type="button" className="member-action-button" onClick={() => onAction("restrict")}><LockKeyhole size={16} /><span><strong>Restrict account</strong><small>Simulate a time-limited restriction</small></span><ArrowRight size={14} /></button>}{canRestrict && <button type="button" className="member-action-button member-action-button--danger" onClick={() => onAction("suspend")}><Ban size={16} /><span><strong>Temporarily suspend</strong><small>Simulate a temporary suspension</small></span><ArrowRight size={14} /></button>}{canReinstate && <button type="button" className="member-action-button member-action-button--success" onClick={() => onAction("reinstate")}><Check size={16} /><span><strong>Reinstate account</strong><small>Simulate restoring active status</small></span><ArrowRight size={14} /></button>}</div></section>

          <section className="member-detail-section member-detail-audit"><h3><Clock3 size={15} /> Demo action history</h3>{auditEntries.length ? <div className="member-audit-list">{auditEntries.map((entry) => <article className="member-audit-item" key={entry.id}><div><strong>{entry.description}</strong><small>{formatDateTime(entry.performedAt)} · {entry.performedBy}</small><p>{entry.reason}</p></div><StatusPill tone="demo">DEMO</StatusPill></article>)}</div> : <div className="member-audit-empty"><MoreHorizontal size={18} /><span>No actions have been simulated for this record in the current session.</span></div>}</section>
          <div className="member-drawer-security-note"><LockKeyhole size={14} /><span>Contact details are masked. Identity evidence, private messages, health data and precise location are not available in this view.</span></div>
        </div>
        <footer className="member-drawer-footer"><button className="button button--secondary" type="button" onClick={onClose}>Close details</button></footer>
      </aside>
    </div>
  );
}
