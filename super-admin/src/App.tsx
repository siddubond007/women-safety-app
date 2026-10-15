import { useState } from "react";
import { BrowserRouter, Navigate, Route, Routes } from "react-router-dom";
import { AdminLayout } from "./layouts/AdminLayout";
import { DashboardPage } from "./pages/DashboardPage";
import { LoginPage } from "./pages/LoginPage";
import { PlannedPage } from "./pages/PlannedPage";

const DEMO_SESSION_KEY = "sakhi-admin-demo-session";

function AppRoutes() {
  const [isDemoSignedIn, setIsDemoSignedIn] = useState(
    () => window.sessionStorage.getItem(DEMO_SESSION_KEY) === "active",
  );

  function enterDemo() {
    window.sessionStorage.setItem(DEMO_SESSION_KEY, "active");
    setIsDemoSignedIn(true);
  }

  function endDemo() {
    window.sessionStorage.removeItem(DEMO_SESSION_KEY);
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