import { useState, type FormEvent } from "react";
import { ArrowRight, LockKeyhole, ShieldCheck, Sparkles } from "lucide-react";
import { BrandMark } from "../components/BrandMark";
import { StatusPill } from "../components/StatusPill";
import {
  adminAuthService,
  isStagingTestAdminMode,
  type AdminAuthResult,
} from "../services/auth/adminAuthService";

interface LoginPageProps {
  onAuthenticate: (token: string, mfaCode?: string) => Promise<AdminAuthResult>;
  onCredentialAuthenticate?: (identifier: string, password: string, mfaCode: string) => Promise<void>;
}

type LoginStage = "token" | "bootstrap" | "mfa" | "verify-enrollment" | "backup-codes" | "recovery";

export function LoginPage({ onAuthenticate, onCredentialAuthenticate }: LoginPageProps) {
  const [token, setToken] = useState("");
  const [fullName, setFullName] = useState("");
  const [email, setEmail] = useState("");
  const [code, setCode] = useState("");
  const [stage, setStage] = useState<LoginStage>("token");
  const [enrollmentSecret, setEnrollmentSecret] = useState("");
  const [otpauthUri, setOtpauthUri] = useState("");
  const [backupCodes, setBackupCodes] = useState<string[]>([]);
  const [recoveryRequestId, setRecoveryRequestId] = useState("");
  const [recoveryToken, setRecoveryToken] = useState("");
  const [recoveryMessage, setRecoveryMessage] = useState("");
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState("");
  const [credentialIdentifier, setCredentialIdentifier] = useState("");
  const [credentialPassword, setCredentialPassword] = useState("");
  const [credentialMfaCode, setCredentialMfaCode] = useState("");

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError("");
    setIsSubmitting(true);
    try {
      if (stage === "backup-codes") {
        setStage("mfa");
        setCode("");
        return;
      }

      if (stage === "recovery") {
        await adminAuthService.completeMfaRecovery(token.trim(), recoveryToken.trim());
        setRecoveryToken("");
        setRecoveryRequestId("");
        setStage("token");
        setCode("");
        setRecoveryMessage("MFA recovery completed. Sign in with your staff token and enroll a new authenticator.");
        return;
      }

      if (stage === "bootstrap") {
        const created = await adminAuthService.bootstrapSuperAdmin(
          token.trim(),
          fullName.trim(),
          email.trim(),
        );
        setToken(created.accessToken);
        const enrollment = await adminAuthService.startMfaEnrollment(created.accessToken);
        setEnrollmentSecret(enrollment.secret);
        setOtpauthUri(enrollment.otpauthUri);
        setStage("verify-enrollment");
        return;
      }

      if (stage === "verify-enrollment") {
        const result = await adminAuthService.verifyMfaEnrollment(token.trim(), code.trim());
        setBackupCodes(result.backupCodes);
        setCode("");
        setStage("backup-codes");
        return;
      }

      const result = await onAuthenticate(
        token.trim(),
        stage === "mfa" ? code.trim() : undefined,
      );
      if (result.authenticated) {
        setToken("");
        setCode("");
        return;
      }
      if (result.bootstrapRequired) {
        setStage("bootstrap");
        return;
      }
      if (result.mfaEnrollmentRequired) {
        const enrollment = await adminAuthService.startMfaEnrollment(token.trim());
        setEnrollmentSecret(enrollment.secret);
        setOtpauthUri(enrollment.otpauthUri);
        setStage("verify-enrollment");
        setCode("");
        return;
      }
      if (result.mfaRequired) {
        setStage("mfa");
        setCode("");
      }
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : "Reviewer authentication failed.");
    } finally {
      setIsSubmitting(false);
    }
  }

  async function submitCredentials(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError("");
    if (!onCredentialAuthenticate) return;
    setIsSubmitting(true);
    try {
      await onCredentialAuthenticate(credentialIdentifier.trim(), credentialPassword, credentialMfaCode.trim());
      setCredentialPassword("");
      setCredentialMfaCode("");
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : "Credential sign-in failed.");
    } finally {
      setIsSubmitting(false);
    }
  }

  async function requestRecovery() {
    setError("");
    setIsSubmitting(true);
    try {
      const request = await adminAuthService.requestMfaRecovery(token.trim());
      setRecoveryRequestId(request.requestId);
      setStage("recovery");
      setRecoveryMessage("Your request is awaiting approval by a separate MFA-verified Super Admin. Enter the recovery token only after it is delivered to you through the approved out-of-band channel.");
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : "MFA recovery request failed.");
    } finally {
      setIsSubmitting(false);
    }
  }

  const staging = isStagingTestAdminMode;
  const needsCode = stage === "mfa" || stage === "verify-enrollment";

  return (
    <main className="login-page">
      <div className="login-orb login-orb--one" aria-hidden="true" />
      <div className="login-orb login-orb--two" aria-hidden="true" />
      <header className="login-topbar">
        <BrandMark />
        <StatusPill tone="demo">
          <span className="status-pill__dot" /> {staging ? "STAGING RBAC PORTAL" : "DEV / TEST RBAC PORTAL"}
        </StatusPill>
      </header>
      <div className="login-layout">
        <section className="login-story">
          <div className="login-eyebrow">
            <span className="login-eyebrow__star"><Sparkles size={14} /></span> THE SAKHI OPERATIONS SPACE
          </div>
          <h1>Care begins with<br /><em>clarity.</em></h1>
          <p className="login-story-copy">
            Role-based administration for Super Admin and the six specialized Normal Admin roles.
          </p>
          <div className="login-feature-list">
            <div>
              <span className="login-feature-icon"><ShieldCheck size={18} /></span>
              <span><strong>Individual staff identity</strong><small>Shared full-admin bootstrap sessions are disabled. Privileged access requires an individual active staff account.</small></span>
            </div>
            <div>
              <span className="login-feature-icon"><LockKeyhole size={18} /></span>
              <span><strong>Mandatory authenticator MFA</strong><small>RFC 6238 TOTP, replay protection, single-use backup codes and independent Super Admin recovery approval.</small></span>
            </div>
            <div>
              <span className="login-feature-icon"><ShieldCheck size={18} /></span>
              <span><strong>Server-side session control</strong><small>Privileged staff sessions are persisted, rotated and revoked on the server, using a protected HttpOnly cookie.</small></span>
            </div>
          </div>
        </section>

        <section className="login-card" aria-labelledby="login-title">
          <div className="login-card-mark"><ShieldCheck size={24} /></div>
          <div className="login-card-kicker">{staging ? "STAGING ADMIN & STAFF PORTAL" : "LOCAL ADMIN & STAFF PORTAL"}</div>
          <h2 id="login-title">
            {stage === "mfa" ? "Verify your authenticator" :
              stage === "verify-enrollment" ? "Enroll your authenticator" :
                stage === "backup-codes" ? "Save your backup codes" :
                  stage === "bootstrap" ? "Create the initial Super Admin" : "Admin or Reviewer Sign In"}
          </h2>
          <p className="login-card-description">
            {stage === "mfa"
              ? "Enter the current six-digit code from your authenticator, or one unused backup code."
              : stage === "verify-enrollment"
                ? "Add this Sakhi Admin account to an RFC 6238-compatible authenticator, then verify with its current six-digit code."
                : stage === "backup-codes"
                  ? "These backup codes are shown once. Store them somewhere private and separate from your authenticator."
                  : stage === "bootstrap"
                    ? "The one-time bootstrap credential can create exactly one initial Super Admin account. It cannot create a privileged session."
                    : stage === "recovery"
                      ? "Enter the one-time recovery token issued by an independent MFA-verified Super Admin. Your existing staff token is also required."
                    : staging
                      ? "Enter your individual staff access token, or the one-time bootstrap credential if no Super Admin account exists."
                      : "Enter the local development/test reviewer token."}
          </p>

          <form onSubmit={submit}>
            <label className="member-form-label" htmlFor="reviewer-token">
              {stage === "bootstrap" ? "One-time bootstrap credential" : "Staff Access Token"} <span>Required</span>
            </label>
            <input
              id="reviewer-token"
              className="admin-review-token-input"
              type="password"
              autoComplete="off"
              value={token}
              onChange={(event) => setToken(event.target.value)}
              minLength={8}
              required
              aria-describedby="reviewer-token-help"
            />
            <p id="reviewer-token-help" className="admin-review-help">
              {stage === "bootstrap"
                ? <>This credential is accepted only to create the first Super Admin account, once.</>
                : staging
                  ? <>Use your personal staff credential issued by the Super Admin.</>
                  : <>Use the configured local development/test reviewer credential.</>}
            </p>

            {stage === "bootstrap" && (
              <>
                <label className="member-form-label" htmlFor="bootstrap-name">Initial Super Admin full name <span>Required</span></label>
                <input id="bootstrap-name" className="admin-review-token-input" value={fullName} onChange={(event) => setFullName(event.target.value)} minLength={3} maxLength={120} required />
                <label className="member-form-label" htmlFor="bootstrap-email">Initial Super Admin email <span>Required</span></label>
                <input id="bootstrap-email" className="admin-review-token-input" type="email" value={email} onChange={(event) => setEmail(event.target.value)} maxLength={254} required />
              </>
            )}

            {stage === "recovery" && (
              <>
                <label className="member-form-label" htmlFor="mfa-recovery-token">
                  Approved one-time recovery token <span>Required</span>
                </label>
                <input
                  id="mfa-recovery-token"
                  className="admin-review-token-input"
                  type="password"
                  autoComplete="off"
                  value={recoveryToken}
                  onChange={(event) => setRecoveryToken(event.target.value)}
                  minLength={32}
                  required
                />
              </>
            )}

            {stage === "verify-enrollment" && (
              <div className="admin-review-help" role="group" aria-label="Authenticator setup">
                <p><strong>Manual setup secret</strong></p>
                <code>{enrollmentSecret}</code>
                <p>Authenticator setup URI:</p>
                <code style={{ overflowWrap: "anywhere" }}>{otpauthUri}</code>
              </div>
            )}

            {stage === "backup-codes" && (
              <div className="admin-review-help" role="group" aria-label="Single-use backup codes">
                <strong>Save all ten backup codes now</strong>
                <ul>
                  {backupCodes.map((backupCode) => <li key={backupCode}><code>{backupCode}</code></li>)}
                </ul>
              </div>
            )}

            {needsCode && (
              <>
                <label className="member-form-label" htmlFor="mfa-code">
                  {stage === "verify-enrollment" ? "Authenticator verification code" : "Authenticator or backup code"}
                  <span>Required</span>
                </label>
                <input
                  id="mfa-code"
                  className="admin-review-token-input"
                  type="text"
                  inputMode="numeric"
                  autoComplete="one-time-code"
                  value={code}
                  onChange={(event) => setCode(event.target.value)}
                  minLength={6}
                  maxLength={128}
                  required
                />
              </>
            )}

            {error && <p className="admin-review-error" role="alert">{error}</p>}
            {recoveryMessage && <p className="admin-review-help" role="status">{recoveryMessage}</p>}
            {recoveryRequestId && (
              <p className="admin-review-help" role="status">
                Recovery request created: <code>{recoveryRequestId}</code>. An independent MFA-verified Super Admin must approve it.
              </p>
            )}

            <button
              className="button button--primary login-submit"
              type="submit"
              disabled={
                isSubmitting ||
                token.trim().length < 8 ||
                (needsCode && code.trim().length < 6) ||
                (stage === "recovery" && recoveryToken.trim().length < 32) ||
                (stage === "bootstrap" && (fullName.trim().length < 3 || !email.includes("@")))
              }
            >
              {isSubmitting
                ? "Verifying..."
                : stage === "backup-codes"
                  ? "I saved my backup codes"
                  : stage === "verify-enrollment"
                    ? "Verify and enable MFA"
                    : stage === "mfa"
                      ? "Verify and sign in"
                      : stage === "bootstrap"
                        ? "Create Super Admin and enroll MFA"
                        : stage === "recovery"
                          ? "Complete MFA recovery"
                          : "Continue"}
              <ArrowRight size={17} />
            </button>
          </form>
          {onCredentialAuthenticate && stage === "token" && (
            <>
              <p className="login-card-description" style={{ marginTop: 18, textAlign: "center" }}>Or sign in with your assigned admin credentials and authenticator.</p>
              <form onSubmit={submitCredentials} className="login-credential-form">
                <label className="member-form-label" htmlFor="admin-identifier">Admin email or username <span>Required</span></label>
                <input id="admin-identifier" className="admin-review-token-input" value={credentialIdentifier} onChange={(event) => setCredentialIdentifier(event.target.value)} autoComplete="username" required />
                <label className="member-form-label" htmlFor="admin-password">Password <span>Required</span></label>
                <input id="admin-password" className="admin-review-token-input" type="password" value={credentialPassword} onChange={(event) => setCredentialPassword(event.target.value)} autoComplete="current-password" required />
                <label className="member-form-label" htmlFor="admin-mfa-code">Authenticator / backup code <span>Required</span></label>
                <input id="admin-mfa-code" className="admin-review-token-input" value={credentialMfaCode} onChange={(event) => setCredentialMfaCode(event.target.value)} autoComplete="one-time-code" required />
                <button className="button login-submit" type="submit" disabled={isSubmitting || !credentialIdentifier.trim() || !credentialPassword || !credentialMfaCode.trim()}>
                  {isSubmitting ? "Verifying credentials..." : "Sign in with credentials"} <ArrowRight size={16} />
                </button>
              </form>
            </>
          )}

          {stage === "mfa" && (
            <button className="button login-submit" type="button" disabled={isSubmitting} onClick={requestRecovery}>
              Request supervised MFA recovery
            </button>
          )}

          <div className="demo-notice">
            <span className="demo-notice-icon"><LockKeyhole size={17} /></span>
            <div>
              <strong>Role-Based Access Control (RBAC)</strong>
              <p>Access is enforced by the backend for each staff role. Frontend route visibility is not an authorization boundary.</p>
            </div>
          </div>
          <div className="login-card-footer">Sakhi Administration <span>-</span> Secure Staff Authentication</div>
        </section>
      </div>
      <footer className="login-footer">
        <span>SAKHI - PRIVATE ADMINISTRATION UI</span>
        <span><LockKeyhole size={13} /> {staging ? "Staging RBAC" : "Dev/test RBAC"}</span>
      </footer>
    </main>
  );
}
