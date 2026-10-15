import { useState } from "react";
import { BrowserRouter, Navigate, Route, Routes } from "react-router-dom";
import { adminAuthService } from "./services/auth/adminAuthService";
import { AdminLayout } from "./layouts/AdminLayout";
import { DashboardPage } from "./pages/DashboardPage";
import { LoginPage } from "./pages/LoginPage";
import { PlannedPage } from "./pages/PlannedPage";

function AppRoutes() {
  const [isDemoSignedIn, setIsDemoSignedIn] = useState(
    () => adminAuthService.hasActiveSession(),
  );

  function enterDemo() {
    adminAuthService.enterDemoSession();
    setIsDemoSignedIn(true);
  }

  function endDemo() {
    adminAuthService.signOut();
    setIsDemoSignedIn(false);
  }

  return (
    <Routes>
      <Route
        path="/login"
        element={isDemoSignedIn ? <Navigate to="/dashboard" replace /> : <LoginPage onEnterDemo={enterDemo} />}
      />
      <Route path="/" element={<Navigate to="/dashboard" replace />} />
      <Route
        element={isDemoSignedIn ? <AdminLayout onSignOut={endDemo} /> : <Navigate to="/login" replace />}
      >
        <Route path="/dashboard" element={<DashboardPage />} />
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
