import { useCallback, useEffect, useState } from "react";
import { CheckCircle2, MessageSquareText, RefreshCw, ShieldAlert } from "lucide-react";
import { StatusPill } from "../components/StatusPill";
import { adminApi, API_BASE_URL } from "../services/api/adminApi";

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
  reports: Array<{
    id: string;
    targetHandle: string;
    targetType?: string;
    postId?: string | null;
    reason: string;
    details?: string | null;
    status: string;
    createdAt: string;
  }>;
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

export function ModerationPage({ section = "moderation" }: { section?: string }) {
  const [data, setData] = useState<OperationsPayload | null>(null);
  const [driveStatus, setDriveStatus] = useState<Record<string, unknown> | null>(null);
  const [loading, setLoading] = useState(true);
  const [notice, setNotice] = useState("");
  const [error, setError] = useState("");
  const [reviewerComments, setReviewerComments] = useState<Record<string, string>>({});

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
      setNotice(`Report ${reportId.slice(0, 8)} resolved with ${actionType}.`);
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not resolve report.");
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
                  : "Trust & Safety Moderation Queue"}
          </h1>
          <p>Confidential member reports, reviewer decision notes, SOS telemetry, and Google Drive hierarchy health.</p>
        </div>
        <div className="heading-meta">
          <StatusPill tone="green">CONFIDENTIAL QUEUE</StatusPill>
          <button className="button button--secondary" type="button" onClick={() => void load()} disabled={loading}>
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
                <span className="panel-kicker">SRS SECTION 5.4</span>
                <h2>Confidential Content &amp; Member Reports ({data.reports.length})</h2>
                <p>Reporter identities remain strictly confidential and are never exposed to the reported member.</p>
              </div>
              <ShieldAlert size={20} />
            </div>
            <div className="table-scroll">
              <table className="operations-table">
                <thead>
                  <tr>
                    <th>Target</th>
                    <th>Reason &amp; Details</th>
                    <th>Status</th>
                    <th>Submitted</th>
                    <th>Reviewer Comment &amp; Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {data.reports.length === 0 && (
                    <tr>
                      <td colSpan={5} className="member-empty-cell">
                        No open moderation reports in the queue.
                      </td>
                    </tr>
                  )}
                  {data.reports.map((rep) => (
                    <tr key={rep.id}>
                      <td>
                        <strong>{rep.targetHandle}</strong>
                        {rep.targetType && (
                          <div style={{ fontSize: 11.5, color: "#6E6275" }}>
                            Type: {rep.targetType}
                          </div>
                        )}
                      </td>
                      <td>
                        <div>{rep.reason}</div>
                        {rep.details && (
                          <small style={{ color: "#6E6275", display: "block", marginTop: 2 }}>
                            {rep.details}
                          </small>
                        )}
                      </td>
                      <td>
                        <StatusPill tone={rep.status === "SUBMITTED" ? "amber" : "green"}>{rep.status}</StatusPill>
                      </td>
                      <td>{new Date(rep.createdAt).toLocaleString("en-IN")}</td>
                      <td>
                        <div style={{ display: "flex", flexDirection: "column", gap: 8, minWidth: 260 }}>
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
                          <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
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
                              onClick={() => void resolveReport(rep.id, "SUSPEND_MEMBER")}
                            >
                              Suspend Member
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
                  ))}
                </tbody>
              </table>
            </div>
          </section>

          <section className="panel queue-panel" style={{ marginBottom: 20 }}>
            <div className="panel-heading">
              <div>
                <span className="panel-kicker">EMERGENCY TELEMETRY</span>
                <h2>SOS &amp; Safety Check-In Events ({data.sosEvents.length})</h2>
                <p>Live emergency dispatches and safety check-in records from Module 4.</p>
              </div>
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
