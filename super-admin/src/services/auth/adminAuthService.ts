const STAGING_TEST_ADMIN_MODE = import.meta.env.VITE_ADMIN_MODE === "staging-test";
const LOCAL_TOKEN_KEY = "sakhi-admin-review-token";
const LOCAL_PROFILE_KEY = "sakhi-admin-rbac-profile";
const API_BASE_URL = (
  import.meta.env.VITE_API_BASE_URL ?? "http://127.0.0.1:3001/api/v1"
).replace(/\/+$/, "");

export type SakhiAdminRole =
  | "SUPER_ADMIN"
  | "VERIFICATION_ADMIN"
  | "CONTENT_MODERATOR"
  | "COMPLAINT_REVIEWER"
  | "SOS_SAFETY_ADMIN"
  | "BUSINESS_ADMIN";

export interface GranularRolePermissions {
  view: boolean;
  create: boolean;
  edit: boolean;
  approve: boolean;
  suspend: boolean;
  export: boolean;
  delete: boolean;
}

export interface AdminRbacProfile {
  staffId: string;
  staffCode: string;
  reviewerLabel: string;
  fullName: string;
  email: string;
  role: SakhiAdminRole;
  roleTitle: string;
  badgeLabel: string;
  clearanceLevel: string;
  isAuthorisedComplaintReviewer: boolean;
  permissions: GranularRolePermissions;
  allowedRoutes: string[];
}

const DEFAULT_SUPER_ADMIN_PROFILE: AdminRbacProfile = {
  staffId: "SUPER-ADMIN-MASTER",
  staffCode: "#SA-01",
  reviewerLabel: "Sakhi Super Admin (#SA-01)",
  fullName: "Sakhi Super Admin",
  email: "superadmin@sakhi.org.in",
  role: "SUPER_ADMIN",
  roleTitle: "Super Admin (Master Governance)",
  badgeLabel: "Super Admin",
  clearanceLevel: "LEVEL_4_MASTER_GOVERNANCE",
  isAuthorisedComplaintReviewer: true,
  permissions: {
    view: true,
    create: true,
    edit: true,
    approve: true,
    suspend: true,
    export: true,
    delete: true,
  },
  allowedRoutes: [
    "/dashboard",
    "/action-center",
    "/members",
    "/verification",
    "/verifications",
    "/moderation",
    "/complaints",
    "/emergency",
    "/community",
    "/businesses",
    "/wellness",
    "/admin-users",
    "/audit-security",
    "/integrations",
    "/settings",
  ],
};

let stagingSessionToken: string | null = null;
let stagingSessionMode: "staging_full_admin" | "staging_test_access_only" | null = null;
let inMemoryProfile: AdminRbacProfile | null = null;

export const isStagingTestAdminMode = STAGING_TEST_ADMIN_MODE;

export interface AdminSession {
  authenticated: true;
  reviewerLabel: string;
  mode: "local_dev_test_only" | "staging_test_access_only" | "staging_full_admin";
  message?: string;
  sessionToken?: string;
  sessionExpiresAt?: string;
  staffId?: string;
  staffCode?: string;
  fullName?: string;
  email?: string;
  role?: SakhiAdminRole;
  roleTitle?: string;
  badgeLabel?: string;
  clearanceLevel?: string;
  isAuthorisedComplaintReviewer?: boolean;
  permissions?: GranularRolePermissions;
  allowedRoutes?: string[];
}

function extractProfileFromPayload(data: Partial<AdminSession>): AdminRbacProfile {
  if (data.role && data.allowedRoutes) {
    return {
      staffId: data.staffId ?? "SUPER-ADMIN-MASTER",
      staffCode: data.staffCode ?? "#SA-01",
      reviewerLabel: data.reviewerLabel ?? "Sakhi Admin",
      fullName: data.fullName ?? data.reviewerLabel ?? "Sakhi Admin",
      email: data.email ?? "admin@sakhi.org.in",
      role: data.role,
      roleTitle: data.roleTitle ?? data.role.replace(/_/g, " "),
      badgeLabel: data.badgeLabel ?? data.role.replace(/_/g, " "),
      clearanceLevel: data.clearanceLevel ?? "LEVEL_2_TRUST_SAFETY",
      isAuthorisedComplaintReviewer: Boolean(
        data.isAuthorisedComplaintReviewer ??
          (data.role === "SUPER_ADMIN" || data.role === "COMPLAINT_REVIEWER"),
      ),
      permissions: data.permissions ?? DEFAULT_SUPER_ADMIN_PROFILE.permissions,
      allowedRoutes: data.allowedRoutes,
    };
  }
  return {
    ...DEFAULT_SUPER_ADMIN_PROFILE,
    reviewerLabel: data.reviewerLabel ?? DEFAULT_SUPER_ADMIN_PROFILE.reviewerLabel,
    fullName: data.reviewerLabel ?? DEFAULT_SUPER_ADMIN_PROFILE.fullName,
  };
}

async function fetchLocalRbacProfile(token: string): Promise<AdminRbacProfile> {
  try {
    const res = await fetch(`${API_BASE_URL}/admin-review/rbac-profile`, {
      method: "GET",
      headers: {
        Accept: "application/json",
        "X-Sakhi-Admin-Token": token,
      },
      credentials: "omit",
      cache: "no-store",
    });
    if (res.ok) {
      const payload = (await res.json()) as Partial<AdminSession>;
      return extractProfileFromPayload(payload);
    }
  } catch {
    // Fallback to default Super Admin profile if rbac-profile endpoint is not reachable
  }
  return DEFAULT_SUPER_ADMIN_PROFILE;
}

async function requestSession(token?: string): Promise<AdminSession> {
  const staging = STAGING_TEST_ADMIN_MODE;
  if (!staging && !token) {
    throw new Error("No saved local reviewer session is available.");
  }

  const url = staging
    ? `${API_BASE_URL}/staging-test-admin/session`
    : `${API_BASE_URL}/admin-review/session`;
  const headers: Record<string, string> = { Accept: "application/json" };
  let body: string | undefined;
  if (staging) {
    headers["Content-Type"] = "application/json";
    body = JSON.stringify({ token });
  } else {
    headers["X-Sakhi-Admin-Token"] = token as string;
  }

  const response = await fetch(url, {
    method: staging ? "POST" : "GET",
    headers,
    body,
    credentials: "omit",
    cache: "no-store",
  });
  const data = (await response.json().catch(() => ({}))) as Partial<AdminSession> & {
    message?: string | string[];
  };
  if (!response.ok) {
    const message = Array.isArray(data.message) ? data.message.join(" ") : data.message;
    throw new Error(message || "Reviewer token was not accepted by the backend.");
  }

  if (staging) {
    if (!data.sessionToken) {
      throw new Error("The backend did not issue a staging admin session.");
    }
    stagingSessionToken = data.sessionToken;
    stagingSessionMode =
      data.mode === "staging_full_admin" ? "staging_full_admin" : "staging_test_access_only";
    inMemoryProfile = extractProfileFromPayload(data);
  } else if (token) {
    const profile = await fetchLocalRbacProfile(token);
    inMemoryProfile = profile;
    sessionStorage.setItem(LOCAL_PROFILE_KEY, JSON.stringify(profile));
    return {
      ...(data as AdminSession),
      ...profile,
    };
  }
  return data as AdminSession;
}

export const adminAuthService = {
  isFullStagingAdminSession(): boolean {
    return STAGING_TEST_ADMIN_MODE && stagingSessionMode === "staging_full_admin";
  },
  hasActiveSession(): boolean {
    return STAGING_TEST_ADMIN_MODE
      ? Boolean(stagingSessionToken)
      : Boolean(sessionStorage.getItem(LOCAL_TOKEN_KEY));
  },
  getToken(): string | null {
    return STAGING_TEST_ADMIN_MODE
      ? stagingSessionToken
      : sessionStorage.getItem(LOCAL_TOKEN_KEY);
  },
  getProfile(): AdminRbacProfile {
    if (inMemoryProfile) return inMemoryProfile;
    if (!STAGING_TEST_ADMIN_MODE) {
      const raw = sessionStorage.getItem(LOCAL_PROFILE_KEY);
      if (raw) {
        try {
          const parsed = JSON.parse(raw) as AdminRbacProfile;
          if (parsed && parsed.role) {
            inMemoryProfile = parsed;
            return parsed;
          }
        } catch {
          // Ignore malformed storage
        }
      }
    }
    return DEFAULT_SUPER_ADMIN_PROFILE;
  },
  canAccessRoute(path: string): boolean {
    if (STAGING_TEST_ADMIN_MODE && !this.isFullStagingAdminSession()) {
      return path === "/test-access";
    }
    const profile = this.getProfile();
    if (profile.role === "SUPER_ADMIN") return true;
    const normalized = path === "/verifications" ? "/verification" : path;
    return (
      profile.allowedRoutes.includes(path) ||
      profile.allowedRoutes.includes(normalized)
    );
  },
  getDefaultLandingRoute(): string {
    if (STAGING_TEST_ADMIN_MODE && !this.isFullStagingAdminSession()) {
      return "/test-access";
    }
    const profile = this.getProfile();
    if (profile.role === "COMPLAINT_REVIEWER") return "/complaints";
    if (profile.role === "VERIFICATION_ADMIN") return "/verification";
    if (profile.role === "CONTENT_MODERATOR") return "/moderation";
    if (profile.role === "SOS_SAFETY_ADMIN") return "/emergency";
    if (profile.role === "BUSINESS_ADMIN") return "/businesses";
    return "/dashboard";
  },
  async validateToken(token: string): Promise<AdminSession> {
    if (!token) throw new Error("Enter the reviewer token.");
    return requestSession(token);
  },
  async validateExistingSession(): Promise<AdminSession> {
    if (STAGING_TEST_ADMIN_MODE) {
      if (!stagingSessionToken) {
        throw new Error("No in-memory staging reviewer session is available. Sign in again.");
      }
      const response = await fetch(`${API_BASE_URL}/staging-test-admin/session`, {
        method: "GET",
        headers: {
          Accept: "application/json",
          "X-Sakhi-Staging-Admin-Session": stagingSessionToken,
        },
        credentials: "omit",
        cache: "no-store",
      });
      const data = (await response.json().catch(() => ({}))) as Partial<AdminSession> & {
        message?: string | string[];
      };
      if (!response.ok) {
        const message = Array.isArray(data.message) ? data.message.join(" ") : data.message;
        throw new Error(message || "The staging reviewer session is no longer valid.");
      }
      stagingSessionMode =
        data.mode === "staging_full_admin" ? "staging_full_admin" : "staging_test_access_only";
      inMemoryProfile = extractProfileFromPayload(data);
      return data as AdminSession;
    }

    const token = sessionStorage.getItem(LOCAL_TOKEN_KEY);
    if (!token) throw new Error("No saved local reviewer session is available.");
    const response = await fetch(`${API_BASE_URL}/admin-review/session`, {
      method: "GET",
      headers: { "X-Sakhi-Admin-Token": token, Accept: "application/json" },
      credentials: "omit",
      cache: "no-store",
    });
    const data = (await response.json().catch(() => ({}))) as Partial<AdminSession> & {
      message?: string | string[];
    };
    if (!response.ok) {
      const message = Array.isArray(data.message) ? data.message.join(" ") : data.message;
      throw new Error(message || "The saved local reviewer session is no longer valid.");
    }
    const profile = await fetchLocalRbacProfile(token);
    inMemoryProfile = profile;
    sessionStorage.setItem(LOCAL_PROFILE_KEY, JSON.stringify(profile));
    return {
      ...(data as AdminSession),
      ...profile,
    };
  },
  async authenticate(token: string): Promise<AdminSession> {
    const session = await requestSession(token);
    if (!STAGING_TEST_ADMIN_MODE) {
      sessionStorage.setItem(LOCAL_TOKEN_KEY, token);
    }
    return session;
  },
  signOut(): void {
    inMemoryProfile = null;
    if (STAGING_TEST_ADMIN_MODE) {
      stagingSessionToken = null;
      stagingSessionMode = null;
    } else {
      sessionStorage.removeItem(LOCAL_TOKEN_KEY);
      sessionStorage.removeItem(LOCAL_PROFILE_KEY);
    }
  },
};
