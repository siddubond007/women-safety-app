import { useCallback, useEffect, useState } from "react";
import { AlertTriangle, CheckCircle2, LogOut, RefreshCw, ShieldCheck, XCircle } from "lucide-react";
import { BrandMark } from "../components/BrandMark";
import { StatusPill } from "../components/StatusPill";
import { AdminApiError, adminApi } from "../services/api/adminApi";

type TestAccount = {
  id: string;
  reference: string;
  displayName: string;
  phoneMasked: string;
  registeredAt: string;
  accountStatus: string;
  verificationStatus: string;
  testAccessApproved: boolean;
  testAccessChangedAt: string | null;
  canGrantTestAccess: boolean;
};
type Decision = "approve" | "revoke";

function formatDate(value: string | null | undefined): string {
  if (!value) return "Never";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "Not available";
  return new Intl.DateTimeFormat("en-IN", {
    day: "2-digit",
    month: "short",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  }).format(date);
}

interface Props {
  onSignOut: () => void;
}

export function StagingTestAccessPage({ onSignOut }: Props) {
  const [accounts, setAccounts] = useState<TestAccount[]>([]);
  const [selected, setSelected] = useState<TestAccount | null>(null);
  const [decision, setDecision] = useState<Decision | null>(null);
  const [reason, setReason] = useState("");
  const [acknowledged, setAcknowledged] = useState(false);
  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");

  const load = useCallback(async () => {
    setError("");
    try {
      const items = await adminApi<TestAccount[]>("/staging-test-admin/accounts");
      setAccounts(items);
    } catch (cause) {
      if (cause instanceof AdminApiError && cause.statusCode === 401) {
        onSignOut();
        return;
      }
      setError(cause instanceof Error ? cause.message : "Could not load staging accounts.");
    } finally {
      setLoading(false);
    }
  }, [onSignOut]);

  useEffect(() => {
    void load();
  }, [load]);

  function beginDecision(account: TestAccount, next: Decision) {
    setSelected(account);
    setDecision(next);
    setReason("");
    setAcknowledged(false);
    setError("");
    setNotice("");
  }

  async function submitDecision() {
    if (!selected || !decision) return;
    if (!acknowledged) {
      setError("Confirm that this action grants test-only access and does not verify eligibility.");
      return;
    }
    if (reason.trim().length < 10) {
      setError("Enter a non-sensitive reason of at least 10 characters.");
      return;
    }
    setSubmitting(true);
    setError("");
    try {
      const result = await adminApi<{ message: string }>(
        `/staging-test-admin/accounts/${selected.id}/${decision === "approve" ? "approve" : "revoke"}`,
        {
          method: "POST",
          body: { acknowledgedTestOnly: true, reason: reason.trim() },
        },
      );
      setNotice(result.message);
      setSelected(null);
      setDecision(null);
      await load();
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : "The test-access change could not be saved.");
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <main className="staging-test-admin">
      <header className="staging-test-admin__topbar">
        <BrandMark />
        <div className="staging-test-admin__top-actions">
          <StatusPill tone="demo">STAGING / TEST ONLY</StatusPill>
          <button type="button" className="button button--secondary" onClick={onSignOut}><LogOut size={15} /> Sign out</button>
        </div>
      </header>

      <section className="staging-test-admin__content">
        <div className="page-heading">
          <div>
            <div className="eyebrow"><span className="eyebrow-line" /> FRIEND TESTING</div>
            <h1>Staging test access</h1>
            <p>Grant or revoke app-feature access for accounts created in the staging database.</p>
          </div>
          <button type="button" className="button button--secondary" onClick={() => { setLoading(true); void load(); }} disabled={loading}>
            <RefreshCw size={15} /> Refresh accounts
          </button>
        </div>

        <div className="staging-test-admin__warning" role="note">
          <AlertTriangle size={22} />
          <div>
            <strong>Test-only override — not eligibility verification</strong>
            <p>These actions do not verify phone ownership, do not make an eligibility decision, and do not modify the account's real verification status. They only unlock the app's restricted test features for this staging environment. Every grant and revocation is recorded in the audit log.</p>
          </div>
        </div>

        {notice && <div className="staging-test-admin__notice" role="status"><CheckCircle2 size={18} />{notice}</div>}
        {error && !selected && <div className="staging-test-admin__error" role="alert"><XCircle size={18} />{error}</div>}

        <section className="panel staging-test-admin__panel">
          <div className="member-directory-heading">
            <div>
              <span className="panel-kicker">HOSTED SUPABASE STAGING DATA</span>
              <h2>Registered test accounts</h2>
              <p>Only masked phone numbers are shown. Eligibility remains unverified even when test access is enabled.</p>
            </div>
            <StatusPill tone="demo">{accounts.length} accounts</StatusPill>
          </div>
          {loading ? (
            <div className="member-directory-state" aria-busy="true"><RefreshCw size={22} /><h3>Loading staging accounts</h3><p>Fetching the account list from the hosted staging API.</p></div>
          ) : accounts.length === 0 ? (
            <div className="member-directory-state"><ShieldCheck size={25} /><h3>No registered profiles found</h3><p>Create a test account in the Sakhi app first, then refresh this list.</p></div>
          ) : (
            <div className="member-table-scroll">
              <table className="member-table">
                <thead><tr><th>Member</th><th>Masked phone</th><th>Account state</th><th>Real eligibility</th><th>Test access</th><th>Last changed</th><th>Action</th></tr></thead>
                <tbody>
                  {accounts.map((account) => (
                    <tr key={account.id}>
                      <td><div className="member-identity-copy"><strong>{account.displayName}</strong><small>{account.reference}</small></div></td>
                      <td>{account.phoneMasked}</td>
                      <td>{account.accountStatus}</td>
                      <td><StatusPill tone="amber">{account.verificationStatus === "VERIFIED" ? "Verified" : account.verificationStatus === "REJECTED" ? "Rejected" : "Unverified"}</StatusPill></td>
                      <td><StatusPill tone={account.testAccessApproved ? "green" : "neutral"}>{account.testAccessApproved ? "TEST APPROVED" : "Not enabled"}</StatusPill></td>
                      <td>{formatDate(account.testAccessChangedAt)}</td>
                      <td>
                        {account.testAccessApproved ? (
                          <button type="button" className="button button--secondary" onClick={() => beginDecision(account, "revoke")}>Revoke test access</button>
                        ) : (
                          <button type="button" className="button button--primary" disabled={!account.canGrantTestAccess} onClick={() => beginDecision(account, "approve")}>Grant test access</button>
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </section>

        <p className="staging-test-admin__footer">SAKHI FRIEND-TESTING PORTAL · Staging only · No actual eligibility state is changed</p>
      </section>

      {selected && decision && (
        <div className="member-modal-overlay" role="presentation">
          <section className="member-action-modal staging-test-admin__modal" role="dialog" aria-modal="true" aria-labelledby="test-access-decision-title">
            <div className="member-modal-heading">
              <span className="member-modal-icon member-modal-icon--warning"><ShieldCheck size={20} /></span>
              <button className="member-modal-close" type="button" disabled={submitting} onClick={() => { setSelected(null); setDecision(null); setError(""); }} aria-label="Close review">X</button>
            </div>
            <div className="member-modal-kicker">STAGING TEST-ONLY CONTROL</div>
            <h2 id="test-access-decision-title">{decision === "approve" ? "Grant test access?" : "Revoke test access?"}</h2>
            <p>{selected.displayName} · {selected.reference} · {selected.phoneMasked}</p>
            <div className="staging-test-admin__modal-warning">
              {decision === "approve"
                ? "The account will be allowed to use restricted app features in staging. Phone ownership and eligibility will remain UNVERIFIED."
                : "Restricted features will be locked again on the next API request. The account's underlying verification status will remain unchanged."}
            </div>
            <label className="eligibility-review-attestation">
              <input type="checkbox" checked={acknowledged} onChange={(event) => setAcknowledged(event.target.checked)} />
              <span>I understand this is a test-only access override, not a real eligibility approval.</span>
            </label>
            <label className="member-form-label" htmlFor="staging-test-access-reason">Reason <span>Required: 10–500 characters</span></label>
            <textarea id="staging-test-access-reason" rows={3} maxLength={500} minLength={10} value={reason} onChange={(event) => setReason(event.target.value)} placeholder={decision === "approve" ? "For example: friend tester needs access to Module 3 community features." : "For example: friend testing completed; revoke temporary staging access."} />
            <div className="member-form-helper"><span>{reason.trim().length}/500</span></div>
            {error && <p className="admin-review-error" role="alert">{error}</p>}
            <div className="eligibility-review-decision-buttons">
              <button type="button" className="button button--secondary" disabled={submitting} onClick={() => { setSelected(null); setDecision(null); setError(""); }}>Cancel</button>
              <button type="button" className="button button--primary" disabled={submitting || !acknowledged || reason.trim().length < 10} onClick={() => void submitDecision()}>
                {submitting ? "Saving..." : decision === "approve" ? "Confirm test approval" : "Confirm revocation"}
              </button>
            </div>
          </section>
        </div>
      )}
    </main>
  );
}
