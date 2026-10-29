import { useCallback, useEffect, useState } from "react";
import {
  AlertTriangle,
  CheckCircle2,
  Copy,
  KeyRound,
  Lock,
  Plus,
  RefreshCw,
  Settings2,
  Shield,
  ShieldCheck,
  Trash2,
  UserCheck,
  UserPlus,
} from "lucide-react";
import { StatusPill } from "../components/StatusPill";
import { SakhiQuoteLoader } from "../components/SakhiQuoteLoader";
import { adminApi } from "../services/api/adminApi";
import type {
  GranularRolePermissions,
  SakhiAdminRole,
} from "../services/auth/adminAuthService";

interface AdminRoleDefinition {
  role: SakhiAdminRole;
  title: string;
  badgeLabel: string;
  description: string;
  allowedRoutes: string[];
  defaultPermissions: GranularRolePermissions;
  defaultClearanceLevel: string;
  canAccessDiscreetComplaints: boolean;
  canManageCategoriesAndRetention: boolean;
  privacyBoundaries: string[];
}

interface AdminStaffRecord {
  id: string;
  staffCode: string;
  fullName: string;
  email: string;
  role: SakhiAdminRole;
  status: "ACTIVE" | "SUSPENDED" | "REVOKED";
  accessTokenPreview: string;
  isAuthorisedComplaintReviewer: boolean;
  clearanceLevel: string;
  permissions: GranularRolePermissions;
  allowedRoutes: string[];
  createdBy: string;
  lastLoginAt: string | null;
  createdAt: string;
  updatedAt: string;
}

interface PlatformConfigRecord {
  configKey: string;
  featureFlags: {
    communityFeedEnabled: boolean;
    businessDirectoryEnabled: boolean;
    wellnessTrackerEnabled: boolean;
    anonymousComplaintsEnabled: boolean;
    sosLiveShareEnabled: boolean;
    decentroDigilockerEnabled: boolean;
    directMessagingEnabled?: boolean;
    manualVerificationFallbackEnabled?: boolean;
  };
  mediaUploadLimits: {
    maxPostImageMb: number;
    maxVideoUploadMb?: number;
    maxVideoDurationSeconds?: number;
    maxComplaintEvidenceMb: number;
    maxFilesPerComplaint: number;
    allowedFormats: string[];
    feedCategories?: string[];
    policyDocuments?: {
      termsVersion: string;
      privacyPolicyVersion: string;
      communityGuidelines: string;
      medicalLegalDisclaimer: string;
    };
    notificationTemplates?: {
      wellnessDiscreetDefault: string;
      complaintStatusUpdate: string;
      sosEmergencySms: string;
    };
    retentionPolicies?: {
      verificationRetentionDays: number;
      closedComplaintRetentionDays: number;
      messagesRetentionDays: number;
      deletedAccountPurgeDays: number;
    };
  };
  businessCategories: string[];
  announcementBanner: string;
  updatedBy: string;
  updatedAt: string;
}

interface StaffListPayload {
  roleDefinitions: Record<SakhiAdminRole, AdminRoleDefinition>;
  staff: AdminStaffRecord[];
  authorisedComplaintReviewers: Array<{
    id: string;
    staffCode: string;
    name: string;
    role: SakhiAdminRole;
    clearance: string;
    email: string;
  }>;
}

const ROLE_OPTIONS: Array<{ value: SakhiAdminRole; label: string }> = [
  {
    value: "COMPLAINT_REVIEWER",
    label: "Role 3 — Authorised Complaint Reviewer (Case Officer)",
  },
  {
    value: "VERIFICATION_ADMIN",
    label: "Role 1 — Verification & User Support Admin",
  },
  {
    value: "CONTENT_MODERATOR",
    label: "Role 2 — Community, Content & Wellness Moderator",
  },
  {
    value: "SOS_SAFETY_ADMIN",
    label: "Role 4 — SOS & Emergency Safety Admin",
  },
  {
    value: "BUSINESS_ADMIN",
    label: "Role 5 — Business & Marketplace Admin",
  },
  {
    value: "SUPER_ADMIN",
    label: "Super Admin — Master Governance",
  },
];

function formatClearance(raw: string): string {
  return raw
    .replace(/_/g, " ")
    .toLowerCase()
    .replace(/\b\w/g, (c) => c.toUpperCase());
}

export function AdminRolesAndConfigPage() {
  const [activeTab, setActiveTab] = useState<"staff" | "matrix" | "config">(
    "staff",
  );
  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");

  const [staffData, setStaffData] = useState<StaffListPayload | null>(null);
  const [platformConfig, setPlatformConfig] =
    useState<PlatformConfigRecord | null>(null);

  // Create Staff Form State
  const [fullName, setFullName] = useState("");
  const [email, setEmail] = useState("");
  const [selectedRole, setSelectedRole] =
    useState<SakhiAdminRole>("COMPLAINT_REVIEWER");
  const [customToken, setCustomToken] = useState("");
  const [isComplaintReviewer, setIsComplaintReviewer] = useState(true);
  const [newlyIssuedToken, setNewlyIssuedToken] = useState<{
    staffName: string;
    staffCode: string;
    roleTitle: string;
    token: string;
  } | null>(null);

  // Platform Config Editor State
  const [announcementBanner, setAnnouncementBanner] = useState("");
  const [maxPostMb, setMaxPostMb] = useState(10);
  const [maxVideoMb, setMaxVideoMb] = useState(50);
  const [maxVideoDurationSec, setMaxVideoDurationSec] = useState(120);
  const [maxEvidenceMb, setMaxEvidenceMb] = useState(15);
  const [maxFilesCount, setMaxFilesCount] = useState(5);
  const [feedCategoriesInput, setFeedCategoriesInput] = useState("Following, Community, Trending, Business Updates, Safety Awareness, Wellness and Lifestyle");
  const [businessCategoriesInput, setBusinessCategoriesInput] = useState("Fashion, Beauty, Food, Health, Education, Home services, Consulting, Art, Retail, Events, Freelancers, Other");
  const [termsVersion, setTermsVersion] = useState("v2.4 (DPDP Act 2023 & IT Rules Compliant)");
  const [privacyPolicyVersion, setPrivacyPolicyVersion] = useState("v2.4 (Zero Raw Aadhaar/OTP & Encrypted Health Data)");
  const [wellnessDiscreetTemplate, setWellnessDiscreetTemplate] = useState("Sakhi Daily Mindfulness: Your personal calendar reminder is ready.");
  const [verificationRetentionDays, setVerificationRetentionDays] = useState(30);
  const [closedComplaintRetentionDays, setClosedComplaintRetentionDays] = useState(90);
  const [messagesRetentionDays, setMessagesRetentionDays] = useState(180);
  const [deletedAccountPurgeDays, setDeletedAccountPurgeDays] = useState(30);

  const loadData = useCallback(async () => {
    // Keep state writes after the network await so the initial effect does not
    // synchronously cascade a render. Refresh controls manage their own spinner.
    try {
      const [staffRes, cfgRes] = await Promise.all([
        adminApi<StaffListPayload>("/admin-review/staff"),
        adminApi<{ config: PlatformConfigRecord }>(
          "/admin-review/platform-config",
        ),
      ]);
      setStaffData(staffRes);
      setPlatformConfig(cfgRes.config);
      setAnnouncementBanner(cfgRes.config.announcementBanner || "");
      setMaxPostMb(cfgRes.config.mediaUploadLimits.maxPostImageMb || 10);
      setMaxVideoMb(cfgRes.config.mediaUploadLimits.maxVideoUploadMb || 50);
      setMaxVideoDurationSec(cfgRes.config.mediaUploadLimits.maxVideoDurationSeconds || 120);
      setMaxEvidenceMb(
        cfgRes.config.mediaUploadLimits.maxComplaintEvidenceMb || 15,
      );
      setMaxFilesCount(
        cfgRes.config.mediaUploadLimits.maxFilesPerComplaint || 5,
      );
      if (Array.isArray(cfgRes.config.mediaUploadLimits.feedCategories)) {
        setFeedCategoriesInput(cfgRes.config.mediaUploadLimits.feedCategories.join(", "));
      }
      if (Array.isArray(cfgRes.config.businessCategories)) {
        setBusinessCategoriesInput(cfgRes.config.businessCategories.join(", "));
      }
      if (cfgRes.config.mediaUploadLimits.policyDocuments) {
        setTermsVersion(cfgRes.config.mediaUploadLimits.policyDocuments.termsVersion || "v2.4");
        setPrivacyPolicyVersion(cfgRes.config.mediaUploadLimits.policyDocuments.privacyPolicyVersion || "v2.4");
      }
      if (cfgRes.config.mediaUploadLimits.notificationTemplates) {
        setWellnessDiscreetTemplate(cfgRes.config.mediaUploadLimits.notificationTemplates.wellnessDiscreetDefault || "");
      }
      if (cfgRes.config.mediaUploadLimits.retentionPolicies) {
        setVerificationRetentionDays(cfgRes.config.mediaUploadLimits.retentionPolicies.verificationRetentionDays || 30);
        setClosedComplaintRetentionDays(cfgRes.config.mediaUploadLimits.retentionPolicies.closedComplaintRetentionDays || 90);
        setMessagesRetentionDays(cfgRes.config.mediaUploadLimits.retentionPolicies.messagesRetentionDays || 180);
        setDeletedAccountPurgeDays(cfgRes.config.mediaUploadLimits.retentionPolicies.deletedAccountPurgeDays || 30);
      }
    } catch (err) {
      setError(
        err instanceof Error
          ? err.message
          : "Could not load Admin Staff & RBAC Governance records.",
      );
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    // Defer the async request until after this effect has committed.
    void Promise.resolve().then(() => loadData());
  }, [loadData]);

  async function handleCreateStaff() {
    if (fullName.trim().length < 3) {
      setError("Enter the admin's full name (at least 3 characters).");
      return;
    }
    if (!email.trim().includes("@")) {
      setError("Enter a valid official email address.");
      return;
    }
    setSubmitting(true);
    setError("");
    setNotice("");
    try {
      const res = await adminApi<{
        staff: AdminStaffRecord;
        issuedAccessToken: string;
      }>("/admin-review/staff", {
        method: "POST",
        body: {
          fullName: fullName.trim(),
          email: email.trim(),
          role: selectedRole,
          customAccessToken: customToken.trim() || undefined,
          isAuthorisedComplaintReviewer:
            selectedRole === "COMPLAINT_REVIEWER" ||
            selectedRole === "SUPER_ADMIN" ||
            isComplaintReviewer,
        },
      });
      setNewlyIssuedToken({
        staffName: res.staff.fullName,
        staffCode: res.staff.staffCode,
        roleTitle:
          staffData?.roleDefinitions?.[res.staff.role]?.title ??
          res.staff.role.replace(/_/g, " "),
        token: res.issuedAccessToken,
      });
      setFullName("");
      setEmail("");
      setCustomToken("");
      setNotice(
        `Created real admin account ${res.staff.fullName} (${res.staff.staffCode}). Copy their login token below!`,
      );
      await loadData();
    } catch (err) {
      setError(
        err instanceof Error ? err.message : "Failed to create admin account.",
      );
    } finally {
      setSubmitting(false);
    }
  }

  async function handleToggleStatus(staff: AdminStaffRecord) {
    const nextStatus = staff.status === "ACTIVE" ? "SUSPENDED" : "ACTIVE";
    setSubmitting(true);
    setError("");
    setNotice("");
    try {
      await adminApi(`/admin-review/staff/${encodeURIComponent(staff.id)}`, {
        method: "PATCH",
        body: { status: nextStatus },
      });
      setNotice(
        `Updated ${staff.fullName} (${staff.staffCode}) status to ${nextStatus}.`,
      );
      await loadData();
    } catch (err) {
      setError(
        err instanceof Error ? err.message : "Failed to update admin status.",
      );
    } finally {
      setSubmitting(false);
    }
  }

  async function handleToggleStaffPermission(
    staff: AdminStaffRecord,
    permKey: keyof GranularRolePermissions,
  ) {
    setSubmitting(true);
    setError("");
    setNotice("");
    try {
      const nextPerms = {
        ...staff.permissions,
        [permKey]: !staff.permissions[permKey],
      };
      await adminApi(`/admin-review/staff/${encodeURIComponent(staff.id)}`, {
        method: "PATCH",
        body: { permissions: nextPerms },
      });
      setNotice(
        `Updated granular "${permKey.toUpperCase()}" permission for ${staff.fullName} (${staff.staffCode}).`,
      );
      await loadData();
    } catch (err) {
      setError(
        err instanceof Error ? err.message : "Failed to update staff permission.",
      );
    } finally {
      setSubmitting(false);
    }
  }

  async function handleToggleComplaintClearance(staff: AdminStaffRecord) {
    setSubmitting(true);
    setError("");
    setNotice("");
    try {
      await adminApi(`/admin-review/staff/${encodeURIComponent(staff.id)}`, {
        method: "PATCH",
        body: {
          isAuthorisedComplaintReviewer: !staff.isAuthorisedComplaintReviewer,
        },
      });
      setNotice(
        `${!staff.isAuthorisedComplaintReviewer ? "Granted" : "Revoked"} Authorised Complaint Reviewer clearance for ${staff.fullName} (${staff.staffCode}).`,
      );
      await loadData();
    } catch (err) {
      setError(
        err instanceof Error
          ? err.message
          : "Failed to update reviewer clearance.",
      );
    } finally {
      setSubmitting(false);
    }
  }

  async function handleRegenerateToken(staff: AdminStaffRecord) {
    setSubmitting(true);
    setError("");
    setNotice("");
    try {
      const res = await adminApi<{
        staff: AdminStaffRecord;
        issuedAccessToken?: string;
      }>(`/admin-review/staff/${encodeURIComponent(staff.id)}`, {
        method: "PATCH",
        body: { regenerateToken: true },
      });
      if (res.issuedAccessToken) {
        setNewlyIssuedToken({
          staffName: res.staff.fullName,
          staffCode: res.staff.staffCode,
          roleTitle:
            staffData?.roleDefinitions?.[res.staff.role]?.title ??
            res.staff.role.replace(/_/g, " "),
          token: res.issuedAccessToken,
        });
      }
      setNotice(
        `Re-issued login token for ${staff.fullName} (${staff.staffCode}).`,
      );
      await loadData();
    } catch (err) {
      setError(
        err instanceof Error ? err.message : "Failed to regenerate token.",
      );
    } finally {
      setSubmitting(false);
    }
  }

  async function handleDeleteStaff(staff: AdminStaffRecord) {
    setSubmitting(true);
    setError("");
    setNotice("");
    try {
      await adminApi(`/admin-review/staff/${encodeURIComponent(staff.id)}`, {
        method: "DELETE",
      });
      setNotice(
        `Removed admin account ${staff.fullName} (${staff.staffCode}) from database.`,
      );
      await loadData();
    } catch (err) {
      setError(
        err instanceof Error ? err.message : "Failed to delete admin account.",
      );
    } finally {
      setSubmitting(false);
    }
  }

  async function handleToggleFeatureFlag(
    flagKey: keyof PlatformConfigRecord["featureFlags"],
  ) {
    if (!platformConfig) return;
    setSubmitting(true);
    setError("");
    setNotice("");
    try {
      const nextFlags = {
        ...platformConfig.featureFlags,
        [flagKey]: !platformConfig.featureFlags[flagKey],
      };
      const res = await adminApi<{ config: PlatformConfigRecord }>(
        "/admin-review/platform-config",
        {
          method: "PUT",
          body: { featureFlags: nextFlags },
        },
      );
      setPlatformConfig(res.config);
      setNotice("Updated global platform feature flags in PostgreSQL.");
    } catch (err) {
      setError(
        err instanceof Error ? err.message : "Failed to update feature flags.",
      );
    } finally {
      setSubmitting(false);
    }
  }

  async function handleSavePlatformSettings() {
    if (!platformConfig) return;
    setSubmitting(true);
    setError("");
    setNotice("");
    try {
      const res = await adminApi<{ config: PlatformConfigRecord }>(
        "/admin-review/platform-config",
        {
          method: "PUT",
          body: {
            announcementBanner: announcementBanner.trim(),
            businessCategories: businessCategoriesInput
              .split(",")
              .map((c) => c.trim())
              .filter(Boolean),
            mediaUploadLimits: {
              ...platformConfig.mediaUploadLimits,
              maxPostImageMb: maxPostMb,
              maxVideoUploadMb: maxVideoMb,
              maxVideoDurationSeconds: maxVideoDurationSec,
              maxComplaintEvidenceMb: maxEvidenceMb,
              maxFilesPerComplaint: maxFilesCount,
              feedCategories: feedCategoriesInput
                .split(",")
                .map((c) => c.trim())
                .filter(Boolean),
              policyDocuments: {
                termsVersion: termsVersion.trim(),
                privacyPolicyVersion: privacyPolicyVersion.trim(),
                communityGuidelines:
                  platformConfig.mediaUploadLimits.policyDocuments?.communityGuidelines ??
                  "Zero tolerance for harassment, doxxing, hate speech, or non-consensual media.",
                medicalLegalDisclaimer:
                  platformConfig.mediaUploadLimits.policyDocuments?.medicalLegalDisclaimer ??
                  "In-app wellness content is non-diagnostic; in-app complaints do not replace a Police FIR or 112 call.",
              },
              notificationTemplates: {
                wellnessDiscreetDefault: wellnessDiscreetTemplate.trim(),
                complaintStatusUpdate:
                  platformConfig.mediaUploadLimits.notificationTemplates?.complaintStatusUpdate ??
                  "Sakhi Personal Note: You have a new update in your private vault.",
                sosEmergencySms:
                  platformConfig.mediaUploadLimits.notificationTemplates?.sosEmergencySms ??
                  "URGENT SAKHI SOS: {memberName} needs emergency assistance. Live location: {trackingUrl} | Dial 112.",
              },
              retentionPolicies: {
                verificationRetentionDays,
                closedComplaintRetentionDays,
                messagesRetentionDays,
                deletedAccountPurgeDays,
              },
            },
          },
        },
      );
      setPlatformConfig(res.config);
      setNotice(
        "Saved global media upload limits and platform announcement banner.",
      );
    } catch (err) {
      setError(
        err instanceof Error
          ? err.message
          : "Failed to save platform configuration.",
      );
    } finally {
      setSubmitting(false);
    }
  }

  if (loading && !staffData) {
    return (
      <SakhiQuoteLoader statusLabel="Loading Admin Users, 5 Normal Admin Roles & RBAC Governance..." />
    );
  }

  const staffList = staffData?.staff ?? [];
  const roleDefs = staffData?.roleDefinitions
    ? Object.values(staffData.roleDefinitions)
    : [];
  const authorisedReviewers = staffData?.authorisedComplaintReviewers ?? [];

  return (
    <div
      className="page-stack"
      style={{ display: "flex", flexDirection: "column", gap: "24px" }}
    >
      {/* Hero Header */}
      <section className="hero-card">
        <div className="hero-copy">
          <div className="eyebrow-row">
            <StatusPill tone="rose">
              SUPER ADMIN GOVERNANCE • SRS SECTIONS 12.1–12.10 &amp; 13
            </StatusPill>
            <StatusPill tone="green">
              PostgreSQL RBAC Staff Accounts Active
            </StatusPill>
          </div>
          <h1>Admin Users, 5 Role Panels &amp; Platform Governance</h1>
          <p>
            Create and manage real administrator accounts across the 5
            specialized Normal Admin roles, designate real Authorised Complaint
            Reviewers for Discreet Complaints, and configure global platform
            feature flags.
          </p>
        </div>
        <div className="hero-actions">
          <button
            className="secondary-button"
            type="button"
            disabled={loading || submitting}
            onClick={() => {
              setLoading(true);
              setError("");
              void loadData();
            }}
          >
            <RefreshCw size={15} /> {loading ? "Syncing..." : "Refresh Staff"}
          </button>
        </div>
      </section>

      {notice && (
        <div
          className="demo-banner"
          style={{
            background: "#e8f5ed",
            borderColor: "#b8e2c8",
            color: "#1f6e4e",
          }}
        >
          <CheckCircle2 size={18} />
          <div>
            <strong>Database Action Confirmed</strong>
            <span>{notice}</span>
          </div>
        </div>
      )}
      {error && (
        <div
          className="demo-banner"
          style={{
            background: "#fcebed",
            borderColor: "#f5c2c7",
            color: "#a63b4a",
          }}
        >
          <AlertTriangle size={18} />
          <div>
            <strong>Validation / API Error</strong>
            <span>{error}</span>
          </div>
        </div>
      )}

      {/* Newly Issued Token Banner */}
      {newlyIssuedToken && (
        <div
          style={{
            background: "#2a1132",
            color: "#fff",
            borderRadius: "18px",
            padding: "20px 24px",
            border: "2px solid #c83e73",
          }}
        >
          <div
            style={{
              display: "flex",
              justifyContent: "space-between",
              alignItems: "center",
              flexWrap: "wrap",
              gap: "12px",
            }}
          >
            <div>
              <StatusPill tone="green">
                NEW ADMIN LOGIN TOKEN ISSUED
              </StatusPill>
              <h3 style={{ margin: "8px 0 4px 0", fontSize: "18px" }}>
                {newlyIssuedToken.staffName} ({newlyIssuedToken.staffCode}) —{" "}
                {newlyIssuedToken.roleTitle}
              </h3>
              <p
                style={{
                  margin: 0,
                  fontSize: "13px",
                  color: "#e6d2ed",
                }}
              >
                Copy this token and sign in on the Admin Login page to open this
                admin&apos;s role-restricted panel:
              </p>
            </div>
            <div style={{ display: "flex", gap: "10px", alignItems: "center" }}>
              <code
                style={{
                  background: "rgba(255,255,255,0.12)",
                  padding: "10px 14px",
                  borderRadius: "10px",
                  fontSize: "14px",
                  fontWeight: 800,
                  letterSpacing: "0.5px",
                }}
              >
                {newlyIssuedToken.token}
              </code>
              <button className="button button--secondary"
                type="button"
                onClick={() => {
                  void navigator.clipboard?.writeText(newlyIssuedToken.token);
                  setNotice(
                    `Copied login token for ${newlyIssuedToken.staffName}!`,
                  );
                }}
                style={{
                  padding: "10px 16px",
                  borderRadius: "999px",
                  border: 0,
                  background: "#c83e73",
                  color: "#fff",
                  fontWeight: 700,
                  cursor: "pointer",
                }}
              >
                <Copy size={14} style={{ verticalAlign: "middle" }} /> Copy Token
              </button>
            </div>
          </div>
        </div>
      )}

      {/* KPI Row */}
      <section
        className="stats-grid"
        style={{
          display: "grid",
          gridTemplateColumns: "repeat(auto-fit, minmax(220px, 1fr))",
          gap: "18px",
        }}
      >
        <article
          style={{
            background: "#fff",
            padding: "20px",
            borderRadius: "16px",
            border: "1px solid #eee7ee",
          }}
        >
          <span style={{ fontSize: "12px", color: "#877b8b", fontWeight: 700 }}>
            CREATED ADMIN STAFF ACCOUNTS
          </span>
          <div
            style={{
              fontSize: "28px",
              fontWeight: 800,
              color: "#31263a",
              marginTop: "8px",
            }}
          >
            {staffList.length}{" "}
            <StatusPill tone="green">
              {staffList.filter((s) => s.status === "ACTIVE").length} Active
            </StatusPill>
          </div>
        </article>
        <article
          style={{
            background: "#fff",
            padding: "20px",
            borderRadius: "16px",
            border: "1px solid #eee7ee",
          }}
        >
          <span style={{ fontSize: "12px", color: "#877b8b", fontWeight: 700 }}>
            AUTHORISED COMPLAINT REVIEWERS
          </span>
          <div
            style={{
              fontSize: "28px",
              fontWeight: 800,
              color: "#631d76",
              marginTop: "8px",
            }}
          >
            {authorisedReviewers.length}{" "}
            <StatusPill tone="rose">Real DB Officers</StatusPill>
          </div>
        </article>
        <article
          style={{
            background: "#fff",
            padding: "20px",
            borderRadius: "16px",
            border: "1px solid #eee7ee",
          }}
        >
          <span style={{ fontSize: "12px", color: "#877b8b", fontWeight: 700 }}>
            ROLE-BASED PANELS CONFIGURED
          </span>
          <div
            style={{
              fontSize: "28px",
              fontWeight: 800,
              color: "#39785c",
              marginTop: "8px",
            }}
          >
            1 Super + 5 Normal{" "}
            <StatusPill tone="green">Least Privilege</StatusPill>
          </div>
        </article>
      </section>

      {/* Navigation Tabs */}
      <div
        style={{
          display: "flex",
          gap: "12px",
          flexWrap: "wrap",
          borderBottom: "1px solid #eee7ee",
          paddingBottom: "14px",
        }}
      >
        {[
          {
            id: "staff",
            label: "1. Admin Staff Accounts & Authorised Reviewers",
            icon: UserPlus,
          },
          {
            id: "matrix",
            label: "2. 6-Role Permission Matrix & Privacy Boundaries",
            icon: Shield,
          },
          {
            id: "config",
            label: "3. Global Feature Flags & Media Upload Limits",
            icon: Settings2,
          },
        ].map((t) => {
          const Icon = t.icon;
          const active = activeTab === t.id;
          return (
            <button className="button button--secondary"
              key={t.id}
              type="button"
              onClick={() => setActiveTab(t.id as typeof activeTab)}
              style={{
                display: "inline-flex",
                alignItems: "center",
                gap: "8px",
                padding: "10px 18px",
                borderRadius: "999px",
                border: active ? "2px solid #631d76" : "1px solid #e5d8e8",
                background: active ? "#631d76" : "#fff",
                color: active ? "#fff" : "#52345f",
                fontWeight: 700,
                fontSize: "13px",
                cursor: "pointer",
              }}
            >
              <Icon size={15} />
              {t.label}
            </button>
          );
        })}
      </div>

      {/* TAB 1: CREATE & MANAGE REAL ADMIN STAFF */}
      {activeTab === "staff" && (
        <div
          style={{
            display: "grid",
            gridTemplateColumns: "1fr 1.35fr",
            gap: "22px",
            alignItems: "start",
          }}
        >
          {/* Left: Create Real Admin Staff Form */}
          <div
            style={{
              background: "#fff",
              borderRadius: "18px",
              border: "1px solid #eee7ee",
              padding: "22px",
            }}
          >
            <h3 style={{ margin: "0 0 6px 0", fontSize: "17px" }}>
              <UserPlus
                size={17}
                style={{ verticalAlign: "middle", marginRight: "6px" }}
              />
              Create Real Admin Staff Account
            </h3>
            <p
              style={{
                margin: "0 0 16px 0",
                fontSize: "13px",
                color: "#6e6275",
              }}
            >
              Created admins are persisted in PostgreSQL. When you assign Role 3
              (or check Authorised Complaint Reviewer), they immediately appear
              in the Discreet Complaints Reviewer dropdown.
            </p>

            <div
              style={{
                display: "flex",
                flexDirection: "column",
                gap: "12px",
              }}
            >
              <label style={{ fontSize: "12.5px", fontWeight: 700 }}>
                Admin Full Name *
                <input
                  value={fullName}
                  onChange={(e) => setFullName(e.target.value)}
                  placeholder="e.g., Priya Nair"
                  style={{
                    width: "100%",
                    marginTop: "4px",
                    padding: "10px 12px",
                    borderRadius: "10px",
                    border: "1px solid #dcd0e0",
                  }}
                />
              </label>

              <label style={{ fontSize: "12.5px", fontWeight: 700 }}>
                Official Email Address *
                <input
                  type="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder="e.g., priya.nair@sakhi.org.in"
                  style={{
                    width: "100%",
                    marginTop: "4px",
                    padding: "10px 12px",
                    borderRadius: "10px",
                    border: "1px solid #dcd0e0",
                  }}
                />
              </label>

              <label style={{ fontSize: "12.5px", fontWeight: 700 }}>
                Assigned Admin Role (Determines Allowed Panel Tabs) *
                <select
                  value={selectedRole}
                  onChange={(e) => {
                    const next = e.target.value as SakhiAdminRole;
                    setSelectedRole(next);
                    if (
                      next === "COMPLAINT_REVIEWER" ||
                      next === "SUPER_ADMIN"
                    ) {
                      setIsComplaintReviewer(true);
                    } else {
                      setIsComplaintReviewer(false);
                    }
                  }}
                  style={{
                    width: "100%",
                    marginTop: "4px",
                    padding: "10px 12px",
                    borderRadius: "10px",
                    border: "1px solid #dcd0e0",
                    fontWeight: 600,
                  }}
                >
                  {ROLE_OPTIONS.map((opt) => (
                    <option key={opt.value} value={opt.value}>
                      {opt.label}
                    </option>
                  ))}
                </select>
              </label>

              <label style={{ fontSize: "12.5px", fontWeight: 700 }}>
                Custom Access Token / Passcode (Optional — leave blank to
                auto-generate)
                <input
                  value={customToken}
                  onChange={(e) => setCustomToken(e.target.value)}
                  placeholder="Optional min 8 chars (e.g., SAKHI-PRIYA-2026)"
                  style={{
                    width: "100%",
                    marginTop: "4px",
                    padding: "10px 12px",
                    borderRadius: "10px",
                    border: "1px solid #dcd0e0",
                  }}
                />
              </label>

              <label
                style={{
                  display: "flex",
                  alignItems: "center",
                  gap: "8px",
                  fontSize: "13px",
                  fontWeight: 700,
                  padding: "10px 12px",
                  background: "#fdf7fb",
                  borderRadius: "10px",
                  border: "1px solid #ead8ee",
                }}
              >
                <input
                  type="checkbox"
                  checked={
                    selectedRole === "COMPLAINT_REVIEWER" ||
                    selectedRole === "SUPER_ADMIN" ||
                    isComplaintReviewer
                  }
                  disabled={
                    selectedRole === "COMPLAINT_REVIEWER" ||
                    selectedRole === "SUPER_ADMIN"
                  }
                  onChange={(e) => setIsComplaintReviewer(e.target.checked)}
                />
                <span>
                  Designate as Authorised Complaint Reviewer (appears in
                  Complaints assignment dropdown)
                </span>
              </label>

              <button className="button button--secondary"
                type="button"
                disabled={submitting}
                onClick={() => void handleCreateStaff()}
                style={{
                  padding: "12px 18px",
                  borderRadius: "999px",
                  border: 0,
                  background: "#631d76",
                  color: "#fff",
                  fontWeight: 700,
                  cursor: "pointer",
                  marginTop: "4px",
                }}
              >
                <Plus size={15} style={{ verticalAlign: "middle" }} />{" "}
                {submitting
                  ? "Creating Admin Account..."
                  : "Create Admin Account & Issue Token"}
              </button>
            </div>
          </div>

          {/* Right: Persisted Staff Directory */}
          <div
            style={{
              background: "#fff",
              borderRadius: "18px",
              border: "1px solid #eee7ee",
              padding: "22px",
            }}
          >
            <h3 style={{ margin: "0 0 12px 0", fontSize: "17px" }}>
              Active Admin Staff &amp; Authorised Reviewers ({staffList.length}{" "}
              Created Staff + Master Super Admin)
            </h3>

            {/* Master Super Admin Card */}
            <div
              style={{
                padding: "14px 16px",
                borderRadius: "14px",
                background: "#f8f1fb",
                border: "1px solid #dec8e8",
                marginBottom: "12px",
              }}
            >
              <div
                style={{
                  display: "flex",
                  justifyContent: "space-between",
                  alignItems: "center",
                  gap: "8px",
                }}
              >
                <div>
                  <strong>Sakhi Super Admin (#SA-01)</strong>
                  <div style={{ fontSize: "12px", color: "#6e6275" }}>
                    superadmin@sakhi.org.in • Master Governance &amp; Default
                    Escalation Lead
                  </div>
                </div>
                <div style={{ display: "flex", gap: "6px" }}>
                  <StatusPill tone="rose">Super Admin</StatusPill>
                  <StatusPill tone="green">Authorised Reviewer</StatusPill>
                </div>
              </div>
            </div>

            {staffList.length === 0 ? (
              <div
                style={{
                  padding: "28px 20px",
                  textAlign: "center",
                  background: "#fdf9fc",
                  borderRadius: "14px",
                  border: "1px dashed #dcc8e6",
                }}
              >
                <strong style={{ display: "block", color: "#52345f" }}>
                  No Additional Staff Accounts Created Yet
                </strong>
                <p
                  style={{
                    margin: "6px 0 0 0",
                    fontSize: "13px",
                    color: "#6e6275",
                  }}
                >
                  Zero fake administrators are pre-seeded. Use the form on the
                  left to create real Normal Admin accounts across the 5 roles!
                </p>
              </div>
            ) : (
              <div
                style={{
                  display: "flex",
                  flexDirection: "column",
                  gap: "12px",
                }}
              >
                {staffList.map((s) => (
                  <div
                    key={s.id}
                    style={{
                      padding: "16px",
                      borderRadius: "14px",
                      border: "1px solid #eee7ee",
                      background: s.status === "ACTIVE" ? "#fff" : "#f9f6fa",
                    }}
                  >
                    <div
                      style={{
                        display: "flex",
                        justifyContent: "space-between",
                        alignItems: "center",
                        flexWrap: "wrap",
                        gap: "8px",
                        marginBottom: "8px",
                      }}
                    >
                      <div>
                        <strong style={{ fontSize: "15px" }}>
                          {s.fullName} ({s.staffCode})
                        </strong>
                        <div style={{ fontSize: "12px", color: "#6e6275" }}>
                          {s.email} • Token: <code>{s.accessTokenPreview}</code>
                        </div>
                      </div>
                      <div
                        style={{ display: "flex", gap: "6px", flexWrap: "wrap" }}
                      >
                        <StatusPill tone="rose">
                          {s.role.replace(/_/g, " ")}
                        </StatusPill>
                        <StatusPill
                          tone={s.status === "ACTIVE" ? "green" : "urgent"}
                        >
                          {s.status}
                        </StatusPill>
                        {s.isAuthorisedComplaintReviewer && (
                          <StatusPill tone="green">
                            Complaint Reviewer ✓
                          </StatusPill>
                        )}
                      </div>
                    </div>

                    <div
                      style={{
                        fontSize: "12px",
                        color: "#6e6275",
                        marginBottom: "8px",
                      }}
                    >
                      Allowed Panel Routes:{" "}
                      <strong>{s.allowedRoutes.join(", ")}</strong> • Clearance:{" "}
                      <strong>{formatClearance(s.clearanceLevel)}</strong>
                    </div>
                    <div
                      style={{
                        display: "flex",
                        gap: "6px",
                        flexWrap: "wrap",
                        marginBottom: "10px",
                        alignItems: "center",
                      }}
                    >
                      <span style={{ fontSize: "11.5px", fontWeight: 700, color: "#52345f" }}>
                        Granular Permissions (Click to Toggle):
                      </span>
                      {(
                        [
                          "view",
                          "create",
                          "edit",
                          "approve",
                          "suspend",
                          "export",
                          "delete",
                        ] as const
                      ).map((permKey) => {
                        const activePerm = s.permissions[permKey];
                        return (
                          <button className="button button--secondary"
                            key={permKey}
                            type="button"
                            disabled={submitting}
                            onClick={() => void handleToggleStaffPermission(s, permKey)}
                            style={{
                              padding: "3px 9px",
                              borderRadius: "999px",
                              border: "1px solid #dcd0e0",
                              background: activePerm ? "#e8f5ed" : "#f5f2f7",
                              color: activePerm ? "#1f6e4e" : "#7b6f82",
                              fontSize: "11px",
                              fontWeight: 700,
                              cursor: "pointer",
                            }}
                          >
                            {permKey.toUpperCase()}: {activePerm ? "ON" : "OFF"}
                          </button>
                        );
                      })}
                    </div>

                    <div
                      style={{
                        display: "flex",
                        gap: "8px",
                        flexWrap: "wrap",
                      }}
                    >
                      <button
                        type="button"
                        className="secondary-button"
                        disabled={submitting}
                        onClick={() => void handleToggleComplaintClearance(s)}
                      >
                        <UserCheck size={14} />{" "}
                        {s.isAuthorisedComplaintReviewer
                          ? "Revoke Complaint Clearance"
                          : "Grant Complaint Clearance"}
                      </button>
                      <button
                        type="button"
                        className="secondary-button"
                        disabled={submitting}
                        onClick={() => void handleRegenerateToken(s)}
                      >
                        <KeyRound size={14} /> Re-Issue Login Token
                      </button>
                      <button
                        type="button"
                        className="secondary-button"
                        disabled={submitting}
                        onClick={() => void handleToggleStatus(s)}
                      >
                        {s.status === "ACTIVE" ? "Suspend" : "Activate"}
                      </button>
                      <button
                        type="button"
                        className="secondary-button"
                        disabled={submitting}
                        onClick={() => void handleDeleteStaff(s)}
                        style={{ color: "#b4233c" }}
                      >
                        <Trash2 size={14} /> Remove
                      </button>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>
      )}

      {/* TAB 2: 6-ROLE PERMISSION MATRIX */}
      {activeTab === "matrix" && (
        <div
          style={{
            display: "grid",
            gridTemplateColumns: "repeat(auto-fit, minmax(340px, 1fr))",
            gap: "18px",
          }}
        >
          {roleDefs.map((def) => (
            <div
              key={def.role}
              style={{
                background: "#fff",
                borderRadius: "18px",
                border: "1px solid #eee7ee",
                padding: "22px",
              }}
            >
              <div
                style={{
                  display: "flex",
                  justifyContent: "space-between",
                  alignItems: "center",
                  marginBottom: "10px",
                }}
              >
                <StatusPill
                  tone={def.role === "SUPER_ADMIN" ? "rose" : "green"}
                >
                  {def.badgeLabel}
                </StatusPill>
                <span style={{ fontSize: "11.5px", color: "#877b8b" }}>
                  {formatClearance(def.defaultClearanceLevel)}
                </span>
              </div>
              <h3 style={{ margin: "0 0 6px 0", fontSize: "17px" }}>
                {def.title}
              </h3>
              <p
                style={{
                  margin: "0 0 12px 0",
                  fontSize: "13px",
                  color: "#6e6275",
                  lineHeight: 1.45,
                }}
              >
                {def.description}
              </p>
              <div
                style={{
                  fontSize: "12px",
                  marginBottom: "10px",
                  padding: "10px",
                  background: "#fdf9fc",
                  borderRadius: "10px",
                }}
              >
                <strong>Allowed Panel Tabs:</strong>{" "}
                {def.allowedRoutes.join(", ")}
              </div>
              <div
                style={{
                  display: "flex",
                  gap: "6px",
                  flexWrap: "wrap",
                  marginBottom: "12px",
                }}
              >
                {Object.entries(def.defaultPermissions).map(([perm, allowed]) => (
                  <StatusPill
                    key={perm}
                    tone={allowed ? "green" : "neutral"}
                  >
                    {perm.toUpperCase()}: {allowed ? "YES" : "NO"}
                  </StatusPill>
                ))}
              </div>
              <div style={{ fontSize: "12px", color: "#7a2e4d" }}>
                <strong>
                  <Lock size={12} style={{ verticalAlign: "middle" }} /> Privacy
                  Hard-Blocks:
                </strong>
                <ul style={{ margin: "4px 0 0 18px", padding: 0 }}>
                  {def.privacyBoundaries.map((b) => (
                    <li key={b} style={{ marginBottom: "3px" }}>
                      {b}
                    </li>
                  ))}
                </ul>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* TAB 3: GLOBAL FEATURE FLAGS & UPLOAD LIMITS */}
      {activeTab === "config" && platformConfig && (
        <div
          style={{
            display: "grid",
            gridTemplateColumns: "1fr 1fr",
            gap: "22px",
            alignItems: "start",
          }}
        >
          <div
            style={{
              background: "#fff",
              borderRadius: "18px",
              border: "1px solid #eee7ee",
              padding: "22px",
            }}
          >
            <h3 style={{ margin: "0 0 12px 0", fontSize: "17px" }}>
              <ShieldCheck
                size={17}
                style={{ verticalAlign: "middle", marginRight: "6px" }}
              />
              Global Platform Feature Flags (SRS Section 12.10)
            </h3>
            <div
              style={{ display: "flex", flexDirection: "column", gap: "10px" }}
            >
              {(
                [
                  [
                    "communityFeedEnabled",
                    "Community Feed & Women's Circles (Module 3)",
                  ],
                  [
                    "anonymousComplaintsEnabled",
                    "Discreet & Anonymous Complaint Intake (Module 5)",
                  ],
                  [
                    "sosLiveShareEnabled",
                    "Emergency SOS & Live Location Sharing (Module 4)",
                  ],
                  [
                    "decentroDigilockerEnabled",
                    "Decentro DigiLocker Female Eligibility Verification (Module 1)",
                  ],
                  [
                    "businessDirectoryEnabled",
                    "Women-Owned Business Directory & Marketplace (Module 7)",
                  ],
                  [
                    "wellnessTrackerEnabled",
                    "Private Menstrual & Wellness Educational Hub (Module 6)",
                  ],
                  [
                    "directMessagingEnabled",
                    "Member-to-Member Direct Messaging & Circle Chat",
                  ],
                  [
                    "manualVerificationFallbackEnabled",
                    "Manual Eligibility Verification Fallback Queue",
                  ],
                ] as const
              ).map(([key, label]) => {
                const enabled = platformConfig.featureFlags[key];
                return (
                  <div
                    key={key}
                    style={{
                      display: "flex",
                      justifyContent: "space-between",
                      alignItems: "center",
                      padding: "12px 14px",
                      borderRadius: "12px",
                      border: "1px solid #eee7ee",
                    }}
                  >
                    <strong style={{ fontSize: "13.5px" }}>{label}</strong>
                    <button className="button button--secondary"
                      type="button"
                      disabled={submitting}
                      onClick={() => void handleToggleFeatureFlag(key)}
                      style={{
                        padding: "6px 14px",
                        borderRadius: "999px",
                        border: "1px solid #dcd0e0",
                        background: enabled ? "#e8f5ed" : "#fcebed",
                        color: enabled ? "#1f6e4e" : "#a63b4a",
                        fontWeight: 800,
                        fontSize: "12px",
                        cursor: "pointer",
                      }}
                    >
                      {enabled ? "ENABLED (Toggle)" : "DISABLED (Toggle)"}
                    </button>
                  </div>
                );
              })}
            </div>
          </div>

          <div
            style={{
              background: "#fff",
              borderRadius: "18px",
              border: "1px solid #eee7ee",
              padding: "22px",
            }}
          >
            <h3 style={{ margin: "0 0 12px 0", fontSize: "17px" }}>
              Media Upload Limits &amp; Global Announcement Banner
            </h3>
            <div
              style={{
                display: "flex",
                flexDirection: "column",
                gap: "12px",
                marginBottom: "16px",
              }}
            >
              <label style={{ fontSize: "13px", fontWeight: 700 }}>
                Max Community Post Image Size (MB)
                <input
                  type="number"
                  min={1}
                  max={50}
                  value={maxPostMb}
                  onChange={(e) => setMaxPostMb(Number(e.target.value))}
                  style={{
                    width: "100%",
                    marginTop: "4px",
                    padding: "10px 12px",
                    borderRadius: "10px",
                    border: "1px solid #dcd0e0",
                  }}
                />
              </label>
              <label style={{ fontSize: "13px", fontWeight: 700 }}>
                Max Complaint Evidence Attachment Size (MB)
                <input
                  type="number"
                  min={1}
                  max={50}
                  value={maxEvidenceMb}
                  onChange={(e) => setMaxEvidenceMb(Number(e.target.value))}
                  style={{
                    width: "100%",
                    marginTop: "4px",
                    padding: "10px 12px",
                    borderRadius: "10px",
                    border: "1px solid #dcd0e0",
                  }}
                />
              </label>
              <label style={{ fontSize: "13px", fontWeight: 700 }}>
                Max Evidence Files Per Complaint
                <input
                  type="number"
                  min={1}
                  max={10}
                  value={maxFilesCount}
                  onChange={(e) => setMaxFilesCount(Number(e.target.value))}
                  style={{
                    width: "100%",
                    marginTop: "4px",
                    padding: "10px 12px",
                    borderRadius: "10px",
                    border: "1px solid #dcd0e0",
                  }}
                />
              </label>
              <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "10px" }}>
                <label style={{ fontSize: "12.5px", fontWeight: 700 }}>
                  Max Video Upload Size (MB)
                  <input
                    type="number"
                    min={5}
                    max={250}
                    value={maxVideoMb}
                    onChange={(e) => setMaxVideoMb(Number(e.target.value))}
                    style={{
                      width: "100%",
                      marginTop: "4px",
                      padding: "9px 11px",
                      borderRadius: "10px",
                      border: "1px solid #dcd0e0",
                    }}
                  />
                </label>
                <label style={{ fontSize: "12.5px", fontWeight: 700 }}>
                  Max Video Duration (Seconds)
                  <input
                    type="number"
                    min={15}
                    max={600}
                    value={maxVideoDurationSec}
                    onChange={(e) => setMaxVideoDurationSec(Number(e.target.value))}
                    style={{
                      width: "100%",
                      marginTop: "4px",
                      padding: "9px 11px",
                      borderRadius: "10px",
                      border: "1px solid #dcd0e0",
                    }}
                  />
                </label>
              </div>
              <label style={{ fontSize: "12.5px", fontWeight: 700 }}>
                Social Wall Feed Categories (Comma-Separated — SRS 5.3)
                <input
                  value={feedCategoriesInput}
                  onChange={(e) => setFeedCategoriesInput(e.target.value)}
                  style={{
                    width: "100%",
                    marginTop: "4px",
                    padding: "9px 11px",
                    borderRadius: "10px",
                    border: "1px solid #dcd0e0",
                  }}
                />
              </label>
              <label style={{ fontSize: "12.5px", fontWeight: 700 }}>
                Business Marketplace Categories (Comma-Separated — SRS 8.3 &amp; 12.4)
                <input
                  value={businessCategoriesInput}
                  onChange={(e) => setBusinessCategoriesInput(e.target.value)}
                  style={{
                    width: "100%",
                    marginTop: "4px",
                    padding: "9px 11px",
                    borderRadius: "10px",
                    border: "1px solid #dcd0e0",
                  }}
                />
              </label>
              <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "10px" }}>
                <label style={{ fontSize: "12.5px", fontWeight: 700 }}>
                  Published Terms &amp; Conditions Version
                  <input
                    value={termsVersion}
                    onChange={(e) => setTermsVersion(e.target.value)}
                    style={{
                      width: "100%",
                      marginTop: "4px",
                      padding: "9px 11px",
                      borderRadius: "10px",
                      border: "1px solid #dcd0e0",
                    }}
                  />
                </label>
                <label style={{ fontSize: "12.5px", fontWeight: 700 }}>
                  Published Privacy Policy Version
                  <input
                    value={privacyPolicyVersion}
                    onChange={(e) => setPrivacyPolicyVersion(e.target.value)}
                    style={{
                      width: "100%",
                      marginTop: "4px",
                      padding: "9px 11px",
                      borderRadius: "10px",
                      border: "1px solid #dcd0e0",
                    }}
                  />
                </label>
              </div>
              <label style={{ fontSize: "12.5px", fontWeight: 700 }}>
                Discreet Default Menstrual / Wellness Notification Template (SRS 10.2)
                <input
                  value={wellnessDiscreetTemplate}
                  onChange={(e) => setWellnessDiscreetTemplate(e.target.value)}
                  style={{
                    width: "100%",
                    marginTop: "4px",
                    padding: "9px 11px",
                    borderRadius: "10px",
                    border: "1px solid #dcd0e0",
                  }}
                />
              </label>
              <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "10px" }}>
                <label style={{ fontSize: "12px", fontWeight: 700 }}>
                  Verification Records Purge (Days)
                  <input
                    type="number"
                    min={7}
                    max={365}
                    value={verificationRetentionDays}
                    onChange={(e) => setVerificationRetentionDays(Number(e.target.value))}
                    style={{
                      width: "100%",
                      marginTop: "4px",
                      padding: "8px 10px",
                      borderRadius: "10px",
                      border: "1px solid #dcd0e0",
                    }}
                  />
                </label>
                <label style={{ fontSize: "12px", fontWeight: 700 }}>
                  Closed Complaints Purge (Days)
                  <input
                    type="number"
                    min={30}
                    max={730}
                    value={closedComplaintRetentionDays}
                    onChange={(e) => setClosedComplaintRetentionDays(Number(e.target.value))}
                    style={{
                      width: "100%",
                      marginTop: "4px",
                      padding: "8px 10px",
                      borderRadius: "10px",
                      border: "1px solid #dcd0e0",
                    }}
                  />
                </label>
                <label style={{ fontSize: "12px", fontWeight: 700 }}>
                  In-App Messages Purge (Days)
                  <input
                    type="number"
                    min={30}
                    max={730}
                    value={messagesRetentionDays}
                    onChange={(e) => setMessagesRetentionDays(Number(e.target.value))}
                    style={{
                      width: "100%",
                      marginTop: "4px",
                      padding: "8px 10px",
                      borderRadius: "10px",
                      border: "1px solid #dcd0e0",
                    }}
                  />
                </label>
                <label style={{ fontSize: "12px", fontWeight: 700 }}>
                  Deleted Accounts Purge (Days)
                  <input
                    type="number"
                    min={7}
                    max={180}
                    value={deletedAccountPurgeDays}
                    onChange={(e) => setDeletedAccountPurgeDays(Number(e.target.value))}
                    style={{
                      width: "100%",
                      marginTop: "4px",
                      padding: "8px 10px",
                      borderRadius: "10px",
                      border: "1px solid #dcd0e0",
                    }}
                  />
                </label>
              </div>
              <label style={{ fontSize: "13px", fontWeight: 700 }}>
                Global In-App Safety Announcement Banner
                <textarea
                  rows={2}
                  value={announcementBanner}
                  onChange={(e) => setAnnouncementBanner(e.target.value)}
                  style={{
                    width: "100%",
                    marginTop: "4px",
                    padding: "10px 12px",
                    borderRadius: "10px",
                    border: "1px solid #dcd0e0",
                  }}
                />
              </label>
            </div>
            <button className="button button--secondary"
              type="button"
              disabled={submitting}
              onClick={() => void handleSavePlatformSettings()}
              style={{
                width: "100%",
                padding: "12px",
                borderRadius: "999px",
                border: 0,
                background: "#631d76",
                color: "#fff",
                fontWeight: 700,
                cursor: "pointer",
              }}
            >
              Save Global Platform Settings
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
