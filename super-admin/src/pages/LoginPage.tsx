import { ArrowRight, CheckCircle2, LockKeyhole, ShieldCheck, Sparkles } from "lucide-react";
import { BrandMark } from "../components/BrandMark";
import { StatusPill } from "../components/StatusPill";

interface LoginPageProps {
  onEnterDemo: () => void;
}

export function LoginPage({ onEnterDemo }: LoginPageProps) {
  return (
    <main className="login-page">
      <div className="login-orb login-orb--one" aria-hidden="true" />
      <div className="login-orb login-orb--two" aria-hidden="true" />
      <header className="login-topbar">
        <BrandMark />
        <StatusPill tone="demo"><span className="status-pill__dot" /> DEMO PREVIEW</StatusPill>
      </header>

      <div className="login-layout">
        <section className="login-story">
          <div className="login-eyebrow"><span className="login-eyebrow__star"><Sparkles size={14} /></span> THE SAKHI OPERATIONS SPACE</div>
          <h1>Care begins with<br /><em>clarity.</em></h1>
          <p className="login-story-copy">A focused workspace for the teams working behind Sakhi's safety, community, wellbeing and business experiences.</p>
          <div className="login-feature-list">
            <div><span className="login-feature-icon"><ShieldCheck size={18} /></span><span><strong>Safety with accountability</strong><small>Clear operational queues and review pathways.</small></span></div>
            <div><span className="login-feature-icon"><LockKeyhole size={18} /></span><span><strong>Privacy by design</strong><small>Restricted information stays out of general views.</small></span></div>
            <div><span className="login-feature-icon"><CheckCircle2 size={18} /></span><span><strong>One considered workspace</strong><small>Consistent patterns for everyday administration.</small></span></div>
          </div>
          <div className="login-quote"><span aria-hidden="true">“</span><p>Built around the people who depend on us to get the details right.</p></div>
        </section>

        <section className="login-card" aria-labelledby="login-title">
          <div className="login-card-mark"><ShieldCheck size={24} /></div>
          <div className="login-card-kicker">PRIVATE ADMIN PORTAL</div>
          <h2 id="login-title">Welcome to Sakhi</h2>
          <p className="login-card-description">Enter the local demo workspace to preview the admin foundation.</p>
          <div className="demo-notice">
            <span className="demo-notice-icon"><LockKeyhole size={17} /></span>
            <div><strong>Demo session only</strong><p>No password is requested or stored. This preview is not real authentication and does not protect production data.</p></div>
          </div>
          <button className="button button--primary login-submit" type="button" onClick={onEnterDemo}>
            Enter demo environment <ArrowRight size={17} />
          </button>
          <div className="login-divider"><span>PREVIEW MODE</span></div>
          <div className="login-protection"><ShieldCheck size={16} /><span>Real admin authentication and MFA are planned for backend integration.</span></div>
          <div className="login-card-footer">Sakhi Super Admin <span>·</span> Stage 1 prototype</div>
        </section>
      </div>

      <footer className="login-footer"><span>© Sakhi · Private administration UI</span><span><LockKeyhole size={13} /> Demo only — not for production use</span></footer>
    </main>
  );
}