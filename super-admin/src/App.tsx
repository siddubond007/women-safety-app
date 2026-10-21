import { useEffect, useState } from "react";
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
import { StagingTestAccessPage } from "./pages/StagingTestAccessPage";

function AppRoutes() {
  const [isSignedIn, setIsSignedIn] = useState(() => adminAuthService.hasActiveSession());
  const [checkingSession, setCheckingSession] = useState(
    () => Boolean(adminAuthService.getToken()),
  );
  const canAccessFullWorkspace =
    !isStagingTestAdminMode || adminAuthService.isFullStagingAdminSession();
  const landingPath = canAccessFullWorkspace ? "/dashboard" : "/test-access";

  useEffect(() => {
    const token = adminAuthService.getToken();
    if (!token) return;
    adminAuthService
      .validateExistingSession()
      .then(() => setIsSignedIn(true))
      .catch(() => {
        adminAuthService.signOut();
        setIsSignedIn(false);
      })
      .finally(() => setCheckingSession(false));
  }, []);

  async function enterAdmin(token: string) {
    await adminAuthService.authenticate(token);
    setIsSignedIn(true);
  }

  function endSession() {
    adminAuthService.signOut();
    setIsSignedIn(false);
  }

  if (checkingSession) {
    return (
      <main className="admin-session-check" role="status">
        Checking reviewer session...
      </main>
    );
  }

  return (
    <Routes>
      <Route
        path="/login"
        element={
          isSignedIn ? <Navigate to={landingPath} replace /> : <LoginPage onAuthenticate={enterAdmin} />
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
        <Route path="/dashboard" element={canAccessFullWorkspace ? <DashboardPage /> : <Navigate to="/test-access" replace />} />
        <Route path="/members" element={canAccessFullWorkspace ? <MemberManagementPage /> : <Navigate to="/test-access" replace />} />
        <Route path="/verification" element={canAccessFullWorkspace ? <EligibilityReviewPage /> : <Navigate to="/test-access" replace />} />
        <Route path="/verifications" element={canAccessFullWorkspace ? <EligibilityReviewPage /> : <Navigate to="/test-access" replace />} />
        <Route path="/community" element={canAccessFullWorkspace ? <CommunityManagementPage /> : <Navigate to="/test-access" replace />} />
        <Route path="/moderation" element={canAccessFullWorkspace ? <ModerationPage section="moderation" /> : <Navigate to="/test-access" replace />} />
        <Route path="/emergency" element={canAccessFullWorkspace ? <ModerationPage section="emergency" /> : <Navigate to="/test-access" replace />} />
        <Route path="/audit-security" element={canAccessFullWorkspace ? <ModerationPage section="audit" /> : <Navigate to="/test-access" replace />} />
        <Route path="/integrations" element={canAccessFullWorkspace ? <ModerationPage section="integrations" /> : <Navigate to="/test-access" replace />} />
        <Route path="*" element={canAccessFullWorkspace ? <PlannedPage /> : <Navigate to="/test-access" replace />} />
      </Route>
      <Route path="*" element={<Navigate to={landingPath} replace />} />
    </Routes>
  );
}

export default function App() {
  return (
    <BrowserRouter>
      <AppRoutes />
    </BrowserRouter>
  );
}
