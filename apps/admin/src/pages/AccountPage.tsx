import { useState, type FormEvent } from "react";
import { useNavigate } from "react-router-dom";
import { api } from "../lib/api.ts";
import { useAuth } from "../lib/auth-context.tsx";
import { errorMessage, roleLabel } from "../lib/format.ts";
import { useToast } from "../lib/toast.tsx";
import { ConfirmDialog } from "../components/ConfirmDialog.tsx";
import { usePageTitle } from "../components/usePageTitle.ts";

const MIN = 12;

export function AccountPage() {
  usePageTitle("Account");
  const { admin, replaceTokens, signOutEverywhere } = useAuth();
  const toast = useToast();
  const navigate = useNavigate();
  const forced = admin?.mustChangePassword ?? false;
  const [current, setCurrent] = useState("");
  const [next, setNext] = useState("");
  const [confirm, setConfirm] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [confirmAll, setConfirmAll] = useState(false);

  const mismatch = confirm.length > 0 && confirm !== next;
  const valid = current.length > 0 && next.length >= MIN && next === confirm;

  async function submit(e: FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError(null);
    try {
      const { data } = await api.post("/admin/me/password", { currentPassword: current, newPassword: next });
      await replaceTokens(data);
      setCurrent("");
      setNext("");
      setConfirm("");
      toast.success("Password changed. Other sessions were signed out.");
      if (forced) navigate("/vendors", { replace: true });
    } catch (err) {
      setError(errorMessage(err, "Could not change the password."));
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="page">
      <h1>Account</h1>
      {forced && (
        <p className="notice" role="alert">
          You are using a temporary password. Choose a new one to continue.
        </p>
      )}
      <section className="card">
        <p>
          {admin?.name} · {admin?.email} · {admin ? roleLabel(admin.role) : ""}
        </p>
        <h2>Change password</h2>
        <form className="form-stack" onSubmit={submit}>
          <label>
            Current password
            <input type="password" value={current} onChange={(e) => setCurrent(e.target.value)} autoComplete="current-password" required />
          </label>
          <label>
            New password (at least {MIN} characters)
            <input type="password" value={next} onChange={(e) => setNext(e.target.value)} autoComplete="new-password" minLength={MIN} required />
          </label>
          <label>
            Confirm new password
            <input type="password" value={confirm} onChange={(e) => setConfirm(e.target.value)} autoComplete="new-password" required />
          </label>
          {mismatch && <p className="error-text">Passwords do not match.</p>}
          {error && (
            <p className="error-text" role="alert">
              {error}
            </p>
          )}
          <div>
            <button type="submit" disabled={busy || !valid}>
              {busy ? "Saving…" : "Change password"}
            </button>
          </div>
        </form>
      </section>

      {!forced && (
        <section className="card section-gap">
          <h2>Sessions</h2>
          <p>Sign out of every browser and device where this account is logged in, including this one.</p>
          <button type="button" className="danger" onClick={() => setConfirmAll(true)}>
            Log out everywhere
          </button>
        </section>
      )}

      <ConfirmDialog
        open={confirmAll}
        title="Log out everywhere?"
        confirmLabel="Log out everywhere"
        danger
        onCancel={() => setConfirmAll(false)}
        onConfirm={() => void signOutEverywhere()}
      >
        <p>You will be signed out of all sessions and need to log in again.</p>
      </ConfirmDialog>
    </div>
  );
}
