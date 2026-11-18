import { useEffect, useState, type FormEvent } from "react";
import { ArrowRight, LockKeyhole, ShieldCheck, Sparkles } from "lucide-react";
import { BrandMark } from "../components/BrandMark";
import { StatusPill } from "../components/StatusPill";
import {
  adminAuthService,
  isStagingTestAdminMode,
} from "../services/auth/adminAuthService";

interface LoginPageProps {
  onAuthenticate?: (token: string, mfaCode?: string) => Promise<unknown>;
  onCredentialAuthenticate?: (
    identifier: string,
    password: string,
    mfaCode: string,
  ) => Promise<void>;
}
type LoginStage = "loading" | "signin" | "signup" | "enroll" | "backup";

export function LoginPage({ onCredentialAuthenticate }: LoginPageProps) {
  const [stage, setStage] = useState<LoginStage>("loading");
  const [bootstrapAvailable, setBootstrapAvailable] = useState(false);
  const [setupKey, setSetupKey] = useState("");
  const [fullName, setFullName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [identifier, setIdentifier] = useState("");
  const [loginPassword, setLoginPassword] = useState("");
  const [mfaCode, setMfaCode] = useState("");
  const [setupToken, setSetupToken] = useState("");
  const [enrollmentSecret, setEnrollmentSecret] = useState("");
  const [otpauthUri, setOtpauthUri] = useState("");
  const [backupCodes, setBackupCodes] = useState<string[]>([]);
  const [error, setError] = useState("");
  const [isSubmitting, setIsSubmitting] = useState(false);

  async function refreshBootstrapStatus() {
    try {
      const status = await adminAuthService.getSuperAdminBootstrapStatus();
      setBootstrapAvailable(status.available);
      setStage(status.available ? "signup" : "signin");
    } catch {
      setBootstrapAvailable(false);
      setStage("signin");
    }
  }
  useEffect(() => {
    void refreshBootstrapStatus();
  }, []);

  async function submitSignup(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError("");
    setIsSubmitting(true);
    try {
      const created = await adminAuthService.bootstrapSuperAdmin(
        setupKey.trim(),
        fullName.trim(),
        email.trim(),
        password,
      );
      setSetupToken(created.accessToken);
      setSetupKey("");
      setPassword("");
      const enrollment = await adminAuthService.startMfaEnrollment(
        created.accessToken,
      );
      setEnrollmentSecret(enrollment.secret);
      setOtpauthUri(enrollment.otpauthUri);
      setStage("enroll");
    } catch (cause) {
      setError(
        cause instanceof Error
          ? cause.message
          : "Initial Super Admin registration failed.",
      );
    } finally {
      setIsSubmitting(false);
    }
  }

  async function verifyEnrollment(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError("");
    setIsSubmitting(true);
    try {
      const result = await adminAuthService.verifyMfaEnrollment(
        setupToken,
        mfaCode.trim(),
      );
      setBackupCodes(result.backupCodes);
      setMfaCode("");
      setStage("backup");
    } catch (cause) {
      setError(
        cause instanceof Error
          ? cause.message
          : "Authenticator verification failed.",
      );
    } finally {
      setIsSubmitting(false);
    }
  }

  async function submitSignin(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError("");
    if (!onCredentialAuthenticate) {
      setError("Email/password sign-in is unavailable in this build.");
      return;
    }
    setIsSubmitting(true);
    try {
      await onCredentialAuthenticate(
        identifier.trim(),
        loginPassword,
        mfaCode.trim(),
      );
      setLoginPassword("");
      setMfaCode("");
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : "Sign-in failed.");
    } finally {
      setIsSubmitting(false);
    }
  }

  function finishBootstrap() {
    setSetupToken("");
    setEnrollmentSecret("");
    setOtpauthUri("");
    setBackupCodes([]);
    setFullName("");
    setEmail("");
    setStage("signin");
    setBootstrapAvailable(false);
  }

  const staging = isStagingTestAdminMode;
  return (
    <main className="login-page">
      <div className="login-orb login-orb--one" aria-hidden="true" />
      <div className="login-orb login-orb--two" aria-hidden="true" />
      <header className="login-topbar">
        <BrandMark />
        <StatusPill tone="demo">
          <span className="status-pill__dot" />{" "}
          {staging ? "STAGING ADMIN PORTAL" : "DEV / TEST ADMIN PORTAL"}
        </StatusPill>
      </header>
      <div className="login-layout">
        <section className="login-story">
          <div className="login-eyebrow">
            <span className="login-eyebrow__star">
              <Sparkles size={14} />
            </span>{" "}
            THE SAKHI OPERATIONS SPACE
          </div>
          <h1>
            Care begins with
            <br />
            <em>clarity.</em>
          </h1>
          <p className="login-story-copy">
            Secure role-based administration for the Super Admin and six
            specialized Normal Admin roles.
          </p>
          <div className="login-feature-list">
            <div>
              <span className="login-feature-icon">
                <ShieldCheck size={18} />
              </span>
              <span>
                <strong>Individual staff identity</strong>
                <small>
                  Every administrator signs in with their own email and
                  password.
                </small>
              </span>
            </div>
            <div>
              <span className="login-feature-icon">
                <LockKeyhole size={18} />
              </span>
              <span>
                <strong>Mandatory authenticator MFA</strong>
                <small>
                  RFC 6238 TOTP, replay protection and single-use backup codes.
                </small>
              </span>
            </div>
            <div>
              <span className="login-feature-icon">
                <ShieldCheck size={18} />
              </span>
              <span>
                <strong>One-time Super Admin registration</strong>
                <small>
                  Initial registration closes permanently after the first
                  account is created.
                </small>
              </span>
            </div>
          </div>
        </section>
        <section className="login-card" aria-labelledby="login-title">
          <div className="login-card-mark">
            <ShieldCheck size={24} />
          </div>
          <div className="login-card-kicker">
            {staging
              ? "STAGING ADMIN & STAFF PORTAL"
              : "LOCAL ADMIN & STAFF PORTAL"}
          </div>

          {stage === "loading" && (
            <h2 id="login-title">Checking secure setup…</h2>
          )}

          {stage === "signup" && (
            <>
              <h2 id="login-title">Create the first Super Admin</h2>
              <p className="login-card-description">
                This one-time registration creates the initial Super Admin
                account. Set your password now, then enroll and verify your
                authenticator before the account can sign in.
              </p>
              <form onSubmit={submitSignup}>
                <label className="member-form-label" htmlFor="setup-key">
                  One-time Super Admin setup key <span>Required</span>
                </label>
                <input
                  id="setup-key"
                  className="admin-review-token-input"
                  type="password"
                  autoComplete="off"
                  value={setupKey}
                  onChange={(e) => setSetupKey(e.target.value)}
                  minLength={8}
                  required
                />
                <p className="admin-review-help">
                  This is a one-time registration authorization, not a staff
                  login or access token.
                </p>
                <label className="member-form-label" htmlFor="superadmin-name">
                  Full name <span>Required</span>
                </label>
                <input
                  id="superadmin-name"
                  className="admin-review-token-input"
                  value={fullName}
                  onChange={(e) => setFullName(e.target.value)}
                  minLength={3}
                  maxLength={120}
                  autoComplete="name"
                  required
                />
                <label className="member-form-label" htmlFor="superadmin-email">
                  Admin email <span>Required</span>
                </label>
                <input
                  id="superadmin-email"
                  className="admin-review-token-input"
                  type="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  maxLength={254}
                  autoComplete="email"
                  required
                />
                <label
                  className="member-form-label"
                  htmlFor="superadmin-password"
                >
                  Create password <span>Required</span>
                </label>
                <input
                  id="superadmin-password"
                  className="admin-review-token-input"
                  type="password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  minLength={12}
                  maxLength={128}
                  autoComplete="new-password"
                  required
                />
                <p className="admin-review-help">
                  Use at least 12 characters. Your password is securely hashed
                  and stored; it is never displayed again.
                </p>
                {error && (
                  <p className="admin-review-error" role="alert">
                    {error}
                  </p>
                )}
                <button
                  className="button button--primary login-submit"
                  type="submit"
                  disabled={
                    isSubmitting ||
                    setupKey.trim().length < 8 ||
                    fullName.trim().length < 3 ||
                    !email.includes("@") ||
                    password.length < 12
                  }
                >
                  {isSubmitting
                    ? "Creating secure account…"
                    : "Register Super Admin"}{" "}
                  <ArrowRight size={17} />
                </button>
              </form>
              <button
                className="button login-submit"
                type="button"
                disabled={isSubmitting}
                onClick={() => {
                  setError("");
                  setStage("signin");
                }}
              >
                Already registered? Sign in
              </button>
            </>
          )}

          {stage === "enroll" && (
            <>
              <h2 id="login-title">Set up your authenticator</h2>
              <p className="login-card-description">
                Add this account to an RFC 6238-compatible authenticator app.
                Then enter its current six-digit code to enable MFA.
              </p>
              <div
                className="admin-review-help"
                role="group"
                aria-label="Authenticator setup"
              >
                <p>
                  <strong>Manual setup secret</strong>
                </p>
                <code style={{ overflowWrap: "anywhere", userSelect: "all" }}>
                  {enrollmentSecret}
                </code>
                <p>
                  <strong>Authenticator setup URI</strong>
                </p>
                <code style={{ overflowWrap: "anywhere", userSelect: "all" }}>
                  {otpauthUri}
                </code>
              </div>
              <form onSubmit={verifyEnrollment}>
                <label className="member-form-label" htmlFor="enrollment-code">
                  Six-digit authenticator code <span>Required</span>
                </label>
                <input
                  id="enrollment-code"
                  className="admin-review-token-input"
                  inputMode="numeric"
                  autoComplete="one-time-code"
                  value={mfaCode}
                  onChange={(e) => setMfaCode(e.target.value)}
                  minLength={6}
                  maxLength={6}
                  required
                />
                {error && (
                  <p className="admin-review-error" role="alert">
                    {error}
                  </p>
                )}
                <button
                  className="button button--primary login-submit"
                  type="submit"
                  disabled={isSubmitting || mfaCode.trim().length !== 6}
                >
                  {isSubmitting ? "Verifying…" : "Verify and enable MFA"}{" "}
                  <ArrowRight size={17} />
                </button>
              </form>
            </>
          )}

          {stage === "backup" && (
            <>
              <h2 id="login-title">Save your recovery codes</h2>
              <p className="login-card-description">
                Your authenticator is verified. Save these single-use recovery
                codes in a secure password manager. They will not be shown
                again.
              </p>
              <div
                className="admin-review-help"
                role="group"
                aria-label="Single-use recovery codes"
              >
                <strong>Super Admin backup codes</strong>
                <ul>
                  {backupCodes.map((code) => (
                    <li key={code}>
                      <code>{code}</code>
                    </li>
                  ))}
                </ul>
              </div>
              <button
                className="button button--primary login-submit"
                type="button"
                onClick={finishBootstrap}
              >
                I saved my recovery codes <ArrowRight size={17} />
              </button>
            </>
          )}

          {stage === "signin" && (
            <>
              <h2 id="login-title">Admin sign in</h2>
              <p className="login-card-description">
                Sign in with your assigned admin email, password and
                authenticator code.
              </p>
              <form onSubmit={submitSignin} className="login-credential-form">
                <label className="member-form-label" htmlFor="admin-identifier">
                  Admin email <span>Required</span>
                </label>
                <input
                  id="admin-identifier"
                  className="admin-review-token-input"
                  type="email"
                  value={identifier}
                  onChange={(e) => setIdentifier(e.target.value)}
                  autoComplete="username"
                  required
                />
                <label className="member-form-label" htmlFor="admin-password">
                  Password <span>Required</span>
                </label>
                <input
                  id="admin-password"
                  className="admin-review-token-input"
                  type="password"
                  value={loginPassword}
                  onChange={(e) => setLoginPassword(e.target.value)}
                  autoComplete="current-password"
                  required
                />
                <label className="member-form-label" htmlFor="admin-mfa-code">
                  Authenticator / backup code <span>Required</span>
                </label>
                <input
                  id="admin-mfa-code"
                  className="admin-review-token-input"
                  value={mfaCode}
                  onChange={(e) => setMfaCode(e.target.value)}
                  autoComplete="one-time-code"
                  required
                />
                {error && (
                  <p className="admin-review-error" role="alert">
                    {error}
                  </p>
                )}
                <button
                  className="button button--primary login-submit"
                  type="submit"
                  disabled={
                    isSubmitting ||
                    !identifier.trim() ||
                    !loginPassword ||
                    !mfaCode.trim()
                  }
                >
                  {isSubmitting ? "Verifying credentials…" : "Sign in"}{" "}
                  <ArrowRight size={17} />
                </button>
              </form>
              {bootstrapAvailable && (
                <button
                  className="button login-submit"
                  type="button"
                  onClick={() => {
                    setError("");
                    setStage("signup");
                  }}
                >
                  First-time Super Admin registration <ArrowRight size={17} />
                </button>
              )}
              <button
                className="button login-submit"
                type="button"
                onClick={() => void refreshBootstrapStatus()}
              >
                Refresh registration status
              </button>
            </>
          )}

          <div className="demo-notice">
            <span className="demo-notice-icon">
              <LockKeyhole size={17} />
            </span>
            <div>
              <strong>Role-Based Access Control (RBAC)</strong>
              <p>
                Backend authorization is enforced for every staff role. Frontend
                route visibility is not an authorization boundary.
              </p>
            </div>
          </div>
          <div className="login-card-footer">
            Sakhi Administration <span>-</span> Secure Staff Authentication
          </div>
        </section>
      </div>
      <footer className="login-footer">
        <span>SAKHI - PRIVATE ADMINISTRATION UI</span>
        <span>
          <LockKeyhole size={13} /> {staging ? "Staging RBAC" : "Dev/test RBAC"}
        </span>
      </footer>
    </main>
  );
}
