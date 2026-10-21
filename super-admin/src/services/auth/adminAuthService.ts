const STAGING_TEST_ADMIN_MODE = import.meta.env.VITE_ADMIN_MODE === "staging-test";
const LOCAL_TOKEN_KEY = "sakhi-admin-review-token";
const API_BASE_URL = (
  import.meta.env.VITE_API_BASE_URL ?? "http://127.0.0.1:3001/api/v1"
).replace(/\/+$/, "");

let stagingSessionToken: string | null = null;

export const isStagingTestAdminMode = STAGING_TEST_ADMIN_MODE;

export interface AdminSession {
  authenticated: true;
  reviewerLabel: string;
  mode: "local_dev_test_only" | "staging_test_access_only";
  message?: string;
  sessionToken?: string;
  sessionExpiresAt?: string;
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
  const data = (await response.json().catch(() => ({}))) as {
    message?: string | string[];
    reviewerLabel?: string;
    mode?: string;
    authenticated?: boolean;
    sessionToken?: string;
    sessionExpiresAt?: string;
  };
  if (!response.ok) {
    const message = Array.isArray(data.message) ? data.message.join(" ") : data.message;
    throw new Error(message || "Reviewer token was not accepted by the backend.");
  }

  if (staging) {
    if (!data.sessionToken) {
      throw new Error("The backend did not issue a staging admin session.");
    }
    // Only the short-lived signed session is kept in module memory. The
    // master reviewer token is not retained in memory after the login call
    // and is never written to browser storage or injected into the static site.
    stagingSessionToken = data.sessionToken;
  }
  return data as AdminSession;
}

export const adminAuthService = {
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
      const data = (await response.json().catch(() => ({}))) as {
        message?: string | string[];
      };
      if (!response.ok) {
        const message = Array.isArray(data.message) ? data.message.join(" ") : data.message;
        throw new Error(message || "The staging reviewer session is no longer valid.");
      }
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
    const data = (await response.json().catch(() => ({}))) as {
      message?: string | string[];
    };
    if (!response.ok) {
      const message = Array.isArray(data.message) ? data.message.join(" ") : data.message;
      throw new Error(message || "The saved local reviewer session is no longer valid.");
    }
    return data as AdminSession;
  },
  async authenticate(token: string): Promise<AdminSession> {
    const session = await requestSession(token);
    if (!STAGING_TEST_ADMIN_MODE) {
      sessionStorage.setItem(LOCAL_TOKEN_KEY, token);
    }
    return session;
  },
  signOut(): void {
    if (STAGING_TEST_ADMIN_MODE) {
      stagingSessionToken = null;
    } else {
      sessionStorage.removeItem(LOCAL_TOKEN_KEY);
    }
  },
};
