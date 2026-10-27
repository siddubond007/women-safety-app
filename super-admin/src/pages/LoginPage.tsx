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
      <header className="login-topbar"><BrandMark /><StatusPill tone="demo"><span className="status-pill__dot" /> {staging ? "STAGING RBAC PORTAL" : "DEV / TEST RBAC PORTAL"}</StatusPill></header>
      <div className="login-layout">
        <section className="login-story">
          <div className="login-eyebrow"><span className="login-eyebrow__star"><Sparkles size={14} /></span> THE SAKHI OPERATIONS SPACE</div>
          <h1>Care begins with<br /><em>clarity.</em></h1>
          <p className="login-story-copy">Role-based administration for Super Admin and the 5 specialized Normal Admin roles (Verification, Content Moderation, Authorised Complaint Reviewer, SOS Safety, and Business Marketplace).</p>
          <div className="login-feature-list">
            <div><span className="login-feature-icon"><ShieldCheck size={18} /></span><span><strong>Super Admin &amp; 5 Role-Specific Panels</strong><small>Sign in with the Master Super Admin token for full governance, or use an issued Staff Token (e.g. SAKHI-CR-...) to open that role&apos;s dedicated panel.</small></span></div>
            <div><span className="login-feature-icon"><LockKeyhole size={18} /></span><span><strong>Strict Least-Privilege Isolation (SRS 7.4 &amp; 12.2)</strong><small>Ordinary moderators are blocked from Discreet Complaints, and no admin can view raw Aadhaar numbers or private menstrual health logs.</small></span></div>
            <div><span className="login-feature-icon"><ShieldCheck size={18} /></span><span><strong>Immutable Audit Trail</strong><small>Every decision, status transition, and evidence reveal records the authenticated admin&apos;s staff code and reason.</small></span></div>
          </div>
        </section>
        <section className="login-card" aria-labelledby="login-title">
          <div className="login-card-mark"><ShieldCheck size={24} /></div>
          <div className="login-card-kicker">{staging ? "STAGING ADMIN & STAFF PORTAL" : "LOCAL ADMIN & STAFF PORTAL"}</div>
          <h2 id="login-title">Admin or Reviewer Sign In</h2>
          <p className="login-card-description">{staging ? "Enter SAKHI_STAGING_FULL_ADMIN_TOKEN for Super Admin governance, a Staff Access Token (SAKHI-CR-...) issued in Admin Users & Roles, or SAKHI_STAGING_TEST_ADMIN_TOKEN." : "Enter the local Super Admin token (ADMIN2026TEST) or a Role-Based Staff Access Token created in Admin Users & Roles."}</p>
          <form onSubmit={submit}>
            <label className="member-form-label" htmlFor="reviewer-token">Super Admin or Staff Access Token <span>Required</span></label>
            <input id="reviewer-token" className="admin-review-token-input" type="password" autoComplete="off" value={token} onChange={(event) => setToken(event.target.value)} minLength={8} required aria-describedby="reviewer-token-help" />
            <p id="reviewer-token-help" className="admin-review-help">{staging ? <>Use <code>SAKHI_STAGING_FULL_ADMIN_TOKEN</code> for Super Admin, or paste a personal Staff Token (such as <code>SAKHI-CR-...</code>) issued by Super Admin in <strong>Admin users &amp; roles</strong>.</> : <>Use <code>ADMIN2026TEST</code> (or the token from the backend terminal) for Super Admin, or paste a Staff Token issued in <strong>Admin users &amp; roles</strong>.</>}</p>
            {error && <p className="admin-review-error" role="alert">{error}</p>}
            <button className="button button--primary login-submit" type="submit" disabled={isSubmitting || token.trim().length < 8}>{isSubmitting ? "Checking role & access..." : "Sign in to workspace"} <ArrowRight size={17} /></button>
          </form>
          <div className="demo-notice"><span className="demo-notice-icon"><LockKeyhole size={17} /></span><div><strong>Role-Based Access Control (RBAC)</strong><p>Once signed in as Super Admin, open <strong>Admin users &amp; roles</strong> in the left sidebar to create real Normal Admin accounts and Authorised Complaint Reviewers.</p></div></div>
          <div className="login-card-footer">Sakhi Administration <span>-</span> Super Admin &amp; 5 Role Panels</div>
        </section>
      </div>
      <footer className="login-footer"><span>SAKHI - PRIVATE ADMINISTRATION UI</span><span><LockKeyhole size={13} /> {staging ? "Staging RBAC" : "Dev/test RBAC"}</span></footer>
    </main>
  );
}
