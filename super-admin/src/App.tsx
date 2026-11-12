import { useEffect, useState, type ReactElement } from "react";
import { BrowserRouter, Navigate, Route, Routes } from "react-router-dom";
import { adminAuthService, isStagingTestAdminMode } from "./services/auth/adminAuthService";
import { AdminLayout } from "./layouts/AdminLayout";
import { DashboardPage } from "./pages/DashboardPage";
import { LoginPage } from "./pages/LoginPage";
import { PlannedPage } from "./pages/PlannedPage";
import { MemberManagementPage } from "./pages/MemberManagementPage";
import { EligibilityReviewPage } from "./pages/EligibilityReviewPage";
import { CommunityManagementPage } from "./pages/CommunityManagementPage";
import { ModerationPage } from "./pages/ModerationPage";
import { ComplaintsManagementPage } from "./pages/ComplaintsManagementPage";
import { SafetyConsolePage } from "./pages/SafetyConsolePage";
import { StagingTestAccessPage } from "./pages/StagingTestAccessPage";
import { RegistrationPolicyPage } from "./pages/RegistrationPolicyPage";
import { AdminRolesAndConfigPage } from "./pages/AdminRolesAndConfigPage";
import { BusinessManagementPage } from "./pages/BusinessManagementPage";
import { SakhiQuoteLoader } from "./components/SakhiQuoteLoader";

function RoleProtectedRoute({
  path,
  element,
}: {
  path: string;
  element: ReactElement;
}) {
  if (!adminAuthService.canAccessRoute(path)) {
    return <Navigate to={adminAuthService.getDefaultLandingRoute()} replace />;
  }
  return element;
}

function AppRoutes() {
  const [isSignedIn, setIsSignedIn] = useState(() => adminAuthService.hasActiveSession());
  const [checkingSession, setCheckingSession] = useState(
    () => isStagingTestAdminMode || Boolean(adminAuthService.getToken()),
  );
  const [logoutError, setLogoutError] = useState<string | null>(null);
  const canAccessFullWorkspace =
    !isStagingTestAdminMode || adminAuthService.isFullStagingAdminSession();
  const landingPath = canAccessFullWorkspace
    ? adminAuthService.getDefaultLandingRoute()
    : "/test-access";

  useEffect(() => {
    const token = adminAuthService.getToken();
    if (!isStagingTestAdminMode && !token) return;
    adminAuthService
      .validateExistingSession()
      .then(() => setIsSignedIn(true))
      .catch(() => {
        adminAuthService.clearLocalSession();
        setIsSignedIn(false);
      })
      .finally(() => setCheckingSession(false));
  }, []);

  async function enterAdmin(token: string, mfaCode?: string) {
    const result = await adminAuthService.authenticate(token, mfaCode);
    if (result.authenticated) setIsSignedIn(true);
    return result;
  }

  async function enterAdminWithCredentials(identifier: string, password: string, mfaCode: string) {
    await adminAuthService.authenticateWithCredentials(identifier, password, mfaCode);
    setIsSignedIn(true);
  }

  async function endSession() {
    setLogoutError(null);
    try {
      await adminAuthService.signOut();
      setIsSignedIn(false);
    } catch (error) {
      setLogoutError(error instanceof Error ? error.message : "The server did not confirm logout.");
    }
  }

  if (checkingSession) {
    return (
      <main className="admin-session-check" role="status">
        <SakhiQuoteLoader statusLabel="Checking reviewer session..." />
      </main>
    );
  }

  return (
    <>
    {logoutError && <div role="alert" className="admin-auth-error">{logoutError}</div>}
    <Routes>
      <Route
        path="/login"
        element={
          isSignedIn ? <Navigate to={landingPath} replace /> : <LoginPage onAuthenticate={enterAdmin} onCredentialAuthenticate={enterAdminWithCredentials} />
        }
      />
      <Route path="/" element={<Navigate to={landingPath} replace />} />
      <Route
        element={
          isSignedIn ? <AdminLayout onSignOut={endSession} /> : <Navigate to="/login" replace />
        }
      >
        {isStagingTestAdminMode && (
          <Route
            path="/test-access"
            element={<StagingTestAccessPage onSignOut={endSession} embedded />}
          />
        )}
        <Route
          path="/dashboard"
          element={
            canAccessFullWorkspace ? (
              <RoleProtectedRoute path="/dashboard" element={<DashboardPage />} />
            ) : (
              <Navigate to="/test-access" replace />
            )
          }
        />
        <Route
          path="/action-center"
          element={
            canAccessFullWorkspace ? (
              <RoleProtectedRoute path="/action-center" element={<ModerationPage section="action-center" />} />
            ) : (
              <Navigate to="/test-access" replace />
            )
          }
        />
        <Route
          path="/members"
          element={
            canAccessFullWorkspace ? (
              <RoleProtectedRoute
                path="/members"
                element={<MemberManagementPage isStagingTest={isStagingTestAdminMode} />}
              />
            ) : (
              <Navigate to="/test-access" replace />
            )
          }
        />
        <Route
          path="/verification"
          element={
            canAccessFullWorkspace ? (
              <RoleProtectedRoute path="/verification" element={<EligibilityReviewPage />} />
            ) : (
              <Navigate to="/test-access" replace />
            )
          }
        />
        <Route
          path="/verifications"
          element={
            canAccessFullWorkspace ? (
              <RoleProtectedRoute path="/verifications" element={<EligibilityReviewPage />} />
            ) : (
              <Navigate to="/test-access" replace />
            )
          }
        />
        <Route
          path="/community"
          element={
            canAccessFullWorkspace ? (
              <RoleProtectedRoute path="/community" element={<CommunityManagementPage />} />
            ) : (
              <Navigate to="/test-access" replace />
            )
          }
        />
        <Route
          path="/wellness"
          element={
            canAccessFullWorkspace ? (
              <RoleProtectedRoute path="/wellness" element={<ModerationPage section="wellness" />} />
            ) : (
              <Navigate to="/test-access" replace />
            )
          }
        />
        <Route
          path="/moderation"
          element={
            canAccessFullWorkspace ? (
              <RoleProtectedRoute
                path="/moderation"
                element={<ModerationPage section="moderation" />}
              />
            ) : (
              <Navigate to="/test-access" replace />
            )
          }
        />
        <Route
          path="/complaints"
          element={
            canAccessFullWorkspace ? (
              <RoleProtectedRoute
                path="/complaints"
                element={<ComplaintsManagementPage />}
              />
            ) : (
              <Navigate to="/test-access" replace />
            )
          }
        />
        <Route
          path="/emergency"
          element={
            canAccessFullWorkspace ? (
              <RoleProtectedRoute path="/emergency" element={<SafetyConsolePage />} />
            ) : (
              <Navigate to="/test-access" replace />
            )
          }
        />
        <Route
          path="/businesses"
          element={
            canAccessFullWorkspace ? (
              <RoleProtectedRoute
                path="/businesses"
                element={<BusinessManagementPage />}
              />
            ) : (
              <Navigate to="/test-access" replace />
            )
          }
        />
        <Route
          path="/admin-users"
          element={
            canAccessFullWorkspace ? (
              <RoleProtectedRoute
                path="/admin-users"
                element={<AdminRolesAndConfigPage />}
              />
            ) : (
              <Navigate to="/test-access" replace />
            )
          }
        />
        <Route
          path="/audit-security"
          element={
            canAccessFullWorkspace ? (
              <RoleProtectedRoute
                path="/audit-security"
                element={<ModerationPage section="audit" />}
              />
            ) : (
              <Navigate to="/test-access" replace />
            )
          }
        />
        <Route
          path="/integrations"
          element={
            canAccessFullWorkspace ? (
              <RoleProtectedRoute
                path="/integrations"
                element={<ModerationPage section="integrations" />}
              />
            ) : (
              <Navigate to="/test-access" replace />
            )
          }
        />
        <Route
          path="/settings"
          element={
            canAccessFullWorkspace ? (
              <RoleProtectedRoute
                path="/settings"
                element={<RegistrationPolicyPage />}
              />
            ) : (
              <Navigate to="/test-access" replace />
            )
          }
        />
        <Route
          path="*"
          element={
            canAccessFullWorkspace ? (
              <PlannedPage />
            ) : (
              <Navigate to="/test-access" replace />
            )
          }
        />
      </Route>
      <Route path="*" element={<Navigate to={landingPath} replace />} />
    </Routes>
    </>
  );
}

export default function App() {
  return (
    <BrowserRouter>
      <AppRoutes />
    </BrowserRouter>
  );
}
