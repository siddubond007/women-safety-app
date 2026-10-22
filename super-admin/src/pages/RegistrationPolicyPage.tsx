import { ShieldCheck } from "lucide-react";
import { RegistrationPolicyPanel } from "../components/RegistrationPolicyPanel";
import { StatusPill } from "../components/StatusPill";

export function RegistrationPolicyPage() {
  return (
    <div className="dashboard-page">
      <section className="page-heading">
        <div>
          <div className="eyebrow">
            <span className="eyebrow-line" /> PLATFORM SETTINGS &amp; POLICY
          </div>
          <h1>Platform registration &amp; age policy</h1>
          <p>
            Manage the persistent minimum age policy enforced across the Sakhi mobile registration flow and backend API.
          </p>
        </div>
        <div className="heading-meta">
          <StatusPill tone="green">
            <span className="status-pill__dot" /> PERSISTED IN POSTGRESQL
          </StatusPill>
        </div>
      </section>

      <RegistrationPolicyPanel />

      <div className="dashboard-footnote">
        <ShieldCheck size={15} />
        <span>
          Every policy update is recorded in <code>platform_registration_policies</code> and audited in <code>audit_events</code>. Both mobile Screen 03 and <code>POST /api/v1/auth/profile</code> enforce this minimum age immediately.
        </span>
      </div>
    </div>
  );
}
