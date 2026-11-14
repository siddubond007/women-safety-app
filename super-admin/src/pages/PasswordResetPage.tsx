import { useState, type FormEvent } from "react";
import { useNavigate } from "react-router-dom";
import { ArrowRight, LockKeyhole, ShieldCheck } from "lucide-react";
import { adminAuthService } from "../services/auth/adminAuthService";

export function PasswordResetPage({ onComplete }: { onComplete: () => void }) {
  const navigate = useNavigate();
  const [password, setPassword] = useState("");
  const [confirmation, setConfirmation] = useState("");
  const [error, setError] = useState("");
  const [saving, setSaving] = useState(false);

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError("");
    if (password.length < 10) {
      setError("Use at least 10 characters for your new password.");
      return;
    }
    if (password !== confirmation) {
      setError("The password confirmation does not match.");
      return;
    }
    setSaving(true);
    try {
      await adminAuthService.changeOwnPassword(password);
      setPassword("");
      setConfirmation("");
      onComplete();
      navigate("/login", { replace: true });
    } catch (cause) {
      setError(
        cause instanceof Error
          ? cause.message
          : "The password could not be changed.",
      );
    } finally {
      setSaving(false);
    }
  }

  return (
    <main className="login-page">
      <section className="login-card" aria-labelledby="password-reset-title">
        <div className="login-card-mark">
          <ShieldCheck size={24} />
        </div>
        <div className="login-card-kicker">SAKHI SECURE STAFF ACCESS</div>
        <h2 id="password-reset-title">Change your initial password</h2>
        <p className="login-card-description">
          Your account must use a private password before you can open the Admin
          workspace. Changing it will end this session; sign in again with your
          new password and MFA.
        </p>
        <form onSubmit={submit} className="login-credential-form">
          <label className="member-form-label" htmlFor="new-staff-password">
            New password <span>Required</span>
          </label>
          <input
            id="new-staff-password"
            className="admin-review-token-input"
            type="password"
            autoComplete="new-password"
            minLength={10}
            value={password}
            onChange={(event) => setPassword(event.target.value)}
            required
          />
          <label className="member-form-label" htmlFor="confirm-staff-password">
            Confirm new password <span>Required</span>
          </label>
          <input
            id="confirm-staff-password"
            className="admin-review-token-input"
            type="password"
            autoComplete="new-password"
            minLength={10}
            value={confirmation}
            onChange={(event) => setConfirmation(event.target.value)}
            required
          />
          {error && (
            <p className="admin-auth-error" role="alert">
              {error}
            </p>
          )}
          <button
            className="button login-submit"
            type="submit"
            disabled={
              saving || password.length < 10 || confirmation.length < 10
            }
          >
            {saving ? "Updating password..." : "Update password and sign out"}{" "}
            <ArrowRight size={16} />
          </button>
        </form>
        <p className="login-card-footer">
          <LockKeyhole size={13} /> Your password is never displayed to other
          staff.
        </p>
      </section>
    </main>
  );
}
