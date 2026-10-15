import {
  Activity,
  ArrowDownRight,
  ArrowRight,
  ArrowUpRight,
  Building2,
  CircleAlert,
  Clock3,
  FileWarning,
  Flag,
  HeartPulse,
  MessageSquareWarning,
  ShieldAlert,
  ShieldCheck,
  Siren,
  Users,
  UserRoundCheck,
  type LucideIcon,
} from "lucide-react";
import { Link } from "react-router-dom";
import { StatusPill } from "../components/StatusPill";
import {
  attentionItems,
  dashboardIndicators,
  dashboardMetrics,
  demoDataNotice,
  integrationPlaceholders,
  queueRows,
  weeklyTrend,
} from "../services/mock/dashboard";
import type { DashboardMetric, MetricTone } from "../types/admin";

const metricIconMap: Record<DashboardMetric["icon"], LucideIcon> = {
  members: Users,
  verified: ShieldCheck,
  pending: Clock3,
  activity: Activity,
};

const indicatorIcons: Record<string, LucideIcon> = {
  businesses: Building2,
  content: Flag,
  complaints: MessageSquareWarning,
  sos: Siren,
  media: HeartPulse,
  closed: ShieldCheck,
  failures: UserRoundCheck,
  alerts: CircleAlert,
};

export function DashboardPage() {
  return (
    <div className="dashboard-page">
      <section className="page-heading">
        <div>
          <div className="eyebrow"><span className="eyebrow-line" /> THE BIG PICTURE</div>
          <h1>Overview dashboard</h1>
          <p>See the activity, review queues and operational work that needs attention.</p>
        </div>
        <div className="heading-meta">
          <div className="date-chip"><span className="date-chip__dot" /> Sample period <strong>Last 30 days</strong></div>
          <span className="sample-caption">Illustrative data only</span>
        </div>
      </section>

      <section className="primary-metrics" aria-label="Primary sample metrics">
        {dashboardMetrics.map((metric, index) => {
          const Icon = metricIconMap[metric.icon];
          const DeltaIcon = metric.direction === "down" ? ArrowDownRight : ArrowUpRight;
          return (
            <article className={"metric-card metric-card--" + metric.tone} key={metric.id}>
              <div className="metric-card-top">
                <span className="metric-icon"><Icon size={19} strokeWidth={1.9} /></span>
                <span className="metric-index">0{index + 1}</span>
              </div>
              <p className="metric-label">{metric.label}</p>
              <div className="metric-value-row"><strong className="metric-value">{metric.value}</strong></div>
              <div className="metric-card-foot">
                <span>{metric.detail}</span>
                {metric.delta && <span className={"metric-delta metric-delta--" + (metric.direction ?? "neutral")}>{metric.direction === "neutral" ? <Clock3 size={12} /> : <DeltaIcon size={13} />}{metric.delta}</span>}
              </div>
            </article>
          );
        })}
      </section>

      <div className="dashboard-grid dashboard-grid--top">
        <section className="panel activity-panel">
          <div className="panel-heading">
            <div><span className="panel-kicker">MEMBER ACTIVITY</span><h2>Engagement overview</h2><p>Sample relative activity across seven days</p></div>
            <StatusPill tone="demo">SAMPLE</StatusPill>
          </div>
          <div className="chart-legend"><span className="legend-mark" /> <span>Illustrative member activity</span><span className="legend-spacer" /><span className="chart-info">No live analytics connected</span></div>
          <ActivityChart />
          <div className="chart-footer">
            <div><span className="chart-footer-dot chart-footer-dot--rose" /><span>Registrations</span><strong>1,284</strong></div>
            <div><span className="chart-footer-dot chart-footer-dot--violet" /><span>Active members</span><strong>6,280</strong></div>
            <div><span className="chart-footer-dot chart-footer-dot--amber" /><span>Verification started</span><strong>438</strong></div>
          </div>
        </section>

        <section className="panel attention-panel">
          <div className="panel-heading">
            <div><span className="panel-kicker">PRIORITY QUEUE</span><h2>Needs attention</h2><p>Example operational follow-ups</p></div>
            <span className="attention-count">03</span>
          </div>
          <div className="attention-list">
            {attentionItems.map((item) => {
              const Icon = item.icon === "verification" ? UserRoundCheck : item.icon === "report" ? FileWarning : ShieldAlert;
              return (
                <Link className="attention-item" to={item.route} key={item.id}>
                  <span className={"attention-icon attention-icon--" + item.severity}><Icon size={17} /></span>
                  <span className="attention-copy"><strong>{item.title}</strong><small>{item.description}</small><span className="attention-age"><Clock3 size={12} /> {item.age}</span></span>
                  <ArrowRight className="attention-arrow" size={16} />
                </Link>
              );
            })}
          </div>
          <Link className="panel-link" to="/action-center">View action center <ArrowRight size={15} /></Link>
        </section>
      </div>

      <section className="panel indicator-panel">
        <div className="panel-heading panel-heading--compact">
          <div><span className="panel-kicker">PLATFORM SNAPSHOT</span><h2>Other key indicators</h2></div>
          <span className="panel-subnote">All values are fictional</span>
        </div>
        <div className="indicator-grid">
          {dashboardIndicators.map((item) => {
            const Icon = indicatorIcons[item.id] ?? CircleAlert;
            const route = item.id === "businesses" ? "/businesses" : item.id === "content" ? "/moderation" : item.id === "complaints" || item.id === "closed" ? "/complaints" : item.id === "sos" ? "/emergency" : item.id === "failures" ? "/verification" : item.id === "media" ? "/community" : "/integrations";
            return (
              <Link className="indicator-item" to={route} key={item.id}>
                <span className="indicator-icon"><Icon size={16} /></span>
                <span className="indicator-copy"><span>{item.label}</span><strong>{item.value}</strong><small>{item.detail}</small></span>
                <ArrowUpRight className="indicator-arrow" size={14} />
              </Link>
            );
          })}
        </div>
      </section>

      <div className="dashboard-grid dashboard-grid--bottom">
        <section className="panel queue-panel">
          <div className="panel-heading">
            <div><span className="panel-kicker">SAMPLE WORK QUEUE</span><h2>Operational items</h2><p>Fictional examples of review work</p></div>
            <StatusPill tone="demo">DEMO</StatusPill>
          </div>
          <div className="table-scroll">
            <table className="operations-table">
              <thead><tr><th>Reference / category</th><th>Assigned team</th><th>Status</th><th>Age</th><th aria-label="Open item" /></tr></thead>
              <tbody>
                {queueRows.map((row) => (
                  <tr key={row.id}>
                    <td><span className="table-ref">{row.reference}</span><span className="table-category">{row.category}</span></td>
                    <td><span className="table-owner">{row.owner}</span></td>
                    <td><StatusPill tone={row.severity === "urgent" ? "urgent" : row.severity === "high" ? "amber" : "neutral"}>{row.status}</StatusPill></td>
                    <td><span className="table-age">{row.age}</span></td>
                    <td><Link className="table-open" to={row.route} aria-label={"Open planned workflow for " + row.reference}><ArrowRight size={15} /></Link></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <div className="table-note"><CircleAlert size={14} /><span>These queue entries are examples and are not assigned to real staff.</span></div>
        </section>

        <section className="panel integrations-panel">
          <div className="panel-heading">
            <div><span className="panel-kicker">DEPENDENCIES</span><h2>Integration status</h2><p>Connection setup has not started</p></div>
            <StatusPill tone="neutral">4 NOT CONNECTED</StatusPill>
          </div>
          <div className="integration-list">
            {integrationPlaceholders.map((item) => (
              <div className="integration-row" key={item.id}>
                <span className="integration-status-icon"><CircleAlert size={16} /></span>
                <span className="integration-copy"><strong>{item.name}</strong><small>{item.description}</small></span>
                <StatusPill tone="neutral">Not connected</StatusPill>
              </div>
            ))}
          </div>
          <Link className="panel-link" to="/integrations">Integration setup <ArrowRight size={15} /></Link>
        </section>
      </div>

      <div className="dashboard-footnote"><ShieldCheck size={15} /><span>{demoDataNotice}</span><Link to="/settings">About this environment <ArrowRight size={13} /></Link></div>
    </div>
  );
}

function ActivityChart() {
  const points = weeklyTrend.map((point, index) => ({
    ...point,
    x: 34 + index * (532 / (weeklyTrend.length - 1)),
    y: 154 - ((point.value - 20) / 70) * 108,
  }));
  const polyline = points.map((point) => point.x + "," + point.y).join(" ");
  const polygon = "34,172 " + polyline + " 566,172";

  return (
    <div className="activity-chart" role="img" aria-label="Illustrative member activity chart for seven days. Sample values only.">
      <svg viewBox="0 0 600 202" preserveAspectRatio="none" aria-hidden="true">
        <defs>
          <linearGradient id="activity-area" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor="#C44F7E" stopOpacity=".19" />
            <stop offset="100%" stopColor="#C44F7E" stopOpacity="0" />
          </linearGradient>
        </defs>
        {[46, 82, 118, 154].map((y) => <line key={y} x1="34" y1={y} x2="566" y2={y} stroke="#EEE8EF" strokeDasharray="3 5" />)}
        <polygon points={polygon} fill="url(#activity-area)" />
        <polyline points={polyline} fill="none" stroke="#BC4D7A" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" />
        {points.map((point) => <circle key={point.label} cx={point.x} cy={point.y} r="3.5" fill="#FFFFFF" stroke="#BC4D7A" strokeWidth="2" />)}
        {points.map((point) => <text key={point.label + "-label"} x={point.x} y="193" fontSize="11" fill="#958A98" textAnchor="middle">{point.label}</text>)}
      </svg>
    </div>
  );
}

export function MetricTrendIcon({ direction }: { direction?: DashboardMetric["direction"] }) {
  if (direction === "down") return <ArrowDownRight size={13} />;
  if (direction === "up") return <ArrowUpRight size={13} />;
  return <Clock3 size={12} />;
}

export function ToneLabel({ tone }: { tone: MetricTone }) {
  return <span className={"tone-label tone-label--" + tone}>{tone}</span>;
}