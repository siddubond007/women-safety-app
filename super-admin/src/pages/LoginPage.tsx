import { useState, type FormEvent } from "react";
import { ArrowRight, LockKeyhole, ShieldCheck, Sparkles } from "lucide-react";
import { BrandMark } from "../components/BrandMark";
import { StatusPill } from "../components/StatusPill";

const DEFAULT_DEV_TOKEN = 'ADMIN2026TEST';

interface LoginPageProps {
  onAuthenticate: (token: string) => Promise<void>;
}

export function LoginPage({ onAuthenticate }: LoginPageProps) {
  const [token, setToken] = useState(DEFAULT_DEV_TOKEN);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState("");

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError("");
    setIsSubmitting(true);
    try {
      await onAuthenticate(token.trim());
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : "Reviewer authentication failed.");
    } finally {
      setIsSubmitting(false);
    }
  }

  return (
    <main className="login-page">
      <div className="login-orb login-orb--one" aria-hidden="true" />
      <div className="login-orb login-orb--two" aria-hidden="true" />
      <header className="login-topbar"><BrandMark /><StatusPill tone="demo"><span className="status-pill__dot" /> DEV / TEST ONLY</StatusPill></header>
      <div className="login-layout">
        <section className="login-story">
          <div className="login-eyebrow"><span className="login-eyebrow__star"><Sparkles size={14} /></span> THE SAKHI OPERATIONS SPACE</div>
          <h1>Care begins with<br /><em>clarity.</em></h1>
          <p className="login-story-copy">A focused workspace for the team responsible for careful, accountable manual eligibility review and member account state management.</p>
          <div className="login-feature-list">
            <div><span className="login-feature-icon"><ShieldCheck size={18} /></span><span><strong>Server-checked reviewer access</strong><small>Each review API request is checked by the backend.</small></span></div>
            <div><span className="login-feature-icon"><LockKeyhole size={18} /></span><span><strong>Live PostgreSQL state</strong><small>Approve, verify, or restrict registered accounts in real time.</small></span></div>
            <div><span className="login-feature-icon"><ShieldCheck size={18} /></span><span><strong>Auditable decisions</strong><small>Decision, reason, reviewer label and timestamp are persisted.</small></span></div>
          </div>
        </section>
        <section className="login-card" aria-labelledby="login-title">
          <div className="login-card-mark"><ShieldCheck size={24} /></div>
          <div className="login-card-kicker">LOCAL REVIEWER PORTAL</div>
          <h2 id="login-title">Reviewer sign in</h2>
          <p className="login-card-description">The local development reviewer token is pre-filled below. Click Sign in to manage member verification states.</p>
          <form onSubmit={submit}>
            <label className="member-form-label" htmlFor="reviewer-token">Reviewer token <span>Required</span></label>
            <input id="reviewer-token" className="admin-review-token-input" type="text" autoComplete="off" value={token} onChange={(event) => setToken(event.target.value)} minLength={8} required aria-describedby="reviewer-token-help" />
            <p id="reviewer-token-help" className="admin-review-help">Default local dev token: <code>{DEFAULT_DEV_TOKEN}</code></p>
            {error && <p className="admin-review-error" role="alert">{error}</p>}
            <button className="button button--primary login-submit" type="submit" disabled={isSubmitting || token.trim().length < 8}>{isSubmitting ? "Checking reviewer access..." : "Sign in to review"} <ArrowRight size={17} /></button>
          </form>
          <div className="demo-notice"><span className="demo-notice-icon"><LockKeyhole size={17} /></span><div><strong>Development-only reviewer gate</strong><p>Once signed in, open Members &amp; accounts to verify any registered phone number and unlock their mobile Home screen.</p></div></div>
          <div className="login-card-footer">Sakhi Super Admin <span>-</span> Manual eligibility review</div>
        </section>
      </div>
      <footer className="login-footer"><span>SAKHI - PRIVATE ADMINISTRATION UI</span><span><LockKeyhole size={13} /> Dev/test only</span></footer>
    </main>
  );
}

