import { ArrowLeft, CircleDashed, Construction, ShieldCheck } from "lucide-react";
import { Link, useLocation } from "react-router-dom";
import { StatusPill } from "../components/StatusPill";

const pageNames: Record<string, { title: string; description: string; group: string }> = {
  "/action-center": { title: "Action center", description: "A prioritized view of assigned tasks, escalations and overdue operational queues.", group: "Workspace" },
  "/members": { title: "Members & accounts", description: "Member directory, role-filtered profiles, account state and approved lifecycle actions.", group: "People & trust" },
  "/verification": { title: "Eligibility & verification", description: "Review queue, reviewer assignment, decision history and appeals after eligibility policy is approved.", group: "People & trust" },
  "/moderation": { title: "Trust & safety", description: "Review reported profiles, posts, comments and business listings with auditable decisions.", group: "People & trust" },
  "/complaints": { title: "Complaints & cases", description: "Restricted complaint workflows with separate internal notes, careful evidence access and protected reporter identity.", group: "People & trust" },
  "/emergency": { title: "SOS & emergency operations", description: "Authorized event-level review and truthful action-state reporting. Live location and official emergency integration remain undecided.", group: "People & trust" },
  "/community": { title: "Community content", description: "Manage authorized community content, report history and publication review.", group: "Platform operations" },
  "/businesses": { title: "Business management", description: "Business directory, application review, listing status and fraud reports.", group: "Platform operations" },
  "/wellness": { title: "Wellness content", description: "Manage reviewed educational resources without exposing individual health histories.", group: "Platform operations" },
  "/notifications": { title: "Notifications", description: "Prepare provider status, safe template management and delivery failure workflows.", group: "Platform operations" },
  "/support": { title: "Support desk", description: "Ticket assignment, priority, response tracking and controlled escalation.", group: "Platform operations" },
  "/analytics": { title: "Analytics & reports", description: "Permission-filtered aggregate metrics with minimized and auditable exports.", group: "Insights & security" },
  "/privacy": { title: "Privacy & data rights", description: "Track access, correction, export, deletion, retention and privacy incident requests.", group: "Insights & security" },
  "/admin-users": { title: "Admin users & roles", description: "Proposed roles and permission mapping. Production authorization must be enforced by the backend.", group: "Insights & security" },
  "/audit-security": { title: "Audit trail & security", description: "Audit sensitive actions, access denials, security events and approved investigations.", group: "Insights & security" },
  "/integrations": { title: "Integrations & system health", description: "Backend, storage, notification, maps and approved verification integration status.", group: "Insights & security" },
  "/backups": { title: "Backups & recovery", description: "Backup evidence, restore-test history, recovery runbooks and incident ownership.", group: "Insights & security" },
  "/settings": { title: "Platform settings", description: "Controlled reference data, policy versions, feature flags and approved operational configuration.", group: "Insights & security" },
};

export function PlannedPage() {
  const location = useLocation();
  const page = pageNames[location.pathname] ?? {
    title: "Workspace module",
    description: "This route is reserved for a future authorized administration workflow.",
    group: "Planned module",
  };

  return (
    <section className="planned-page">
      <div className="planned-breadcrumb"><Link to="/dashboard"><ArrowLeft size={14} /> Overview dashboard</Link><span>/</span><span>{page.group}</span></div>
      <div className="planned-hero">
        <div className="planned-icon"><Construction size={24} /></div>
        <StatusPill tone="amber"><CircleDashed size={12} /> PLANNED</StatusPill>
        <h1>{page.title}</h1>
        <p>{page.description}</p>
        <div className="planned-rule" />
        <div className="planned-details">
          <div><ShieldCheck size={18} /><span><strong>Security-first implementation</strong><small>Permission boundaries and audit requirements will be defined before real record access is added.</small></span></div>
          <div><CircleDashed size={18} /><span><strong>Not implemented in Stage 1</strong><small>This page is an explicit placeholder, not a working production module.</small></span></div>
        </div>
        <Link to="/dashboard" className="button button--secondary planned-return">Return to overview</Link>
      </div>
    </section>
  );
}