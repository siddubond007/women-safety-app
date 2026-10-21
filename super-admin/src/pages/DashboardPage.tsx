import { useEffect, useState } from "react";
import { Activity, AlertCircle, CheckCircle2, Clock3, RefreshCw, ShieldCheck, Users } from "lucide-react";
import { Link, useNavigate } from "react-router-dom";
import { StatusPill } from "../components/StatusPill";
import { adminAuthService, isStagingTestAdminMode } from "../services/auth/adminAuthService";
import { adminApi, AdminApiError } from "../services/api/adminApi";

type MemberSummaryResponse = {
  summary: {
    totalAccounts: number;
    activeAccounts: number;
    pendingAccounts: number;
    verifiedAccounts: number;
    rejectedAccounts: number;
    pendingManualReviews: number;
  };
};
type ReviewQueueItem = {
  id: string;
  submissionId: string;
  accountId: string;
  reference: string;
  displayName: string;
  dateOfBirth: string;
  emailMasked: string;
  phoneMasked: string;
  registeredAt: string;
  submittedAt: string;
  manualReviewConsent: { version: string; acceptedAt: string };
};

type OverviewData = { summary: MemberSummaryResponse["summary"]; queue: ReviewQueueItem[] };

export function DashboardPage() {
  const navigate = useNavigate();
  const [data, setData] = useState<OverviewData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [refresh, setRefresh] = useState(0);
  const [seeding, setSeeding] = useState(false);
  const [seedNotice, setSeedNotice] = useState("");

  function requestRefresh() {
    setLoading(true);
    setError("");
    setRefresh((value) => value + 1);
  }

  async function triggerLiveSeed() {
    setSeeding(true);
    try {
      const res = await adminApi<{ message: string }>("/admin-review/seed-live-data", { method: "POST", body: {} });
      setSeedNotice(res.message);
      requestRefresh();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Failed to seed database.");
    } finally {
      setSeeding(false);
    }
  }

  useEffect(() => {
    let active = true;

    const fetchDashboard = async () => {
      try {
        const [members, queue] = await Promise.all([
          adminApi<MemberSummaryResponse>("/admin-review/members?page=1&pageSize=1"),
          adminApi<ReviewQueueItem[]>("/admin-review/queue"),
        ]);
        if (active) {
          setData({ summary: members.summary, queue });
          setError("");
        }
      } catch (cause) {
        if (!active) return;
        if (cause instanceof AdminApiError && cause.statusCode === 401) {
          adminAuthService.signOut();
          navigate("/login", { replace: true });
          return;
        }
        setError(cause instanceof Error ? cause.message : "Live dashboard data could not be loaded.");
        setData(null);
      } finally {
        if (active) setLoading(false);
      }
    };

    void fetchDashboard();
    return () => {
      active = false;
    };
  }, [navigate, refresh]);

  const metrics = data ? [
    { id: "accounts", label: "Registered accounts", value: data.summary.totalAccounts, detail: "Persisted in PostgreSQL", icon: Users, tone: "rose" },
    { id: "active", label: "Active accounts", value: data.summary.activeAccounts, detail: "Account status ACTIVE", icon: CheckCircle2, tone: "green" },
    { id: "verified", label: "Verified accounts", value: data.summary.verifiedAccounts, detail: "Verification status VERIFIED", icon: ShieldCheck, tone: "violet" },
    { id: "pending", label: "Pending eligibility reviews", value: data.summary.pendingManualReviews, detail: "Real review submissions", icon: Clock3, tone: "amber" },
  ] : [];

  return (
    <div className="dashboard-page">
      <section className="page-heading">
        <div><div className="eyebrow"><span className="eyebrow-line" /> THE BIG PICTURE</div><h1>Overview dashboard</h1><p>{isStagingTestAdminMode ? "Live account and eligibility information from the hosted Sakhi staging database." : "Live account and eligibility information from the Sakhi development database."}</p></div>
        <div className="heading-meta">{isStagingTestAdminMode ? <StatusPill tone="green"><span className="status-pill__dot" /> STAGING DATABASE</StatusPill> : <StatusPill tone="green"><span className="status-pill__dot" /> LIVE DATABASE</StatusPill>}{!isStagingTestAdminMode && <button className="button button--primary" type="button" onClick={() => void triggerLiveSeed()} disabled={seeding || loading}>{seeding ? "Syncing data..." : "Sync 8 Users & 11 Live Posts"}</button>}<button className="button button--secondary" type="button" onClick={requestRefresh} disabled={loading}><RefreshCw size={14} /> Refresh data</button></div>
      </section>

      {seedNotice && <div className="member-toast" role="status" style={{ marginBottom: 16 }}><CheckCircle2 size={17} /><span>{seedNotice}</span></div>}
      {error && <section className="panel dashboard-state" role="alert"><div><AlertCircle size={26} /><h2>Live data unavailable</h2><p>{error}</p><p>The dashboard will not substitute fictional counts or sample records.</p><button className="button button--secondary" type="button" onClick={requestRefresh}>Retry connection</button></div></section>}

      {loading && !data && !error && <section className="panel dashboard-state" aria-busy="true"><div><Activity size={24} /><h2>Loading database records</h2><p>Fetching live account counts and the actual eligibility-review queue.</p></div></section>}

      {data && <>
        <section className="primary-metrics" aria-label="Live database metrics">
          {metrics.map(({ id, label, value, detail, icon: Icon, tone }, index) => <article className={"metric-card metric-card--" + tone} key={id}><div className="metric-card-top"><span className="metric-icon"><Icon size={19} /></span><span className="metric-index">0{index + 1}</span></div><p className="metric-label">{label}</p><div className="metric-value-row"><strong className="metric-value">{value.toLocaleString("en-IN")}</strong></div><div className="metric-card-foot"><span>{detail}</span></div></article>)}
        </section>

        <section className="panel queue-panel">
          <div className="panel-heading"><div><span className="panel-kicker">LIVE DATABASE</span><h2>Eligibility reviews awaiting a decision</h2><p>Only persisted submissions appear here; no sample queue items are generated.</p></div><Link className="panel-link" to="/verification">Open review queue</Link></div>
          <div className="table-scroll"><table className="operations-table"><thead><tr><th>Member</th><th>Reference</th><th>Submitted</th><th>Status</th><th aria-label="Open review" /></tr></thead><tbody>
            {data.queue.length === 0 && <tr><td colSpan={5} className="member-empty-cell">No actual pending eligibility submissions are in the database.</td></tr>}
            {data.queue.slice(0, 8).map((item) => <tr key={item.submissionId}><td><span className="table-ref">{item.displayName}</span><span className="table-category">{item.phoneMasked}</span></td><td><span className="table-owner">{item.reference}</span></td><td><span className="table-age">{new Intl.DateTimeFormat("en-IN", { day: "2-digit", month: "short", year: "numeric" }).format(new Date(item.submittedAt))}</span></td><td><StatusPill tone="amber">Pending review</StatusPill></td><td><Link className="table-open" to="/verification" aria-label={"Review " + item.reference}>→</Link></td></tr>)}
          </tbody></table></div>
          <div className="table-note"><ShieldCheck size={14} /><span>All counts and queue entries above come from the backend response. Unconnected platform modules are not represented with invented metrics.</span></div>
        </section>

        <section className="panel dashboard-account-panel">
          <div className="panel-heading dashboard-account-heading"><div><span className="panel-kicker">ACCOUNT MANAGEMENT</span><h2>Real member records</h2><p>Search accounts and change development-only account/verification status with an audit reason.</p></div><Link className="button button--secondary" to="/members">Open member directory</Link></div>
        </section>
        <div className="dashboard-footnote"><ShieldCheck size={15} /><span>Local development/test environment. Manual state overrides are not real-world eligibility decisions.</span><Link to="/settings">About this environment →</Link></div>
      </>}
    </div>
  );
}
