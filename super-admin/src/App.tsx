import { useEffect, useState } from "react";
import { BrowserRouter, Navigate, Route, Routes } from "react-router-dom";
import { adminAuthService } from "./services/auth/adminAuthService";
import { AdminLayout } from "./layouts/AdminLayout";
import { DashboardPage } from "./pages/DashboardPage";
import { LoginPage } from "./pages/LoginPage";
import { PlannedPage } from "./pages/PlannedPage";
import { MemberManagementPage } from "./pages/MemberManagementPage";
import { EligibilityReviewPage } from "./pages/EligibilityReviewPage";
import { CommunityManagementPage } from "./pages/CommunityManagementPage";
import { ModerationPage } from "./pages/ModerationPage";

function AppRoutes() {
  const [isSignedIn, setIsSignedIn] = useState(() => adminAuthService.hasActiveSession());
  const [sessionMode, setSessionMode] = useState<"local_dev_test_only" | "staging_test_only">("local_dev_test_only");
  const [checkingSession, setCheckingSession] = useState(() => Boolean(adminAuthService.getToken()));

  useEffect(() => {
    const token = adminAuthService.getToken();
    if (!token) return;
    adminAuthService
      .validateToken(token)
      .then((session) => {
        setSessionMode(session.mode);
        setIsSignedIn(true);
      })
      .catch(() => {
        adminAuthService.signOut();
        setSessionMode("local_dev_test_only");
        setIsSignedIn(false);
      })
      .finally(() => setCheckingSession(false));
  }, []);

  async function enterAdmin(token: string) {
    const session = await adminAuthService.authenticate(token);
    setSessionMode(session.mode);
    setIsSignedIn(true);
  }

  function endSession() {
    adminAuthService.signOut();
    setSessionMode("local_dev_test_only");
    setIsSignedIn(false);
  }

  if (checkingSession) {
    return (
      <main className="admin-session-check" role="status">
        Checking local reviewer session...
      </main>
    );
  }

  return (
    <Routes>
      <Route
        path="/login"
        element={
          isSignedIn ? <Navigate to="/dashboard" replace /> : <LoginPage onAuthenticate={enterAdmin} />
        }
      />
      <Route path="/" element={<Navigate to="/dashboard" replace />} />
      <Route
        element={
          isSignedIn ? <AdminLayout onSignOut={endSession} mode={sessionMode} /> : <Navigate to="/login" replace />
        }
      >
        <Route path="/dashboard" element={<DashboardPage />} />
        <Route path="/members" element={<MemberManagementPage isStagingTest={sessionMode === "staging_test_only"} />} />
        <Route path="/verification" element={<EligibilityReviewPage />} />
        <Route path="/verifications" element={<EligibilityReviewPage />} />
        <Route path="/community" element={<CommunityManagementPage />} />
        <Route path="/moderation" element={<ModerationPage section="moderation" />} />
        <Route path="/emergency" element={<ModerationPage section="emergency" />} />
        <Route path="/audit-security" element={<ModerationPage section="audit" />} />
        <Route path="/integrations" element={<ModerationPage section="integrations" />} />
        <Route path="*" element={<PlannedPage />} />
      </Route>
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
