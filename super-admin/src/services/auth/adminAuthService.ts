const STAGING_TEST_ADMIN_MODE = true;

const API_BASE_URL = (
  import.meta.env.VITE_API_BASE_URL ??
  "https://sakhi-staging-api.onrender.com/api/v1"
).replace(/\/+$/, "");

export type SakhiAdminRole =
  | "SUPER_ADMIN"
  | "VERIFICATION_ADMIN"
  | "CONTENT_MODERATOR"
  | "COMPLAINT_REVIEWER"
  | "SOS_SAFETY_ADMIN"
  | "BUSINESS_ADMIN"
  | "READ_ONLY_AUDITOR";

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

const LOCKED_ADMIN_PROFILE: AdminRbacProfile = {
  staffId: "",
  staffCode: "",
  reviewerLabel: "Unauthenticated",
  fullName: "Unauthenticated",
  email: "",
  role: "COMPLAINT_REVIEWER",
  roleTitle: "No active staff session",
  badgeLabel: "Unauthenticated",
  clearanceLevel: "NONE",
  isAuthorisedComplaintReviewer: false,
  permissions: {
    view: false,
    create: false,
    edit: false,
    approve: false,
    suspend: false,
    export: false,
    delete: false,
  },
  allowedRoutes: [],
};

let stagingSessionToken: string | null = null;
let stagingCookieSessionActive = false;
let stagingCsrfToken: string | null = null;
let stagingSessionMode: "staging_full_admin" | null = null;
let stagingLastRotationAt = 0;
let stagingRotationPromise: Promise<void> | null = null;
let inMemoryProfile: AdminRbacProfile | null = null;

export const isStagingTestAdminMode = STAGING_TEST_ADMIN_MODE;

export interface AdminSession {
  authenticated: true;
  reviewerLabel: string;
  mode: "local_dev_test_only" | "staging_full_admin";
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
  csrfToken?: string;
  mustResetPassword?: boolean;
}

export interface AdminMfaChallenge {
  authenticated: false;
  mfaRequired?: true;
  mfaEnrollmentRequired?: true;
  bootstrapRequired?: true;
  staffId?: string;
  staffCode?: string;
  message?: string;
}

export type AdminAuthResult = AdminSession | AdminMfaChallenge;

function extractProfileFromPayload(
  data: Partial<AdminSession>,
): AdminRbacProfile {
  const allowedRoles: SakhiAdminRole[] = [
    "SUPER_ADMIN",
    "VERIFICATION_ADMIN",
    "CONTENT_MODERATOR",
    "COMPLAINT_REVIEWER",
    "SOS_SAFETY_ADMIN",
    "BUSINESS_ADMIN",
    "READ_ONLY_AUDITOR",
  ];
  if (
    !data.staffId ||
    !data.staffCode ||
    !data.role ||
    !allowedRoles.includes(data.role) ||
    !data.permissions ||
    !Array.isArray(data.allowedRoutes) ||
    typeof data.fullName !== "string" ||
    typeof data.email !== "string"
  ) {
    throw new Error(
      "The backend did not return a complete authenticated staff profile. Access remains blocked.",
    );
  }
  return {
    staffId: data.staffId,
    staffCode: data.staffCode,
    reviewerLabel: data.reviewerLabel ?? data.fullName,
    fullName: data.fullName,
    email: data.email,
    role: data.role,
    roleTitle: data.roleTitle ?? data.role.replace(/_/g, " "),
    badgeLabel: data.badgeLabel ?? data.role.replace(/_/g, " "),
    clearanceLevel: data.clearanceLevel ?? "NONE",
    isAuthorisedComplaintReviewer: Boolean(data.isAuthorisedComplaintReviewer),
    permissions: data.permissions,
    allowedRoutes: data.allowedRoutes,
  };
}

async function requestSession(
  token?: string,
  mfaCode?: string,
): Promise<AdminAuthResult> {
  if (!token?.trim())
    throw new Error("Enter your individual staff credential.");
  const response = await fetch(API_BASE_URL + "/staging-test-admin/session", {
    method: "POST",
    headers: {
      Accept: "application/json",
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      token,
      ...(mfaCode ? { mfaCode } : {}),
    }),
    credentials: "include",
    cache: "no-store",
  });
  const data = (await response
    .json()
    .catch(() => ({}))) as Partial<AdminSession> &
    Partial<AdminMfaChallenge> & { message?: string | string[] };
  if (!response.ok) {
    const message = Array.isArray(data.message)
      ? data.message.join(" ")
      : data.message;
    throw new Error(message || "Individual staff authentication was rejected.");
  }
  if (data.authenticated === false) return data as AdminMfaChallenge;
  if (data.mode !== "staging_full_admin" || !data.csrfToken) {
    throw new Error(
      "Privileged access requires an individual persistent MFA-verified staff session.",
    );
  }
  stagingSessionMode = "staging_full_admin";
  stagingSessionToken = null;
  stagingCookieSessionActive = true;
  stagingCsrfToken = data.csrfToken;
  stagingLastRotationAt = Date.now();
  inMemoryProfile = extractProfileFromPayload(data);
  return data as AdminSession;
}

export const adminAuthService = {
  isFullStagingAdminSession(): boolean {
    return (
      STAGING_TEST_ADMIN_MODE && stagingSessionMode === "staging_full_admin"
    );
  },
  hasActiveSession(): boolean {
    return Boolean(stagingCookieSessionActive);
  },
  getToken(): string | null {
    return stagingSessionToken;
  },
  getCsrfToken(): string | null {
    return stagingCsrfToken;
  },
  async rotateSessionIfDue(): Promise<void> {
    if (
      !stagingCookieSessionActive ||
      !stagingCsrfToken ||
      Date.now() - stagingLastRotationAt < 25 * 60 * 1000
    ) {
      return;
    }
    if (stagingRotationPromise) return stagingRotationPromise;
    stagingRotationPromise = (async () => {
      const response = await fetch(
        `${API_BASE_URL}/staging-test-admin/session/rotate`,
        {
          method: "POST",
          headers: {
            Accept: "application/json",
            "X-Sakhi-CSRF": stagingCsrfToken as string,
          },
          credentials: "include",
          cache: "no-store",
        },
      );
      const data = (await response.json().catch(() => ({}))) as {
        csrfToken?: string;
        message?: string | string[];
      };
      if (!response.ok || !data.csrfToken) {
        const message = Array.isArray(data.message)
          ? data.message.join(" ")
          : data.message;
        throw new Error(
          message || "The secure staff session could not be rotated.",
        );
      }
      stagingCsrfToken = data.csrfToken;
      stagingLastRotationAt = Date.now();
    })();
    try {
      await stagingRotationPromise;
    } finally {
      stagingRotationPromise = null;
    }
  },
  getProfile(): AdminRbacProfile {
    return inMemoryProfile ?? LOCKED_ADMIN_PROFILE;
  },
  canAccessRoute(path: string): boolean {
    if (STAGING_TEST_ADMIN_MODE && !this.isFullStagingAdminSession()) {
      return false;
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
      return "/login";
    }
    const profile = this.getProfile();
    if (profile.role === "COMPLAINT_REVIEWER") return "/complaints";
    if (profile.role === "VERIFICATION_ADMIN") return "/verification";
    if (profile.role === "CONTENT_MODERATOR") return "/moderation";
    if (profile.role === "SOS_SAFETY_ADMIN") return "/emergency";
    if (profile.role === "BUSINESS_ADMIN") return "/businesses";
    if (profile.role === "READ_ONLY_AUDITOR") return "/audit-security";
    return "/dashboard";
  },
  async validateToken(token: string): Promise<AdminAuthResult> {
    if (!token) throw new Error("Enter your individual staff credential.");
    return requestSession(token);
  },
  async validateExistingSession(): Promise<AdminSession> {
    const response = await fetch(API_BASE_URL + "/staging-test-admin/session", {
      method: "GET",
      headers: { Accept: "application/json" },
      credentials: "include",
      cache: "no-store",
    });
    const data = (await response
      .json()
      .catch(() => ({}))) as Partial<AdminSession> & {
      message?: string | string[];
    };
    if (!response.ok) {
      const message = Array.isArray(data.message)
        ? data.message.join(" ")
        : data.message;
      throw new Error(message || "The staff session is no longer valid.");
    }
    if (data.mode !== "staging_full_admin" || !data.csrfToken) {
      throw new Error(
        "The existing session is not an individual MFA-verified staff session.",
      );
    }
    stagingSessionMode = "staging_full_admin";
    stagingSessionToken = null;
    stagingCookieSessionActive = true;
    stagingCsrfToken = data.csrfToken;
    stagingLastRotationAt = Date.now();
    inMemoryProfile = extractProfileFromPayload(data);
    return data as AdminSession;
  },
  async authenticate(
    token: string,
    mfaCode?: string,
  ): Promise<AdminAuthResult> {
    return requestSession(token, mfaCode);
  },
  async authenticateWithCredentials(
    identifier: string,
    password: string,
    mfaCode: string,
  ): Promise<AdminSession> {
    const response = await fetch(`${API_BASE_URL}/admin-review/auth/login`, {
      method: "POST",
      headers: {
        Accept: "application/json",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        identifier: identifier.trim(),
        password,
        mfaCode: mfaCode.trim(),
      }),
      credentials: "include",
      cache: "no-store",
    });
    const data = (await response
      .json()
      .catch(() => ({}))) as Partial<AdminSession> & {
      message?: string | string[];
    };
    if (!response.ok || !data.authenticated || !data.csrfToken) {
      const message = Array.isArray(data.message)
        ? data.message.join(" ")
        : data.message;
      throw new Error(message || "Credential or MFA authentication failed.");
    }
    stagingSessionMode = "staging_full_admin";
    stagingSessionToken = null;
    stagingCookieSessionActive = true;
    stagingCsrfToken = data.csrfToken;
    stagingLastRotationAt = Date.now();
    inMemoryProfile = extractProfileFromPayload(data);
    return { ...(data as AdminSession), mode: "staging_full_admin" };
  },
  async changeOwnPassword(newPassword: string): Promise<void> {
    const response = await fetch(
      `${API_BASE_URL}/admin-review/auth/password/change`,
      {
        method: "POST",
        headers: {
          Accept: "application/json",
          "Content-Type": "application/json",
          ...(stagingCsrfToken ? { "X-Sakhi-CSRF": stagingCsrfToken } : {}),
        },
        body: JSON.stringify({ newPassword }),
        credentials: "include",
        cache: "no-store",
      },
    );
    const data = await response.json().catch(() => ({}));
    if (!response.ok) {
      const message = Array.isArray(data.message)
        ? data.message.join(" ")
        : data.message;
      throw new Error(
        message || "The initial staff password could not be changed.",
      );
    }
    this.clearLocalSession();
  },
  async bootstrapSuperAdmin(
    token: string,
    fullName: string,
    email: string,
  ): Promise<{
    created: true;
    staffCode: string;
    accessToken: string;
    mfaEnrollmentRequired: true;
  }> {
    const response = await fetch(
      `${API_BASE_URL}/staging-test-admin/bootstrap/super-admin`,
      {
        method: "POST",
        headers: {
          Accept: "application/json",
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ token, fullName, email }),
        credentials: "include",
        cache: "no-store",
      },
    );
    const data = await response.json().catch(() => ({}));
    if (!response.ok)
      throw new Error(
        data.message || "The initial Super Admin bootstrap failed.",
      );
    return data;
  },
  async startMfaEnrollment(
    token: string,
  ): Promise<{ secret: string; otpauthUri: string; accountLabel: string }> {
    const response = await fetch(
      `${API_BASE_URL}/staging-test-admin/staff-mfa/enroll`,
      {
        method: "POST",
        headers: {
          Accept: "application/json",
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ token }),
        credentials: "include",
        cache: "no-store",
      },
    );
    const data = await response.json().catch(() => ({}));
    if (!response.ok)
      throw new Error(data.message || "Could not start MFA enrollment.");
    return data;
  },
  async verifyMfaEnrollment(
    token: string,
    code: string,
  ): Promise<{ enrolled: true; backupCodes: string[] }> {
    const response = await fetch(
      `${API_BASE_URL}/staging-test-admin/staff-mfa/verify-enrollment`,
      {
        method: "POST",
        headers: {
          Accept: "application/json",
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ token, code }),
        credentials: "include",
        cache: "no-store",
      },
    );
    const data = await response.json().catch(() => ({}));
    if (!response.ok)
      throw new Error(data.message || "MFA verification failed.");
    return data;
  },
  async requestMfaRecovery(
    token: string,
  ): Promise<{ requestId: string; status: string }> {
    const response = await fetch(
      `${API_BASE_URL}/staging-test-admin/staff-mfa/recovery/request`,
      {
        method: "POST",
        headers: {
          Accept: "application/json",
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ token }),
        credentials: "include",
        cache: "no-store",
      },
    );
    const data = await response.json().catch(() => ({}));
    if (!response.ok)
      throw new Error(
        data.message || "Could not create an MFA recovery request.",
      );
    return data;
  },
  async completeMfaRecovery(
    token: string,
    recoveryToken: string,
  ): Promise<{ recovered: true; mfaEnrollmentRequired: true }> {
    const response = await fetch(
      `${API_BASE_URL}/staging-test-admin/staff-mfa/recovery/complete`,
      {
        method: "POST",
        headers: {
          Accept: "application/json",
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ token, recoveryToken }),
        credentials: "include",
        cache: "no-store",
      },
    );
    const data = await response.json().catch(() => ({}));
    if (!response.ok)
      throw new Error(data.message || "MFA recovery completion failed.");
    return data;
  },
  async listPendingMfaRecoveryRequests(): Promise<
    Array<Record<string, unknown>>
  > {
    const response = await fetch(
      `${API_BASE_URL}/staging-test-admin/staff-mfa/recovery/pending`,
      {
        method: "GET",
        headers: { Accept: "application/json" },
        credentials: "include",
        cache: "no-store",
      },
    );
    const data = await response.json().catch(() => ({}));
    if (!response.ok)
      throw new Error(data.message || "Could not load MFA recovery requests.");
    return data as Array<Record<string, unknown>>;
  },
  async approveMfaRecoveryRequest(
    requestId: string,
  ): Promise<{ recoveryToken: string; expiresAt: string }> {
    const response = await fetch(
      `${API_BASE_URL}/staging-test-admin/staff-mfa/recovery/approve`,
      {
        method: "POST",
        headers: {
          Accept: "application/json",
          "Content-Type": "application/json",
          ...(stagingCsrfToken ? { "X-Sakhi-CSRF": stagingCsrfToken } : {}),
        },
        body: JSON.stringify({ requestId }),
        credentials: "include",
        cache: "no-store",
      },
    );
    const data = await response.json().catch(() => ({}));
    if (!response.ok)
      throw new Error(data.message || "MFA recovery approval failed.");
    return data;
  },
  async rotateMfaEncryptionKeys(): Promise<{
    rotated: number;
    targetVersion: string;
  }> {
    const response = await fetch(
      `${API_BASE_URL}/staging-test-admin/staff-mfa/encryption-keys/rotate`,
      {
        method: "POST",
        headers: {
          Accept: "application/json",
          ...(stagingCsrfToken ? { "X-Sakhi-CSRF": stagingCsrfToken } : {}),
        },
        credentials: "include",
        cache: "no-store",
      },
    );
    const data = await response.json().catch(() => ({}));
    if (!response.ok)
      throw new Error(data.message || "MFA encryption key rotation failed.");
    return data;
  },
  async signOut(): Promise<void> {
    const headers: Record<string, string> = { Accept: "application/json" };
    if (stagingCsrfToken) headers["X-Sakhi-CSRF"] = stagingCsrfToken;
    const response = await fetch(API_BASE_URL + "/staging-test-admin/logout", {
      method: "POST",
      headers,
      credentials: "include",
      cache: "no-store",
    });
    if (!response.ok) {
      throw new Error(
        "The server did not confirm staff-session revocation. You remain signed in.",
      );
    }
    stagingSessionToken = null;
    stagingCookieSessionActive = false;
    stagingCsrfToken = null;
    stagingSessionMode = null;
    stagingLastRotationAt = 0;
    stagingRotationPromise = null;
    inMemoryProfile = null;
  },
  clearLocalSession(): void {
    stagingSessionToken = null;
    stagingCookieSessionActive = false;
    stagingCsrfToken = null;
    stagingSessionMode = null;
    stagingLastRotationAt = 0;
    stagingRotationPromise = null;
    inMemoryProfile = null;
  },
};
