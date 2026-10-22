import { useEffect, useMemo, useState } from "react";
import {
  Activity,
  AlertCircle,
  ArrowRight,
  Camera,
  CheckCircle2,
  Clock3,
  FileWarning,
  MessageSquareWarning,
  Newspaper,
  RefreshCw,
  ShieldCheck,
  Users,
  UsersRound,
} from "lucide-react";
import { Link, useNavigate } from "react-router-dom";
import { StatusPill } from "../components/StatusPill";
import { RegistrationPolicyPanel } from "../components/RegistrationPolicyPanel";
import { adminAuthService } from "../services/auth/adminAuthService";
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

type AuditEvent = {
  id: string;
  actorType: string;
  action: string;
  targetType: string | null;
  targetId: string | null;
  outcome: string;
  createdAt: string;
};

type ReportRecord = {
  id: string;
  status: string;
  category: string;
  targetType: string;
  targetHandle: string;
  reason: string;
  createdAt: string;
};

type OperationsResponse = {
  counts: {
    totalAccounts: number;
    totalPosts: number;
    totalGroups: number;
    totalReports: number;
    totalBlocks: number;
    totalSosEvents: number;
    totalMediaUploads: number;
  };
  cloudStorage: {
    provider: string;
    publicBaseUrl: string;
    status: string;
  };
  reports: ReportRecord[];
  mediaUploads: Array<{
    uploadId: string;
    action: string;
    fileName: string;
    purpose: string;
    provider: string;
    publicUrl: string;
    createdAt: string;
  }>;
  auditEvents: AuditEvent[];
};

type DashboardData = {
  summary: MemberSummaryResponse["summary"];
  queue: ReviewQueueItem[];
  operations: OperationsResponse;
};

const formatDate = (value: string) =>
  new Intl.DateTimeFormat("en-IN", {
    day: "2-digit",
    month: "short",
    year: "numeric",
  }).format(new Date(value));

const formatDateTime = (value: string) =>
  new Intl.DateTimeFormat("en-IN", {
    day: "2-digit",
    month: "short",
    hour: "2-digit",
    minute: "2-digit",
  }).format(new Date(value));

const titleFromAction = (action: string) =>
  action
    .split(".")
    .join(" ")
    .replace(/_/g, " ")
    .replace(/\b\w/g, (letter) => letter.toUpperCase());

const isOpenReport = (report: ReportRecord) =>
  !["RESOLVED", "DISMISSED", "CLOSED"].includes(report.status.toUpperCase());

export function DashboardPage() {
  const navigate = useNavigate();
  const [data, setData] = useState<DashboardData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [refresh, setRefresh] = useState(0);

  useEffect(() => {
    let active = true;

    const fetchDashboard = async () => {
      setLoading(true);
      setError("");
      try {
        const [members, queue, operations] = await Promise.all([
          adminApi<MemberSummaryResponse>("/admin-review/members?page=1&pageSize=1"),
          adminApi<ReviewQueueItem[]>("/admin-review/queue"),
          adminApi<OperationsResponse>("/admin-review/operations"),
        ]);
        if (active) setData({ summary: members.summary, queue, operations });
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

  const recentReports = useMemo(
    () => (data?.operations.reports ?? []).filter(isOpenReport),
    [data],
  );

  const activityByDay = useMemo(() => {
    const now = new Date();
    const days = Array.from({ length: 7 }, (_, index) => {
      const date = new Date(now);
      date.setHours(0, 0, 0, 0);
      date.setDate(date.getDate() - (6 - index));
      return { date, count: 0 };
    });
    for (const event of data?.operations.auditEvents ?? []) {
      const eventDate = new Date(event.createdAt);
      const bucket = days.find(
        (day) => day.date.toDateString() === eventDate.toDateString(),
      );
      if (bucket) bucket.count += 1;
    }
    return days;
  }, [data]);

  const metricCards = data
    ? [
        {
          id: "accounts",
          label: "Registered accounts",
          value: data.summary.totalAccounts,
          detail: "Persisted member accounts",
          icon: Users,
          tone: "rose",
        },
        {
          id: "active",
          label: "Active accounts",
          value: data.summary.activeAccounts,
          detail: "Account status ACTIVE",
          icon: CheckCircle2,
          tone: "green",
        },
        {
          id: "verified",
          label: "Verified accounts",
          value: data.summary.verifiedAccounts,
          detail: "Verification status VERIFIED",
          icon: ShieldCheck,
          tone: "violet",
        },
        {
          id: "pending",
          label: "Pending eligibility reviews",
          value: data.summary.pendingManualReviews,
          detail: "Actual review submissions",
          icon: Clock3,
          tone: "amber",
        },
      ]
    : [];

  const maxActivity = Math.max(1, ...activityByDay.map((item) => item.count));
  const activityPoints = activityByDay.map((item, index) => ({
    ...item,
    x: 34 + index * (532 / Math.max(1, activityByDay.length - 1)),
    y: 154 - (item.count / maxActivity) * 108,
  }));
  const activityPolyline = activityPoints
    .map((point) => `${point.x},${point.y}`)
    .join(" ");
  const activityPolygon = activityPoints.length
    ? `34,172 ${activityPolyline} 566,172`
    : "";

  return (
    <div className="dashboard-page">
      <section className="page-heading">
        <div>
          <div className="eyebrow"><span className="eyebrow-line" /> THE BIG PICTURE</div>
          <h1>Overview dashboard</h1>
          <p>Member, community, and review activity retrieved from the configured Sakhi backend.</p>
        </div>
        <div className="heading-meta">
          {data && <StatusPill tone="green"><span className="status-pill__dot" /> LIVE DATABASE</StatusPill>}
          <button className="button button--secondary" type="button" onClick={() => setRefresh((value) => value + 1)} disabled={loading}>
            <RefreshCw size={14} /> {loading ? "Refreshing..." : "Refresh data"}
          </button>
        </div>
      </section>

      {error && (
        <section className="panel dashboard-state" role="alert">
          <div>
            <AlertCircle size={26} />
            <h2>Live data unavailable</h2>
            <p>{error}</p>
            <p>The page will not substitute fictional counts or sample records.</p>
            <button className="button button--secondary" type="button" onClick={() => setRefresh((value) => value + 1)}>Retry connection</button>
          </div>
        </section>
      )}

      {loading && !data && !error && (
        <section className="panel dashboard-state" aria-busy="true">
          <div><Activity size={24} /><h2>Loading database records</h2><p>Fetching member counts, review submissions, recent audit records, and community totals.</p></div>
        </section>
      )}

      {data && (
        <>
          <section className="primary-metrics" aria-label="Live database metrics">
            {metricCards.map(({ id, label, value, detail, icon: Icon, tone }, index) => (
              <article className={"metric-card metric-card--" + tone} key={id}>
                <div className="metric-card-top">
                  <span className="metric-icon"><Icon size={19} strokeWidth={1.9} /></span>
                  <span className="metric-index">0{index + 1}</span>
                </div>
                <p className="metric-label">{label}</p>
                <div className="metric-value-row"><strong className="metric-value">{value.toLocaleString("en-IN")}</strong></div>
                <div className="metric-card-foot"><span>{detail}</span></div>
              </article>
            ))}
          </section>

          <div className="dashboard-grid dashboard-grid--top">
            <section className="panel activity-panel">
              <div className="panel-heading">
                <div><span className="panel-kicker">RECENT AUDIT ACTIVITY</span><h2>Operational overview</h2><p>Latest database audit events, grouped by day</p></div>
                <StatusPill tone="neutral">UP TO 40 EVENTS</StatusPill>
              </div>
              <div className="chart-legend"><span className="legend-mark" /><span>Events in the latest audit sample</span><span className="legend-spacer" /><span className="chart-info">Not a full analytics history</span></div>
              {(data.operations.auditEvents.length > 0) ? (
                <>
                  <div className="activity-chart" role="img" aria-label="Counts per day for the latest audit events returned by the backend">
                    <svg viewBox="0 0 600 202" preserveAspectRatio="none" aria-hidden="true">
                      <line x1="34" y1="46" x2="566" y2="46" className="audit-chart-grid" />
                      <line x1="34" y1="100" x2="566" y2="100" className="audit-chart-grid" />
                      <line x1="34" y1="154" x2="566" y2="154" className="audit-chart-grid" />
                      <polygon points={activityPolygon} fill="url(#audit-area)" />
                      <defs><linearGradient id="audit-area" x1="0" y1="0" x2="0" y2="1"><stop offset="0%" stopColor="#C44F7E" stopOpacity=".18" /><stop offset="100%" stopColor="#C44F7E" stopOpacity="0" /></linearGradient></defs>
                      <polyline points={activityPolyline} fill="none" stroke="#B94776" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round" />
                      {activityPoints.map((point) => <circle key={point.date.toISOString()} cx={point.x} cy={point.y} r="4" fill="#fff" stroke="#B94776" strokeWidth="2" />)}
                    </svg>
                    <div className="audit-chart-labels">
                      {activityByDay.map((item) => <span key={item.date.toISOString()}>{new Intl.DateTimeFormat("en-IN", { day: "2-digit", month: "short" }).format(item.date)}<strong>{item.count}</strong></span>)}
                    </div>
                  </div>
                  <div className="chart-footer">
                    <div><span className="chart-footer-dot chart-footer-dot--rose" /><span>Returned audit entries</span><strong>{data.operations.auditEvents.length}</strong></div>
                    <div><span className="chart-footer-dot chart-footer-dot--violet" /><span>Community posts</span><strong>{data.operations.counts.totalPosts.toLocaleString("en-IN")}</strong></div>
                    <div><span className="chart-footer-dot chart-footer-dot--amber" /><span>Review queue</span><strong>{data.queue.length.toLocaleString("en-IN")}</strong></div>
                  </div>
                </>
              ) : (
                <div className="dashboard-empty-state"><Activity size={25} /><strong>No audit activity returned</strong><span>The backend has not returned any audit records for this view.</span></div>
              )}
              <div className="audit-activity-list">
                {data.operations.auditEvents.slice(0, 4).map((event) => (
                  <div className="audit-activity-row" key={event.id}>
                    <span className="audit-activity-icon"><ShieldCheck size={15} /></span>
                    <span className="audit-activity-copy"><strong>{titleFromAction(event.action)}</strong><small>{event.actorType} · {event.outcome}{event.targetType ? " · " + event.targetType : ""}</small></span>
                    <time>{formatDateTime(event.createdAt)}</time>
                  </div>
                ))}
              </div>
            </section>

            <section className="panel attention-panel">
              <div className="panel-heading">
                <div><span className="panel-kicker">PRIORITY QUEUE</span><h2>Needs attention</h2><p>Open requests returned by the backend</p></div>
                <span className="attention-count">{String(data.queue.length + recentReports.length).padStart(2, "0")}</span>
              </div>
              <div className="attention-list">
                {data.queue.slice(0, 4).map((item) => (
                  <Link className="attention-item" to="/verification" key={item.submissionId}>
                    <span className="attention-icon attention-icon--amber"><Clock3 size={17} /></span>
                    <span className="attention-copy"><strong>{item.displayName}</strong><small>Eligibility review · {item.reference}</small><span className="attention-age"><Clock3 size={12} /> Submitted {formatDate(item.submittedAt)}</span></span>
                    <ArrowRight className="attention-arrow" size={16} />
                  </Link>
                ))}
                {recentReports.slice(0, 3).map((report) => (
                  <Link className="attention-item" to="/moderation" key={report.id}>
                    <span className="attention-icon attention-icon--rose"><MessageSquareWarning size={17} /></span>
                    <span className="attention-copy"><strong>{report.category || "Member report"}</strong><small>{report.targetType} · {report.targetHandle || "Member content"}</small><span className="attention-age"><Clock3 size={12} /> {formatDate(report.createdAt)} · {report.status}</span></span>
                    <ArrowRight className="attention-arrow" size={16} />
                  </Link>
                ))}
                {data.queue.length === 0 && recentReports.length === 0 && <div className="dashboard-empty-state dashboard-empty-state--compact"><CheckCircle2 size={22} /><strong>No open items in the loaded queues</strong><span>No pending review submissions or open reports were returned.</span></div>}
              </div>
              <Link className="panel-link" to="/verification">Open eligibility review queue <ArrowRight size={15} /></Link>
            </section>
          </div>

          <section className="panel indicator-panel">
            <div className="panel-heading panel-heading--compact">
              <div><span className="panel-kicker">PLATFORM SNAPSHOT</span><h2>Other key indicators</h2></div>
              <span className="panel-subnote">Persisted values and bounded recent-record samples</span>
            </div>
            <div className="indicator-grid">
              {[
                { id: "members", title: "Database accounts", value: data.operations.counts.totalAccounts, detail: "All persisted accounts", icon: Users, route: "/members" },
                { id: "content", title: "Community posts", value: data.operations.counts.totalPosts, detail: "Persisted post records", icon: Newspaper, route: "/community" },
                { id: "groups", title: "Community groups", value: data.operations.counts.totalGroups, detail: "Persisted groups", icon: UsersRound, route: "/community" },
                { id: "reports", title: "Recent report records", value: data.operations.reports.length, detail: "Latest reports returned, up to 30", icon: FileWarning, route: "/moderation" },
                { id: "media", title: "Recent media audit records", value: data.operations.mediaUploads.length, detail: "Latest media events returned, up to 30", icon: Camera, route: "/community" },
              ].map((item) => (
                <Link className="indicator-item" to={item.route} key={item.id}>
                  <span className="indicator-icon"><item.icon size={16} /></span>
                  <span className="indicator-copy"><span>{item.title}</span><strong>{item.value.toLocaleString("en-IN")}</strong><small>{item.detail}</small></span>
                  <ArrowRight className="indicator-arrow" size={14} />
                </Link>
              ))}
            </div>
          </section>

          <div className="dashboard-grid dashboard-grid--bottom">
            <section className="panel queue-panel">
              <div className="panel-heading">
                <div><span className="panel-kicker">LIVE REVIEW SUBMISSIONS</span><h2>Eligibility items</h2><p>Actual pending manual-review submissions only</p></div>
                <StatusPill tone="amber">{data.queue.length} PENDING</StatusPill>
              </div>
              <div className="table-scroll">
                <table className="operations-table">
                  <thead><tr><th>Member / reference</th><th>Mobile</th><th>Submitted</th><th>Status</th><th aria-label="Open item" /></tr></thead>
                  <tbody>
                    {data.queue.length === 0 && <tr><td colSpan={5} className="member-empty-cell">No pending eligibility submissions were returned by the backend.</td></tr>}
                    {data.queue.slice(0, 8).map((item) => (
                      <tr key={item.submissionId}>
                        <td><span className="table-ref">{item.displayName}</span><span className="table-category">{item.reference}</span></td>
                        <td><span className="table-owner">{item.phoneMasked}</span></td>
                        <td><span className="table-age">{formatDate(item.submittedAt)}</span></td>
                        <td><StatusPill tone="amber">Pending review</StatusPill></td>
                        <td><Link className="table-open" to="/verification" aria-label={"Review " + item.reference}><ArrowRight size={15} /></Link></td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
              <div className="table-note"><ShieldCheck size={14} /><span>Queue entries come from persisted eligibility submissions; profile consent alone does not create a review request.</span></div>
            </section>

            <section className="panel integrations-panel">
              <div className="panel-heading">
                <div><span className="panel-kicker">CONNECTION DETAILS</span><h2>Backend and storage</h2><p>Status from completed API requests and configuration</p></div>
                <StatusPill tone="green">API RESPONDING</StatusPill>
              </div>
              <div className="integration-list">
                <div className="integration-row"><span className="integration-status-icon"><CheckCircle2 size={16} /></span><span className="integration-copy"><strong>Sakhi backend</strong><small>Member, review, and operations endpoints responded successfully.</small></span><StatusPill tone="green">Ready</StatusPill></div>
                <div className="integration-row"><span className="integration-status-icon"><ShieldCheck size={16} /></span><span className="integration-copy"><strong>Database-backed admin data</strong><small>Counts and records came from the configured API.</small></span><StatusPill tone="green">Loaded</StatusPill></div>
                <div className="integration-row"><span className="integration-status-icon"><Camera size={16} /></span><span className="integration-copy"><strong>Media provider setting</strong><small>{data.operations.cloudStorage.provider || "No provider configured"}</small></span><StatusPill tone="neutral">Configured</StatusPill></div>
                <div className="integration-row"><span className="integration-status-icon"><Activity size={16} /></span><span className="integration-copy"><strong>Audit trail</strong><small>Latest events returned: {data.operations.auditEvents.length} (maximum 40).</small></span><StatusPill tone="neutral">Recent records</StatusPill></div>
              </div>
              <div className="table-note"><AlertCircle size={14} /><span>Cloud media upload reachability is not proven by configuration alone; confirm it with an actual upload during staging smoke tests.</span></div>
            </section>
          </div>

          <RegistrationPolicyPanel />

          <div className="dashboard-footnote"><ShieldCheck size={15} /><span>Staging/dev-test workspace. These controls do not represent a production authorization system or a final eligibility policy.</span><Link to="/members">Manage member records <ArrowRight size={13} /></Link></div>
        </>
      )}
    </div>
  );
}
