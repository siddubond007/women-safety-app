import { useState, type FormEvent } from "react";
import { ArrowRight, LockKeyhole, ShieldCheck, Sparkles } from "lucide-react";
import { BrandMark } from "../components/BrandMark";
import { StatusPill } from "../components/StatusPill";
import { isStagingTestAdminMode } from "../services/auth/adminAuthService";

interface LoginPageProps {
  onAuthenticate: (token: string) => Promise<void>;
}

export function LoginPage({ onAuthenticate }: LoginPageProps) {
  const [token, setToken] = useState("");
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState("");

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError("");
    setIsSubmitting(true);
    try {
      const submittedToken = token.trim();
      if (isStagingTestAdminMode) setToken("");
      await onAuthenticate(submittedToken);
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : "Reviewer authentication failed.");
    } finally {
      setIsSubmitting(false);
    }
  }

  const staging = isStagingTestAdminMode;

  return (
    <main className="login-page">
      <div className="login-orb login-orb--one" aria-hidden="true" />
      <div className="login-orb login-orb--two" aria-hidden="true" />
      <header className="login-topbar"><BrandMark /><StatusPill tone="demo"><span className="status-pill__dot" /> {staging ? "STAGING TEST ACCESS ONLY" : "DEV / TEST ONLY"}</StatusPill></header>
      <div className="login-layout">
        <section className="login-story">
          <div className="login-eyebrow"><span className="login-eyebrow__star"><Sparkles size={14} /></span> THE SAKHI OPERATIONS SPACE</div>
          <h1>Care begins with<br /><em>clarity.</em></h1>
          <p className="login-story-copy">{staging ? "A limited staging-only control for granting and revoking app-feature access to friend testers." : "A focused workspace for the team responsible for careful, accountable manual eligibility review and member account state management."}</p>
          <div className="login-feature-list">
            <div><span className="login-feature-icon"><ShieldCheck size={18} /></span><span><strong>{staging ? "Test access only" : "Server-checked reviewer access"}</strong><small>{staging ? "Does not certify phone ownership or eligibility." : "Each review API request is checked by the backend."}</small></span></div>
            <div><span className="login-feature-icon"><LockKeyhole size={18} /></span><span><strong>Server-side access control</strong><small>The staging token is exchanged once for an eight-hour signed session held in memory only; refreshing the page signs out.</small></span></div>
            <div><span className="login-feature-icon"><ShieldCheck size={18} /></span><span><strong>Auditable decisions</strong><small>Every test-access grant or revocation records a reason and reviewer label.</small></span></div>
          </div>
        </section>
        <section className="login-card" aria-labelledby="login-title">
          <div className="login-card-mark"><ShieldCheck size={24} /></div>
          <div className="login-card-kicker">{staging ? "STAGING TEST-ACCESS PORTAL" : "LOCAL REVIEWER PORTAL"}</div>
          <h2 id="login-title">Reviewer sign in</h2>
          <p className="login-card-description">{staging ? "Enter the staging-only reviewer token configured in Render. This portal can grant test access only; it cannot approve real eligibility." : "Enter the local development reviewer token printed by the backend startup script, then sign in to review persisted member submissions."}</p>
          <form onSubmit={submit}>
            <label className="member-form-label" htmlFor="reviewer-token">Reviewer token <span>Required</span></label>
            <input id="reviewer-token" className="admin-review-token-input" type="password" autoComplete="off" value={token} onChange={(event) => setToken(event.target.value)} minLength={8} required aria-describedby="reviewer-token-help" />
            <p id="reviewer-token-help" className="admin-review-help">{staging ? <>Copy <code>SAKHI_STAGING_TEST_ADMIN_TOKEN</code> from Render → <strong>sakhi-staging-api</strong> → Environment. Do not commit or share this token.</> : <>Find it in the backend terminal after <code>Super Admin Reviewer Token:</code>.</>}</p>
            {error && <p className="admin-review-error" role="alert">{error}</p>}
            <button className="button button--primary login-submit" type="submit" disabled={isSubmitting || token.trim().length < 8}>{isSubmitting ? "Checking reviewer access..." : "Sign in to review"} <ArrowRight size={17} /></button>
          </form>
          <div className="demo-notice"><span className="demo-notice-icon"><LockKeyhole size={17} /></span><div><strong>{staging ? "Test-only approval" : "Development-only reviewer gate"}</strong><p>{staging ? "Approval only unlocks staging app features for testing. Phone ownership and actual eligibility remain unverified; no member verification fields are changed." : "Once signed in, open Members & accounts to review the local development dataset."}</p></div></div>
          <div className="login-card-footer">Sakhi Super Admin <span>-</span> {staging ? "Staging test access" : "Manual eligibility review"}</div>
        </section>
      </div>
      <footer className="login-footer"><span>SAKHI - PRIVATE ADMINISTRATION UI</span><span><LockKeyhole size={13} /> {staging ? "Staging test only" : "Dev/test only"}</span></footer>
    </main>
  );
}
