import { useCallback, useEffect, useState, type FormEvent } from "react";
import { AlertCircle, CheckCircle2, Clock3, LockKeyhole, RefreshCw, ShieldCheck } from "lucide-react";
import { StatusPill } from "./StatusPill";
import { adminApi } from "../services/api/adminApi";

export interface RegistrationPolicyData {
  configured: boolean;
  minimumAgeYears: number;
  source:
    | "database_admin_policy"
    | "environment_staging_default"
    | "environment_dev_default"
    | "unconfigured";
  updatedAt: string | null;
  updatedBy: string | null;
  changeReason: string | null;
  minAllowedAgeYears: number;
  maxAllowedAgeYears: number;
  environmentDefaultAgeYears: number;
  message?: string;
}

const PRESET_AGES = [13, 16, 18, 21] as const;

function formatDateTime(value: string | null): string {
  if (!value) return "Default environment policy (no custom admin override yet)";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return value;
  return new Intl.DateTimeFormat("en-IN", {
    day: "2-digit",
    month: "short",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  }).format(date);
}

export function RegistrationPolicyPanel() {
  const [policy, setPolicy] = useState<RegistrationPolicyData | null>(null);
  const [ageInput, setAgeInput] = useState("18");
  const [reason, setReason] = useState("");
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");

  const loadPolicy = useCallback(async () => {
    try {
      const response = await adminApi<RegistrationPolicyData>(
        "/admin-review/registration-policy",
      );
      setPolicy(response);
      setAgeInput(String(response.minimumAgeYears ?? 18));
    } catch (cause) {
      setError(
        cause instanceof Error
          ? cause.message
          : "Could not load registration minimum-age policy.",
      );
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    let active = true;
    void Promise.resolve().then(() => {
      if (active) void loadPolicy();
    });
    return () => {
      active = false;
    };
  }, [loadPolicy]);

  function handleRefresh() {
    setLoading(true);
    setError("");
    void loadPolicy();
  }

  async function handleSave(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError("");
    setNotice("");

    const trimmedAge = ageInput.trim();
    if (!/^\d+$/.test(trimmedAge)) {
      setError("Enter a whole integer number of years (for example 13, 18, or 21).");
      return;
    }
    const parsedAge = Number.parseInt(trimmedAge, 10);
    const minAllowed = policy?.minAllowedAgeYears ?? 13;
    const maxAllowed = policy?.maxAllowedAgeYears ?? 100;
    if (
      !Number.isInteger(parsedAge) ||
      parsedAge < minAllowed ||
      parsedAge > maxAllowed
    ) {
      setError(
        `Minimum registration age must be an integer between ${minAllowed} and ${maxAllowed} years.`,
      );
      return;
    }

    const trimmedReason = reason.trim();
    if (trimmedReason.length < 10 || trimmedReason.length > 500) {
      setError(
        "Enter an audit reason between 10 and 500 characters explaining why the minimum age policy is being changed.",
      );
      return;
    }

    setSaving(true);
    try {
      const saved = await adminApi<RegistrationPolicyData>(
        "/admin-review/registration-policy",
        {
          method: "PUT",
          body: {
            minimumAgeYears: parsedAge,
            reason: trimmedReason,
          },
        },
      );
      setPolicy(saved);
      setAgeInput(String(saved.minimumAgeYears));
      setReason("");
      setNotice(
        saved.message ??
          `Minimum registration age updated to ${saved.minimumAgeYears}+ years and persisted in PostgreSQL.`,
      );
    } catch (cause) {
      setError(
        cause instanceof Error
          ? cause.message
          : "Could not save minimum registration age policy.",
      );
    } finally {
      setSaving(false);
    }
  }

  return (
    <section className="panel registration-policy-panel" aria-labelledby="reg-policy-heading">
      <div className="member-directory-heading">
        <div>
          <span className="panel-kicker">PLATFORM REGISTRATION POLICY</span>
          <h2 id="reg-policy-heading">Minimum registration age control</h2>
          <p>
            Configure the minimum age required to create a Sakhi account. This policy is persisted in PostgreSQL, audited in <code>audit_events</code>, displayed dynamically on the mobile registration screen (<code>Age Verified ({policy?.minimumAgeYears ?? 18}+)</code>), and enforced server-side on <code>POST /api/v1/auth/profile</code>.
          </p>
        </div>
        <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
          {policy && (
            <StatusPill tone={policy.source === "database_admin_policy" ? "green" : "amber"}>
              ACTIVE: {policy.minimumAgeYears}+ YEARS
            </StatusPill>
          )}
          <button
            type="button"
            className="button button--secondary"
            onClick={handleRefresh}
            disabled={loading || saving}
          >
            <RefreshCw size={14} /> Refresh
          </button>
        </div>
      </div>

      {notice && (
        <div className="member-toast" role="status" style={{ marginBottom: 14 }}>
          <CheckCircle2 size={17} />
          <span>{notice}</span>
        </div>
      )}

      {error && (
        <div className="admin-error-banner" role="alert" style={{ marginBottom: 14 }}>
          <AlertCircle size={16} />
          <span>{error}</span>
        </div>
      )}

      {loading && !policy ? (
        <div className="member-directory-state" aria-busy="true">
          <Clock3 size={22} />
          <h3>Loading registration age policy...</h3>
        </div>
      ) : (
        <div className="registration-policy-grid">
          <div className="registration-policy-summary">
            <div className="registration-policy-badge-preview">
              <span className="registration-policy-badge-label">Mobile Screen 03 Live Badge Preview</span>
              <span className="registration-policy-pill">
                <ShieldCheck size={15} /> Age Verified ({policy?.minimumAgeYears ?? 18}+)
              </span>
            </div>
            <dl className="member-detail-list">
              <div>
                <dt>Current minimum age</dt>
                <dd><strong>{policy?.minimumAgeYears ?? 18} years old</strong></dd>
              </div>
              <div>
                <dt>Policy source</dt>
                <dd>
                  {policy?.source === "database_admin_policy"
                    ? "Database admin override (platform_registration_policies)"
                    : `Environment default (${policy?.environmentDefaultAgeYears ?? 18}+ years)`}
                </dd>
              </div>
              <div>
                <dt>Last updated</dt>
                <dd>{formatDateTime(policy?.updatedAt ?? null)}</dd>
              </div>
              <div>
                <dt>Updated by</dt>
                <dd>{policy?.updatedBy ?? "System environment default"}</dd>
              </div>
              {policy?.changeReason && (
                <div>
                  <dt>Last audit reason</dt>
                  <dd>{policy.changeReason}</dd>
                </div>
              )}
            </dl>
          </div>

          <form className="registration-policy-form" onSubmit={handleSave}>
            <div className="registration-policy-presets">
              <span>Quick presets:</span>
              {PRESET_AGES.map((preset) => (
                <button
                  key={preset}
                  type="button"
                  className={
                    Number.parseInt(ageInput, 10) === preset
                      ? "button button--primary"
                      : "button button--secondary"
                  }
                  onClick={() => setAgeInput(String(preset))}
                  disabled={saving}
                >
                  {preset}+ years
                </button>
              ))}
            </div>

            <div className="member-filter-toolbar" style={{ marginTop: 12 }}>
              <label className="member-filter-select">
                <span>Minimum registration age (years, {policy?.minAllowedAgeYears ?? 13}–{policy?.maxAllowedAgeYears ?? 100})</span>
                <input
                  type="number"
                  min={policy?.minAllowedAgeYears ?? 13}
                  max={policy?.maxAllowedAgeYears ?? 100}
                  step={1}
                  required
                  value={ageInput}
                  onChange={(event) => setAgeInput(event.target.value)}
                />
              </label>

              <label className="member-filter-select" style={{ flex: 2 }}>
                <span>Audit log reason (required, 10–500 chars)</span>
                <input
                  type="text"
                  minLength={10}
                  maxLength={500}
                  required
                  value={reason}
                  onChange={(event) => setReason(event.target.value)}
                  placeholder="e.g. Enforce 18+ age verification across staging registration cohort"
                />
              </label>

              <button
                className="button button--primary"
                type="submit"
                disabled={saving}
              >
                <LockKeyhole size={15} />{" "}
                {saving ? "Saving policy..." : "Save age policy"}
              </button>
            </div>
          </form>
        </div>
      )}
    </section>
  );
}
