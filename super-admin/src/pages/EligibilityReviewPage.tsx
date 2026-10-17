import { useCallback, useEffect, useState } from "react";
import { AlertTriangle, CheckCircle2, Clock3, RefreshCw, ShieldCheck, XCircle } from "lucide-react";
import { useNavigate } from "react-router-dom";
import { StatusPill } from "../components/StatusPill";
import { adminAuthService } from "../services/auth/adminAuthService";
import { adminApi, AdminApiError } from "../services/api/adminApi";

type ReviewAccount = {
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
type ReviewHistoryItem = {
  id: string;
  targetId: string | null;
  submissionId?: string | null;
  action: string;
  outcome: string;
  createdAt: string;
  reviewerLabel: string;
  reason: string;
};
type ReviewDecision = "approve" | "reject";

function formatDate(value: string | null | undefined): string {
  if (!value) return "Not available";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "Not available";
  return new Intl.DateTimeFormat("en-IN", { day: "2-digit", month: "short", year: "numeric" }).format(date);
}
function formatDateTime(value: string | null | undefined): string {
  if (!value) return "Not available";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "Not available";
  return new Intl.DateTimeFormat("en-IN", { day: "2-digit", month: "short", year: "numeric", hour: "2-digit", minute: "2-digit" }).format(date);
}

export function EligibilityReviewPage() {
  const navigate = useNavigate();
  const [queue, setQueue] = useState<ReviewAccount[]>([]);
  const [history, setHistory] = useState<ReviewHistoryItem[]>([]);
  const [selected, setSelected] = useState<ReviewAccount | null>(null);
  const [decision, setDecision] = useState<ReviewDecision | null>(null);
  const [reason, setReason] = useState("");
  const [evidenceAttested, setEvidenceAttested] = useState(false);
  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");

  const load = useCallback(async () => {
    try {
      const [nextQueue, nextHistory] = await Promise.all([
        adminApi<ReviewAccount[]>("/admin-review/queue"),
        adminApi<ReviewHistoryItem[]>("/admin-review/history"),
      ]);
      setQueue(nextQueue);
      setHistory(nextHistory);
    } catch (cause) {
      if (cause instanceof AdminApiError && cause.statusCode === 401) {
        adminAuthService.signOut();
        navigate("/login", { replace: true });
        return;
      }
      setError(cause instanceof Error ? cause.message : "Could not load the manual review queue.");
    } finally {
      setLoading(false);
    }
  }, [navigate]);

  useEffect(() => {
    let active = true;
    async function loadInitialData() {
      try {
        const [nextQueue, nextHistory] = await Promise.all([
          adminApi<ReviewAccount[]>("/admin-review/queue"),
          adminApi<ReviewHistoryItem[]>("/admin-review/history"),
        ]);
        if (!active) return;
        setQueue(nextQueue);
        setHistory(nextHistory);
      } catch (cause) {
        if (!active) return;
        if (cause instanceof AdminApiError && cause.statusCode === 401) {
          adminAuthService.signOut();
          navigate("/login", { replace: true });
          return;
        }
        setError(cause instanceof Error ? cause.message : "Could not load the manual review queue.");
      } finally {
        if (active) setLoading(false);
      }
    }
    void loadInitialData();
    return () => { active = false; };
  }, [navigate]);

  function beginDecision(account: ReviewAccount, nextDecision: ReviewDecision) {
    setSelected(account);
    setDecision(nextDecision);
    setReason("");
    setEvidenceAttested(false);
    setError("");
    setNotice("");
  }

  async function submitDecision() {
    if (!selected || !decision || !evidenceAttested || reason.trim().length < 10) return;
    setSubmitting(true);
    setError("");
    try {
      const result = await adminApi<{ status: string; decision: string }>(`/admin-review/submissions/${selected.submissionId}/decision`, {
        method: "POST",
        body: { decision, reason: reason.trim(), reviewedEvidence: true },
      });
      setNotice(result.decision === "approve" ? "Manual review approval was persisted." : "Manual review rejection was persisted.");
      setSelected(null);
      setDecision(null);
      await load();
    } catch (cause) {
      if (cause instanceof AdminApiError && cause.statusCode === 401) {
        adminAuthService.signOut();
        navigate("/login", { replace: true });
        return;
      }
      setError(cause instanceof Error ? cause.message : "The decision could not be saved.");
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <div className="eligibility-review-page">
      <div className="page-heading">
        <div><div className="eyebrow"><span className="eyebrow-line" /> PEOPLE &amp; TRUST</div><h1>Eligibility review</h1><p>Review explicitly submitted cases and record a reasoned manual decision.</p></div>
        <button type="button" className="button button--secondary" onClick={() => { setLoading(true); setError(""); void load(); }} disabled={loading}><RefreshCw size={15} /> Refresh queue</button>
      </div>

      <div className="eligibility-review-warning" role="note"><AlertTriangle size={19} /><div><strong>Evidence is not stored in this portal</strong><p>This local dev/test workflow records manual-review requests and decisions only. It does not capture, upload, store, or display selfies or identity documents. Before deciding, reviewers must follow the separately approved evidence procedure configured for this deployment. Never infer eligibility from a face, name, or profile fields alone.</p></div></div>

      {notice && <div className="eligibility-review-notice" role="status"><CheckCircle2 size={17} />{notice}</div>}
      {error && <div className="eligibility-review-error" role="alert"><XCircle size={17} />{error}</div>}

      <section className="member-summary" aria-label="Eligibility review summary">
        <article className="member-summary-card member-summary-card--amber"><span className="member-summary-icon"><Clock3 size={18} /></span><span className="member-summary-copy"><small>Awaiting manual decision</small><strong>{queue.length}</strong></span></article>
        <article className="member-summary-card member-summary-card--green"><span className="member-summary-icon"><ShieldCheck size={18} /></span><span className="member-summary-copy"><small>Decision records loaded</small><strong>{history.length}</strong></span></article>
      </section>

      <section className="panel eligibility-review-panel">
        <div className="member-directory-heading"><div><span className="panel-kicker">REVIEW QUEUE</span><h2>Pending submissions</h2><p>Only cases with an explicit manual-review submission and consent are shown.</p></div><StatusPill tone="demo">DEV / TEST</StatusPill></div>
        {loading ? <div className="member-directory-state" aria-busy="true"><span className="dashboard-loading-mark"><Clock3 size={22} /></span><h3>Loading review queue</h3><p>Fetching pending submissions from the backend.</p></div> : queue.length === 0 ? <div className="member-directory-state"><CheckCircle2 size={25} /><h3>No pending submissions</h3><p>No explicit manual-review requests were returned by the backend.</p></div> : (
          <div className="member-table-scroll"><table className="member-table"><thead><tr><th>Member</th><th>Masked phone</th><th>Date of birth</th><th>Registered</th><th>Review requested</th><th>Manual consent</th><th /></tr></thead><tbody>{queue.map((item) => <tr key={item.submissionId}><td><div className="member-identity-copy"><strong>{item.displayName}</strong><small>{item.reference}</small></div></td><td>{item.phoneMasked}</td><td>{formatDate(item.dateOfBirth)}</td><td>{formatDate(item.registeredAt)}</td><td>{formatDateTime(item.submittedAt)}</td><td>{item.manualReviewConsent.version}<br /><small>{formatDateTime(item.manualReviewConsent.acceptedAt)}</small></td><td><button type="button" className="button button--secondary eligibility-review-open" onClick={() => beginDecision(item, "approve")}>Review case</button></td></tr>)}</tbody></table></div>
        )}
      </section>

      {selected && decision && <div className="member-modal-overlay" role="presentation"><section className="member-action-modal eligibility-review-modal" role="dialog" aria-modal="true" aria-labelledby="eligibility-decision-title"><div className="member-modal-heading"><span className="member-modal-icon member-modal-icon--warning"><ShieldCheck size={20} /></span><button className="member-modal-close" type="button" disabled={submitting} onClick={() => { setSelected(null); setDecision(null); }} aria-label="Close review">X</button></div><div className="member-modal-kicker">MANUAL ELIGIBILITY DECISION</div><h2 id="eligibility-decision-title">Review {selected.displayName}</h2><dl className="eligibility-review-details"><div><dt>Member reference</dt><dd>{selected.reference}</dd></div><div><dt>Masked phone</dt><dd>{selected.phoneMasked}</dd></div><div><dt>Date of birth</dt><dd>{formatDate(selected.dateOfBirth)}</dd></div><div><dt>Masked email</dt><dd>{selected.emailMasked}</dd></div><div><dt>Manual-review consent</dt><dd>{selected.manualReviewConsent.version} - {formatDateTime(selected.manualReviewConsent.acceptedAt)}</dd></div><div><dt>Submission ID</dt><dd>{selected.submissionId}</dd></div></dl><label className="eligibility-review-attestation"><input type="checkbox" checked={evidenceAttested} onChange={(event) => setEvidenceAttested(event.target.checked)} /><span>I followed the separately approved evidence procedure and reviewed the required evidence outside this portal. I am not deciding from profile fields alone.</span></label><label className="member-form-label" htmlFor="eligibility-decision-reason">Decision reason <span>Required: 10-500 characters</span></label><textarea id="eligibility-decision-reason" rows={4} maxLength={500} minLength={10} value={reason} onChange={(event) => setReason(event.target.value)} placeholder="Record a non-sensitive rationale for this decision." /><div className="member-form-helper"><span>Do not include identity documents or unnecessary sensitive details.</span><span>{reason.length}/500</span></div>{error && <p className="admin-review-error" role="alert">{error}</p>}<div className="eligibility-review-decision-buttons"><button type="button" className="button button--secondary" disabled={submitting} onClick={() => setDecision(decision === "reject" ? "approve" : "reject")}>{decision === "reject" ? "Switch to approval" : "Choose rejection"}</button><button type="button" className="button button--primary" disabled={submitting || !evidenceAttested || reason.trim().length < 10} onClick={() => void submitDecision()}>{submitting ? "Saving..." : decision === "reject" ? "Confirm rejection" : "Confirm approval"}</button></div>{decision === "reject" && <p className="admin-review-help">Rejection will be persisted. A resubmission/appeal workflow is not implemented in this stage.</p>}</section></div>}

      <section className="panel eligibility-review-panel eligibility-review-history"><div className="member-directory-heading"><div><span className="panel-kicker">AUDIT</span><h2>Recent manual decisions</h2><p>Decision history is persisted by the backend.</p></div></div>{history.length === 0 ? <div className="member-audit-empty"><Clock3 size={18} /><span>No manual decisions have been recorded yet.</span></div> : <div className="member-table-scroll"><table className="member-table"><thead><tr><th>Decision</th><th>Member account ID</th><th>Reviewer</th><th>Reason</th><th>Recorded</th></tr></thead><tbody>{history.map((item) => <tr key={item.id}><td><StatusPill tone={item.outcome === "approve" ? "green" : "urgent"}>{item.outcome.toUpperCase()}</StatusPill></td><td>{item.targetId ?? "Unavailable"}</td><td>{item.reviewerLabel}</td><td>{item.reason}</td><td>{formatDateTime(item.createdAt)}</td></tr>)}</tbody></table></div>}</section>
    </div>
  );
}
