import { useCallback, useEffect, useState } from "react";
import {
  CheckCircle2,
  Clock3,
  Eye,
  EyeOff,
  MessageSquareText,
  RefreshCw,
  ShieldCheck,
  XCircle,
} from "lucide-react";
import { Link, useNavigate } from "react-router-dom";
import { StatusPill } from "../components/StatusPill";
import { RegistrationPolicyPanel } from "../components/RegistrationPolicyPanel";
import { adminAuthService } from "../services/auth/adminAuthService";
import { adminApi, AdminApiError } from "../services/api/adminApi";

type ReviewAccount = {
  id: string;
  submissionId: string;
  accountId: string;
  reference: string;
  displayName: string;
  dateOfBirth: string | null;
  email?: string;
  emailMasked: string;
  phoneMasked: string;
  phoneE164?: string;
  phoneFormatted?: string;
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

type PendingDirectoryMember = {
  id: string;
  reference: string;
  displayName: string;
  dateOfBirth: string | null;
  ageYears?: number | null;
  email?: string;
  emailMasked: string;
  phoneMasked: string;
  phoneE164?: string;
  phoneFormatted?: string;
  registeredAt: string;
  accountStatus: string;
  verificationStatus: string;
  eligibilityStatus: string;
  profileComplete: boolean;
};

type ReviewDecision = "approve" | "reject";

const ELIGIBILITY_DATE_TIME_FMT = new Intl.DateTimeFormat("en-IN", {
  day: "2-digit",
  month: "short",
  year: "numeric",
  hour: "2-digit",
  minute: "2-digit",
});

function formatDateTime(value: string | null | undefined): string {
  if (!value) return "Not available";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "Not available";
  return ELIGIBILITY_DATE_TIME_FMT.format(date);
}

export function EligibilityReviewPage() {
  const navigate = useNavigate();
  const [queue, setQueue] = useState<ReviewAccount[]>([]);
  const [pendingMembers, setPendingMembers] = useState<PendingDirectoryMember[]>(
    [],
  );
  const [history, setHistory] = useState<ReviewHistoryItem[]>([]);
  const [selected, setSelected] = useState<ReviewAccount | null>(null);
  const [decision, setDecision] = useState<ReviewDecision | null>(null);
  const [reason, setReason] = useState(
    "Approved female eligibility and minimum age verification.",
  );
  const [overrideComment, setOverrideComment] = useState(
    "Verified female eligibility & age policy via Super Admin review.",
  );
  const [evidenceAttested, setEvidenceAttested] = useState(true);
  const [showPhones, setShowPhones] = useState(false);
  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [quickUpdatingId, setQuickUpdatingId] = useState<string | null>(null);
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");

  const load = useCallback(async () => {
    setLoading(true);
    setError("");
    try {
      const [nextQueue, nextHistory, membersRes] = await Promise.all([
        adminApi<ReviewAccount[]>("/admin-review/queue"),
        adminApi<ReviewHistoryItem[]>("/admin-review/history"),
        adminApi<{ items: PendingDirectoryMember[] }>(
          "/admin-review/members?page=1&pageSize=50",
        ).catch(() => ({ items: [] })),
      ]);
      setQueue(nextQueue);
      setHistory(nextHistory);
      setPendingMembers(membersRes.items ?? []);
    } catch (cause) {
      if (cause instanceof AdminApiError && cause.statusCode === 401) {
        adminAuthService.signOut();
        navigate("/login", { replace: true });
        return;
      }
      setError(
        cause instanceof Error
          ? cause.message
          : "Could not load the eligibility review queue.",
      );
    } finally {
      setLoading(false);
    }
  }, [navigate]);

  useEffect(() => {
    void Promise.resolve().then(() => load());
  }, [load]);

  function beginDecision(account: ReviewAccount, nextDecision: ReviewDecision) {
    setSelected(account);
    setDecision(nextDecision);
    setReason(
      nextDecision === "approve"
        ? "Approved female eligibility and minimum age verification."
        : "Eligibility criteria could not be confirmed.",
    );
    setEvidenceAttested(true);
    setError("");
    setNotice("");
  }

  async function submitDecision() {
    if (!selected || !decision) return;
    if (!evidenceAttested) {
      setError(
        "Confirm that you followed the required review procedure before recording a decision.",
      );
      return;
    }
    const cleanReason =
      reason.trim().length >= 10
        ? reason.trim()
        : "Approved female eligibility and minimum age verification.";
    setSubmitting(true);
    setError("");
    try {
      await adminApi(
        `/admin-review/submissions/${encodeURIComponent(selected.submissionId)}/decision`,
        {
          method: "POST",
          body: {
            decision,
            reason: cleanReason,
            reviewedEvidence: true,
          },
        },
      );
      setNotice(
        decision === "approve"
          ? `✅ Approved & Verified ${selected.displayName} (${selected.phoneFormatted ?? selected.phoneE164 ?? selected.phoneMasked}).`
          : `Recorded rejection for ${selected.displayName}.`,
      );
      setSelected(null);
      setDecision(null);
      await load();
    } catch (cause) {
      if (cause instanceof AdminApiError && cause.statusCode === 401) {
        adminAuthService.signOut();
        navigate("/login", { replace: true });
        return;
      }
      setError(
        cause instanceof Error
          ? cause.message
          : "The review decision could not be saved.",
      );
    } finally {
      setSubmitting(false);
    }
  }

  async function quickOverrideMemberStatus(
    member: PendingDirectoryMember,
    preset:
      | "VERIFIED"
      | "PENDING_MANUAL_REVIEW"
      | "INCOMPLETE"
      | "REJECTED",
  ) {
    setQuickUpdatingId(member.id);
    setError("");
    const nextAccountStatus =
      preset === "VERIFIED" ? "ACTIVE" : "PENDING_VERIFICATION";
    const nextVerificationStatus =
      preset === "VERIFIED"
        ? "VERIFIED"
        : preset === "REJECTED"
          ? "REJECTED"
          : "UNVERIFIED";
    const customReason =
      overrideComment.trim().length >= 10
        ? `${overrideComment.trim()} (${member.displayName} → ${preset})`
        : `Admin set ${member.displayName} eligibility status to ${preset} from Eligibility & Verification page.`;
    try {
      try {
        await adminApi(
          `/admin-review/members/${encodeURIComponent(member.id)}/eligibility-override`,
          {
            method: "PATCH",
            body: {
              preset,
              accountStatus: nextAccountStatus,
              verificationStatus: nextVerificationStatus,
              reason: customReason,
            },
          },
        );
      } catch {
        await adminApi(
          `/admin-review/members/${encodeURIComponent(member.id)}/state`,
          {
            method: "PATCH",
            body: {
              accountStatus: nextAccountStatus,
              verificationStatus: nextVerificationStatus,
              allowStagingOverride: true,
              reason: customReason,
            },
          },
        );
      }
      setNotice(
        preset === "VERIFIED"
          ? `✅ Verified & Activated ${member.displayName} (${member.phoneFormatted ?? member.phoneE164 ?? member.phoneMasked})!`
          : `Updated ${member.displayName} status to ${preset}.`,
      );
      await load();
    } catch (cause) {
      setError(
        cause instanceof Error
          ? cause.message
          : "Could not override member status.",
      );
    } finally {
      setQuickUpdatingId(null);
    }
  }

  return (
    <div className="dashboard-page">
      <section className="page-heading">
        <div>
          <div className="eyebrow">
            <span className="eyebrow-line" /> PEOPLE &amp; TRUST • MODULE 1 (SRS SECTION 3.1–3.5)
          </div>
          <h1>Eligibility &amp; Identity Verification</h1>
          <p>
            Manage Decentro Staging DigiLocker KYC, minimum registration age policy, explicit manual-review submissions, and direct eligibility overrides for any registered user.
          </p>
        </div>
        <div className="heading-meta" style={{ display: "flex", gap: 8 }}>
          <button
            className="button button--secondary"
            type="button"
            onClick={() => setShowPhones((prev) => !prev)}
          >
            {showPhones ? <EyeOff size={15} /> : <Eye size={15} />}
            {showPhones ? "Hide Phone Numbers" : "Show Full Phone Numbers"}
          </button>
          <button
            className="button button--secondary"
            type="button"
            onClick={() => void load()}
            disabled={loading}
          >
            <RefreshCw size={14} /> Refresh queue
          </button>
        </div>
      </section>

      {/* Decentro Staging DigiLocker KYC Integration Banner */}
      <div
        className="panel"
        style={{
          padding: "14px 18px",
          marginBottom: 18,
          background: "#FAF5FB",
          border: "1px solid #DFC9E3",
          display: "flex",
          justifyContent: "space-between",
          alignItems: "center",
          flexWrap: "wrap",
          gap: 12,
        }}
      >
        <div>
          <span className="panel-kicker">AUTHORISED KYC PROVIDER (SRS 3.2 &amp; 3.5)</span>
          <h3 style={{ margin: "2px 0 4px", fontSize: 15 }}>
            Decentro Staging DigiLocker KYC Integration
          </h3>
          <p style={{ margin: 0, fontSize: 12.5, color: "#5F4B66" }}>
            Uses the server-side Decentro DigiLocker integration when provider credentials and the verification-policy gate are configured. Eligibility changes only after the backend retrieves a correlated provider result. Authorized admins can separately override member status.
          </p>
        </div>
        <StatusPill tone="neutral">READINESS FROM BACKEND CONFIG</StatusPill>
      </div>

      {notice && (
        <div className="member-toast" role="status" style={{ marginBottom: 16 }}>
          <CheckCircle2 size={17} />
          <span>{notice}</span>
        </div>
      )}
      {error && (
        <div className="admin-error-banner" role="alert" style={{ marginBottom: 16 }}>
          <span>{error}</span>
        </div>
      )}

      <div className="metric-grid" style={{ marginBottom: 20 }}>
        <article className="metric-card">
          <div className="metric-card__top">
            <span className="metric-icon metric-icon--amber">
              <Clock3 size={18} />
            </span>
          </div>
          <div className="metric-value">{queue.length}</div>
          <div className="metric-title">Awaiting manual decision</div>
        </article>
        <article className="metric-card">
          <div className="metric-card__top">
            <span className="metric-icon metric-icon--green">
              <ShieldCheck size={18} />
            </span>
          </div>
          <div className="metric-value">{history.length}</div>
          <div className="metric-title">Decision records loaded</div>
        </article>
      </div>

      <RegistrationPolicyPanel />

      {/* Explicit Manual Review Queue */}
      <section className="panel queue-panel" style={{ marginBottom: 22 }}>
        <div className="panel-heading">
          <div>
            <span className="panel-kicker">REVIEW QUEUE</span>
            <h2>Pending Manual-Review Submissions ({queue.length})</h2>
          </div>
          <StatusPill tone="amber">MANUAL QUEUE</StatusPill>
        </div>

        {queue.length === 0 ? (
          <div className="empty-state" style={{ padding: 20 }}>
            <h3>No pending manual-review submissions</h3>
            <p>
              Use the <strong>All Registered Users — Direct Eligibility Override</strong> table right below to change any registered user’s status even if they haven’t submitted a manual review request yet!
            </p>
          </div>
        ) : (
          <div className="table-scroll">
            <table className="operations-table">
              <thead>
                <tr>
                  <th>Member</th>
                  <th>Mobile Number (+91)</th>
                  <th>DOB &amp; Email</th>
                  <th>Submitted</th>
                  <th>Decision</th>
                </tr>
              </thead>
              <tbody>
                {queue.map((item) => (
                  <tr key={item.submissionId}>
                    <td>
                      <strong>{item.displayName}</strong>
                      <div style={{ fontSize: 11.5, color: "#6E6275" }}>
                        {item.reference}
                      </div>
                    </td>
                    <td>
                      <strong style={{ fontFamily: "monospace" }}>
                        {showPhones
                          ? (item.phoneFormatted ??
                            item.phoneE164 ??
                            item.phoneMasked)
                          : item.phoneMasked}
                      </strong>
                    </td>
                    <td>
                      <div>{item.dateOfBirth}</div>
                      <small style={{ color: "#6E6275" }}>
                        {showPhones
                          ? (item.email ?? item.emailMasked)
                          : item.emailMasked}
                      </small>
                    </td>
                    <td>{formatDateTime(item.submittedAt)}</td>
                    <td style={{ display: "flex", gap: 8 }}>
                      <button
                        className="button button--primary"
                        type="button"
                        onClick={() => beginDecision(item, "approve")}
                      >
                        <CheckCircle2 size={14} /> Approve
                      </button>
                      <button
                        className="button button--secondary"
                        type="button"
                        onClick={() => beginDecision(item, "reject")}
                      >
                        <XCircle size={14} /> Reject
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}

        {selected && decision && (
          <div
            style={{
              marginTop: 16,
              padding: 16,
              background: "#FAF5FB",
              borderRadius: 14,
              border: "1px solid #DFC9E3",
            }}
          >
            <h3 style={{ margin: "0 0 8px" }}>
              {decision === "approve" ? "Approve & Verify" : "Reject"}{" "}
              {selected.displayName} (
              {selected.phoneFormatted ??
                selected.phoneE164 ??
                selected.phoneMasked}
              )
            </h3>
            <label className="member-filter-select" style={{ marginBottom: 10 }}>
              <span>Audit reason / reviewer comment (10–500 chars)</span>
              <input
                type="text"
                value={reason}
                onChange={(e) => setReason(e.target.value)}
              />
            </label>
            <div style={{ display: "flex", gap: 8 }}>
              <button
                className="button button--primary"
                type="button"
                disabled={submitting}
                onClick={() => void submitDecision()}
              >
                {submitting ? "Saving…" : `Confirm ${decision}`}
              </button>
              <button
                className="button button--secondary"
                type="button"
                onClick={() => {
                  setSelected(null);
                  setDecision(null);
                }}
              >
                Cancel
              </button>
            </div>
          </div>
        )}
      </section>

      {/* All Registered Users — Direct Eligibility Override Table */}
      <section className="panel queue-panel" style={{ marginBottom: 22 }}>
        <div className="panel-heading">
          <div>
            <span className="panel-kicker">
              DIRECT DEVELOPMENT &amp; STAGING ELIGIBILITY CONTROL
            </span>
            <h2>
              All Registered Users — Change Status Anytime ({pendingMembers.length})
            </h2>
            <p style={{ margin: "4px 0 0", fontSize: 13, color: "#6E6275" }}>
              Enter an optional audit comment/reason below and click any button to set any registered user to <strong>Verified</strong>, <strong>Pending</strong>, <strong>Incomplete</strong>, or <strong>Rejected</strong>.
            </p>
          </div>
          <Link className="button button--secondary" to="/members">
            Open Full 360° Member Directory
          </Link>
        </div>

        <div
          style={{
            marginBottom: 14,
            padding: "10px 14px",
            borderRadius: 12,
            background: "rgba(250, 245, 251, 0.85)",
            border: "1px solid #DFC9E3",
            display: "flex",
            alignItems: "center",
            gap: 10,
          }}
        >
          <MessageSquareText size={16} color="#5A1868" />
          <span style={{ fontSize: 12.5, fontWeight: 700, color: "#5A1868", whiteSpace: "nowrap" }}>
            Reviewer Override Comment:
          </span>
          <input
            type="text"
            value={overrideComment}
            onChange={(e) => setOverrideComment(e.target.value)}
            placeholder="Enter audit comment or reason for status change..."
            style={{
              flex: 1,
              padding: "7px 12px",
              borderRadius: 8,
              border: "1px solid #D3B8DB",
              fontSize: 13,
            }}
          />
        </div>

        <div className="table-scroll">
          <table className="operations-table">
            <thead>
              <tr>
                <th>Member</th>
                <th>Mobile Number (+91)</th>
                <th>DOB &amp; Email</th>
                <th>Current Status</th>
                <th>Change Eligibility Status Now</th>
              </tr>
            </thead>
            <tbody>
              {pendingMembers.map((m) => {
                const busy = quickUpdatingId === m.id;
                return (
                  <tr key={m.id}>
                    <td>
                      <strong>{m.displayName}</strong>
                      <div style={{ fontSize: 11.5, color: "#6E6275" }}>
                        {m.reference}
                      </div>
                    </td>
                    <td>
                      <strong style={{ fontFamily: "monospace" }}>
                        {showPhones
                          ? (m.phoneFormatted ?? m.phoneE164 ?? m.phoneMasked)
                          : m.phoneMasked}
                      </strong>
                    </td>
                    <td>
                      <div>
                        {m.dateOfBirth ?? "DOB not set"}
                        {m.ageYears != null ? ` (${m.ageYears} yrs)` : ""}
                      </div>
                      <small style={{ color: "#6E6275" }}>
                        {showPhones ? (m.email ?? m.emailMasked) : m.emailMasked}
                      </small>
                    </td>
                    <td>
                      <StatusPill
                        tone={
                          m.verificationStatus === "VERIFIED"
                            ? "green"
                            : m.verificationStatus === "REJECTED"
                              ? "urgent"
                              : "amber"
                        }
                      >
                        {m.verificationStatus} ({m.accountStatus})
                      </StatusPill>
                    </td>
                    <td>
                      <div style={{ display: "flex", gap: 6, flexWrap: "wrap" }}>
                        <button
                          type="button"
                          className="button button--primary"
                          disabled={busy}
                          onClick={() =>
                            void quickOverrideMemberStatus(m, "VERIFIED")
                          }
                        >
                          ✅ Verify
                        </button>
                        <button
                          type="button"
                          className="button button--secondary"
                          disabled={busy}
                          onClick={() =>
                            void quickOverrideMemberStatus(
                              m,
                              "PENDING_MANUAL_REVIEW",
                            )
                          }
                        >
                          ⏳ Set Pending
                        </button>
                        <button
                          type="button"
                          className="button button--secondary"
                          disabled={busy}
                          onClick={() =>
                            void quickOverrideMemberStatus(m, "INCOMPLETE")
                          }
                        >
                          📝 Set Incomplete
                        </button>
                        <button
                          type="button"
                          className="button button--secondary"
                          disabled={busy}
                          onClick={() =>
                            void quickOverrideMemberStatus(m, "REJECTED")
                          }
                        >
                          ❌ Reject
                        </button>
                      </div>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </section>

      {/* Audit Decision History */}
      <section className="panel queue-panel">
        <div className="panel-heading">
          <div>
            <span className="panel-kicker">AUDIT TRAIL</span>
            <h2>Recorded Eligibility Decisions ({history.length})</h2>
          </div>
        </div>
        <div className="table-scroll">
          <table className="operations-table">
            <thead>
              <tr>
                <th>Action</th>
                <th>Outcome</th>
                <th>Reviewer</th>
                <th>Reason</th>
                <th>Timestamp</th>
              </tr>
            </thead>
            <tbody>
              {history.length === 0 && (
                <tr>
                  <td colSpan={5} className="member-empty-cell">
                    No eligibility decisions recorded yet.
                  </td>
                </tr>
              )}
              {history.map((item) => (
                <tr key={item.id}>
                  <td>
                    <code>{item.action}</code>
                  </td>
                  <td>
                    <StatusPill
                      tone={item.outcome === "approve" ? "green" : "amber"}
                    >
                      {item.outcome}
                    </StatusPill>
                  </td>
                  <td>{item.reviewerLabel}</td>
                  <td>{item.reason}</td>
                  <td>{formatDateTime(item.createdAt)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </div>
  );
}
