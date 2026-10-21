const TOKEN_KEY = "sakhi-admin-review-token";
const API_BASE_URL = (
  import.meta.env.VITE_API_BASE_URL ?? "http://127.0.0.1:3001/api/v1"
).replace(/\/+$/, "");

export interface AdminSession {
  authenticated: true;
  reviewerLabel: string;
  mode: "local_dev_test_only" | "staging_test_only";
}

async function requestSession(token: string): Promise<AdminSession> {
  const response = await fetch(`${API_BASE_URL}/admin-review/session`, {
    method: "GET",
    headers: {
      "X-Sakhi-Admin-Token": token,
      "x-sakhi-admin-review-token": token,
    },
    cache: "no-store",
  });
  const data = (await response.json().catch(() => ({}))) as {
    message?: string | string[];
    reviewerLabel?: string;
    mode?: string;
    authenticated?: boolean;
  };
  if (!response.ok) {
    const message = Array.isArray(data.message) ? data.message.join(" ") : data.message;
    throw new Error(message || "Reviewer token was not accepted by the backend.");
  }
  return data as AdminSession;
}

export const adminAuthService = {
  hasActiveSession(): boolean {
    return Boolean(sessionStorage.getItem(TOKEN_KEY));
  },
  getToken(): string | null {
    return sessionStorage.getItem(TOKEN_KEY);
  },
  async validateToken(token: string): Promise<AdminSession> {
    if (!token) throw new Error("Enter the reviewer token.");
    return requestSession(token);
  },
  async authenticate(token: string): Promise<AdminSession> {
    const session = await requestSession(token);
    sessionStorage.setItem(TOKEN_KEY, token);
    return session;
  },
  signOut(): void {
    sessionStorage.removeItem(TOKEN_KEY);
  },
};
