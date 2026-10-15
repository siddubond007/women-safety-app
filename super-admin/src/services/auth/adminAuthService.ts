/**
 * Auth service contract for the admin UI. A production implementation must
 * come from a server-backed auth/session design; the browser demo is not
 * authorization and must never be used to protect production data.
 */
export interface AdminAuthService {
  hasActiveSession(): boolean;
  enterDemoSession(): void;
  signOut(): void;
}

const DEMO_SESSION_KEY = "sakhi-admin-demo-session";

class BrowserDemoAuthService implements AdminAuthService {
  hasActiveSession(): boolean {
    return window.sessionStorage.getItem(DEMO_SESSION_KEY) === "active";
  }

  enterDemoSession(): void {
    window.sessionStorage.setItem(DEMO_SESSION_KEY, "active");
  }

  signOut(): void {
    window.sessionStorage.removeItem(DEMO_SESSION_KEY);
  }
}

export const adminAuthService: AdminAuthService = new BrowserDemoAuthService();
