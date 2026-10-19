import { useEffect, useState } from "react";
import { BrowserRouter, Navigate, Route, Routes } from "react-router-dom";
import { adminAuthService } from "./services/auth/adminAuthService";
import { AdminLayout } from "./layouts/AdminLayout";
import { DashboardPage } from "./pages/DashboardPage";
import { LoginPage } from "./pages/LoginPage";
import { PlannedPage } from "./pages/PlannedPage";
import { MemberManagementPage } from "./pages/MemberManagementPage";
import { EligibilityReviewPage } from "./pages/EligibilityReviewPage";

function AppRoutes() {
  const [isSignedIn, setIsSignedIn] = useState(() => adminAuthService.hasActiveSession());
  const [checkingSession, setCheckingSession] = useState(() => Boolean(adminAuthService.getToken()));

  useEffect(() => {
    const token = adminAuthService.getToken();
    if (!token) return;
    adminAuthService.validateToken(token)
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
    return <main className="admin-session-check" role="status">Checking local reviewer session...</main>;
  }

  return (
    <Routes>
      <Route path="/login" element={isSignedIn ? <Navigate to="/dashboard" replace /> : <LoginPage onAuthenticate={enterAdmin} />} />
      <Route path="/" element={<Navigate to="/dashboard" replace />} />
      <Route element={isSignedIn ? <AdminLayout onSignOut={endSession} /> : <Navigate to="/login" replace />}>
        <Route path="/dashboard" element={<DashboardPage />} />
        <Route path="/members" element={<MemberManagementPage />} />
        <Route path="/verification" element={<EligibilityReviewPage />} />
                                                                        <Route path="*" element={<PlannedPage />} />
      </Route>
    </Routes>
  );
}

export default function App() {
  return <BrowserRouter><AppRoutes /></BrowserRouter>;
}

