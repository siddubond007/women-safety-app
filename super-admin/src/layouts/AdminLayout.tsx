import { useMemo, useState } from "react";
import {
  Activity,
  AlertTriangle,
  ArrowUpRight,
  Bell,
  BookOpenText,
  BriefcaseBusiness,
  Building2,
  ChartNoAxesCombined,
  ChevronDown,
  ClipboardCheck,
  FileClock,
  HeartPulse,
  HelpCircle,
  LayoutDashboard,
  LifeBuoy,
  LockKeyhole,
  LogOut,
  Menu,
  MessageSquareWarning,
  Search,
  Settings2,
  Shield,
  ShieldAlert,
  ShieldCheck,
  Siren,
  Users,
  UserRoundCheck,
  X,
  type LucideIcon,
} from "lucide-react";
import { Link, NavLink, Outlet, useLocation } from "react-router-dom";
import { BrandMark } from "../components/BrandMark";
import { StatusPill } from "../components/StatusPill";
import { adminAuthService, isStagingTestAdminMode } from "../services/auth/adminAuthService";

interface AdminLayoutProps {
  onSignOut: () => void;
}

interface NavigationItem {
  label: string;
  path: string;
  icon: LucideIcon;
  group: string;
  planned?: boolean;
}

const navigationItems: NavigationItem[] = [
  { label: "Overview dashboard", path: "/dashboard", icon: LayoutDashboard, group: "Workspace" },
  { label: "Action center", path: "/action-center", icon: Activity, group: "Workspace" },
  { label: "Members & accounts", path: "/members", icon: Users, group: "People & trust" },
  { label: "Eligibility & verification", path: "/verification", icon: UserRoundCheck, group: "People & trust" },
  { label: "Trust & safety", path: "/moderation", icon: ShieldAlert, group: "People & trust" },
  { label: "Complaints & cases", path: "/complaints", icon: MessageSquareWarning, group: "People & trust" },
  { label: "SOS & emergency", path: "/emergency", icon: Siren, group: "People & trust" },
  { label: "Community content", path: "/community", icon: BookOpenText, group: "Platform operations" },
  { label: "Business management", path: "/businesses", icon: Building2, group: "Platform operations" },
  { label: "Wellness content", path: "/wellness", icon: HeartPulse, group: "Platform operations" },
  { label: "Notifications", path: "/notifications", icon: Bell, group: "Platform operations", planned: true },
  { label: "Support desk", path: "/support", icon: LifeBuoy, group: "Platform operations", planned: true },
  { label: "Analytics & reports", path: "/analytics", icon: ChartNoAxesCombined, group: "Insights & security", planned: true },
  { label: "Privacy & data rights", path: "/privacy", icon: LockKeyhole, group: "Insights & security", planned: true },
  { label: "Admin users & roles", path: "/admin-users", icon: Shield, group: "Insights & security" },
  { label: "Audit trail & security", path: "/audit-security", icon: FileClock, group: "Insights & security" },
  { label: "Integrations & health", path: "/integrations", icon: Settings2, group: "Insights & security" },
  { label: "Backups & recovery", path: "/backups", icon: ClipboardCheck, group: "Insights & security", planned: true },
  { label: "Platform settings", path: "/settings", icon: BriefcaseBusiness, group: "Insights & security" },
];

const groupNames = ["Workspace", "People & trust", "Platform operations", "Insights & security"];

export function AdminLayout({ onSignOut }: AdminLayoutProps) {
  const location = useLocation();
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);
  const [searchOpen, setSearchOpen] = useState(false);
  const [searchQuery, setSearchQuery] = useState("");
  const [notificationsOpen, setNotificationsOpen] = useState(false);
  const hasFullStagingAdminAccess =
    !isStagingTestAdminMode || adminAuthService.isFullStagingAdminSession();
  const profile = adminAuthService.getProfile();

  const visibleNavigationItems = useMemo<NavigationItem[]>(() => {
    const roleFiltered = navigationItems.filter((item) =>
      adminAuthService.canAccessRoute(item.path),
    );
    if (!isStagingTestAdminMode) return roleFiltered;
    const testAccessItem: NavigationItem = {
      label: "Staging Test Access",
      path: "/test-access",
      icon: ShieldCheck,
      group: "Testing",
    };
    return hasFullStagingAdminAccess
      ? profile.role === "SUPER_ADMIN"
        ? [...roleFiltered, testAccessItem]
        : roleFiltered
      : [testAccessItem];
  }, [hasFullStagingAdminAccess, profile.role]);

  const visibleGroupNames = useMemo(() => {
    const groupsWithItems = groupNames.filter((g) =>
      visibleNavigationItems.some((item) => item.group === g),
    );
    if (
      isStagingTestAdminMode &&
      visibleNavigationItems.some((i) => i.group === "Testing")
    ) {
      return [...groupsWithItems, "Testing"];
    }
    return groupsWithItems;
  }, [visibleNavigationItems]);

  const pageTitle = visibleNavigationItems.find((item) => item.path === location.pathname)?.label ?? "Admin workspace";
  const searchMatches = useMemo(() => {
    const query = searchQuery.trim().toLowerCase();
    if (!query) return visibleNavigationItems.filter((item) => !item.planned);
    return visibleNavigationItems.filter((item) => item.label.toLowerCase().includes(query));
  }, [searchQuery, visibleNavigationItems]);

  function closeOverlays() {
    setMobileMenuOpen(false);
    setSearchOpen(false);
  }

  const initials = (profile.fullName || "SA")
    .split(" ")
    .map((w) => w[0])
    .join("")
    .slice(0, 2)
    .toUpperCase();

  return (
    <div className="admin-shell">
      {mobileMenuOpen && (
        <button className="mobile-overlay" type="button" aria-label="Close navigation" onClick={closeOverlays} />
      )}
      <aside className={mobileMenuOpen ? "sidebar sidebar--open" : "sidebar"}>
        <div className="sidebar-brand-row">
          <Link className="sidebar-brand-link" to="/dashboard" onClick={closeOverlays} aria-label="Sakhi admin overview">
            <BrandMark />
          </Link>
          <button className="icon-button sidebar-close" type="button" onClick={closeOverlays} aria-label="Close navigation">
            <X size={18} />
          </button>
        </div>

        <div className="environment-card">
          <span className="environment-icon"><ShieldCheckIcon /></span>
          <span className="environment-copy">
            <strong>{profile.badgeLabel} ({profile.staffCode})</strong>
            <small>{profile.roleTitle}</small>
          </span>
          <span className="environment-dot" aria-hidden="true" />
        </div>

        <nav className="sidebar-nav" aria-label="Admin navigation">
          {visibleGroupNames.map((groupName) => (
            <div className="nav-group" key={groupName}>
              <p className="nav-group-title">{groupName}</p>
              {visibleNavigationItems.filter((item) => item.group === groupName).map((item) => {
                const Icon = item.icon;
                return (
                  <NavLink
                    to={item.path}
                    key={item.path}
                    end
                    onClick={closeOverlays}
                    className={({ isActive }) => "nav-link" + (isActive ? " nav-link--active" : "")}
                    title={item.planned ? item.label + " - planned" : item.label}
                  >
                    <Icon size={17} strokeWidth={1.8} />
                    <span className="nav-link-label">{item.label}</span>
                    {item.planned && <span className="nav-planned-dot" aria-label="Planned module" />}
                  </NavLink>
                );
              })}
            </div>
          ))}
        </nav>

        <div className="sidebar-bottom">
          <div className="help-card">
            <span className="help-card__icon"><HelpCircle size={17} /></span>
            <div>
              <strong>RBAC Clearance</strong>
              <span>{profile.role === "SUPER_ADMIN" ? "Master Governance" : `${visibleNavigationItems.length} Authorized Modules`}</span>
            </div>
            <ArrowUpRight size={15} />
          </div>
          <div className="sidebar-footer">
            <span className="sidebar-footer__mark">{initials}</span>
            <div className="sidebar-footer__copy">
              <strong>{profile.fullName}</strong>
              <span>{profile.email}</span>
            </div>
            <StatusPill tone="demo">{profile.staffCode}</StatusPill>
          </div>
        </div>
      </aside>

      <div className="main-column">
        <header className="topbar">
          <div className="topbar-left">
            <button className="icon-button mobile-menu-button" type="button" onClick={() => setMobileMenuOpen(true)} aria-label="Open navigation">
              <Menu size={20} />
            </button>
            <div className="breadcrumbs"><span>{profile.badgeLabel}</span><span className="breadcrumb-separator">/</span><strong>{pageTitle}</strong></div>
          </div>
          <div className="topbar-actions">
            <div className="global-search">
              {searchOpen ? (
                <div className="search-field-wrap">
                  <Search size={17} />
                  <input
                    autoFocus
                    aria-label="Search admin modules"
                    placeholder="Search modules..."
                    value={searchQuery}
                    onChange={(event) => setSearchQuery(event.target.value)}
                    onKeyDown={(event) => {
                      if (event.key === "Escape") {
                        setSearchOpen(false);
                        setSearchQuery("");
                      }
                    }}
                  />
                  <button className="search-close" type="button" onClick={() => { setSearchOpen(false); setSearchQuery(""); }} aria-label="Close search"><X size={15} /></button>
                  <div className="search-results" role="listbox" aria-label="Module search results">
                    {searchMatches.length ? searchMatches.slice(0, 7).map((item) => (
                      <Link key={item.path} to={item.path} onClick={() => { setSearchOpen(false); setSearchQuery(""); }} className="search-result">
                        <span>{item.label}</span>
                        {item.planned && <small>Planned</small>}
                      </Link>
                    )) : <p className="search-empty">No matching module</p>}
                  </div>
                </div>
              ) : (
                <button className="search-launch" type="button" onClick={() => setSearchOpen(true)} aria-label="Search admin modules">
                  <Search size={17} /><span>Search modules</span><kbd>/</kbd>
                </button>
              )}
            </div>

            <div className="notification-wrap">
              <button className={"icon-button notification-button" + (notificationsOpen ? " icon-button--active" : "")} type="button" onClick={() => setNotificationsOpen(!notificationsOpen)} aria-label="Show notification integration status" aria-expanded={notificationsOpen}>
                <Bell size={19} />
              </button>
              {notificationsOpen && (
                <div className="notification-popover">
                  <div className="popover-heading"><strong>Live Admin Feed</strong><span>Connected to PostgreSQL</span></div>
                  <div className="popover-foot">Signed in as {profile.fullName} ({profile.roleTitle}). Least-privilege RBAC and audit logging are enforced.</div>
                </div>
              )}
            </div>

            <div className="topbar-divider" />
            <button className="admin-profile" type="button" onClick={onSignOut} title="Sign out of admin session">
              <span className="admin-avatar">{initials}</span>
              <span className="admin-profile-copy"><strong>{profile.fullName} ({profile.staffCode})</strong><small>{profile.badgeLabel}</small></span>
              <ChevronDown size={15} />
              <span className="profile-signout"><LogOut size={13} /> Sign out</span>
            </button>
          </div>
        </header>

        <main className="page-content">
          <div className="demo-banner" role="status">
            <span className="demo-banner__icon"><AlertTriangle size={16} /></span>
            <div>
              <strong>{profile.roleTitle.toUpperCase()} ({profile.staffCode})</strong>
              <span>{profile.role === "SUPER_ADMIN" ? "Master Super Admin governance session active. Manage the 5 Normal Admin roles in Admin users & roles." : `Role-restricted workspace active. Only modules authorized for ${profile.badgeLabel} are accessible.`}</span>
            </div>
            <StatusPill tone="demo">{profile.badgeLabel}</StatusPill>
          </div>
          <Outlet />
          <footer className="page-footer">
            <span>SAKHI ADMIN CONTROL CENTER • {profile.badgeLabel.toUpperCase()}</span>
            <span>{isStagingTestAdminMode ? <>Hosted staging <span className="footer-dot">-</span> Connected backend data</> : <>Local development/test <span className="footer-dot">-</span> Connected backend data</>}</span>
          </footer>
        </main>
      </div>
    </div>
  );
}

function ShieldCheckIcon() {
  return <Shield size={16} />;
}
