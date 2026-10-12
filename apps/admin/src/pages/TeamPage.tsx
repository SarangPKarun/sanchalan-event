import { useCallback, useEffect, useState, type FormEvent } from "react";
import { api } from "../lib/api.ts";
import { useAuth } from "../lib/auth-context.tsx";
import { errorMessage, formatDate, roleLabel } from "../lib/format.ts";
import { useToast } from "../lib/toast.tsx";
import { ConfirmDialog } from "../components/ConfirmDialog.tsx";
import { ErrorRetry } from "../components/ErrorRetry.tsx";
import { StatusBadge } from "../components/StatusBadge.tsx";
import { usePageTitle } from "../components/usePageTitle.ts";

type Role = "super_admin" | "vendor_reviewer" | "support";

interface TeamAdmin {
  id: string;
  name: string;
  email: string;
  role: Role;
  status: "active" | "disabled";
  mustChangePassword: boolean;
  lastLoginAt: string | null;
}

const ROLES: Role[] = ["super_admin", "vendor_reviewer", "support"];

type Pending =
  | { kind: "disable" | "enable" | "reset"; admin: TeamAdmin }
  | { kind: "role"; admin: TeamAdmin; role: Role };

export function TeamPage() {
  usePageTitle("Team");
  const { admin: me, can } = useAuth();
  const toast = useToast();
  const [admins, setAdmins] = useState<TeamAdmin[]>([]);
  const [state, setState] = useState<"loading" | "error" | "ready">("loading");
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [role, setRole] = useState<Role>("vendor_reviewer");
  const [busy, setBusy] = useState(false);
  const [pending, setPending] = useState<Pending | null>(null);
  const [secret, setSecret] = useState<{ who: string; password: string } | null>(null);

  const load = useCallback(async () => {
    try {
      const { data } = await api.get<{ admins: TeamAdmin[] }>("/admin/admins");
      setAdmins(data.admins);
      setState("ready");
    } catch {
      setState("error");
    }
  }, []);

  const allowed = can("team.manage");
  useEffect(() => {
    if (allowed) void load();
  }, [load, allowed]);

  async function add(e: FormEvent) {
    e.preventDefault();
    setBusy(true);
    try {
      const { data } = await api.post<{ admin: TeamAdmin; temporaryPassword: string }>("/admin/admins", { name, email, role });
      setSecret({ who: data.admin.email, password: data.temporaryPassword });
      setName("");
      setEmail("");
      await load();
    } catch (err) {
      toast.error(errorMessage(err, "Could not add the admin."));
    } finally {
      setBusy(false);
    }
  }

  async function confirmPending() {
    if (!pending) return;
    setBusy(true);
    try {
      const id = pending.admin.id;
      if (pending.kind === "reset") {
        const { data } = await api.post<{ temporaryPassword: string }>(`/admin/admins/${id}/reset-password`, {});
        setSecret({ who: pending.admin.email, password: data.temporaryPassword });
      } else {
        const body = pending.kind === "role" ? { role: pending.role } : { status: pending.kind === "disable" ? "disabled" : "active" };
        await api.patch(`/admin/admins/${id}`, body);
        toast.success("Updated.");
      }
      setPending(null);
      await load();
    } catch (err) {
      toast.error(errorMessage(err, "Action failed."));
      setPending(null);
    } finally {
      setBusy(false);
    }
  }

  const dialog = pending && {
    disable: { title: "Disable this admin?", label: "Disable", danger: true, text: "They are signed out immediately and cannot log in until re-enabled." },
    enable: { title: "Re-enable this admin?", label: "Enable", danger: false, text: "They can log in again." },
    reset: { title: "Reset password?", label: "Reset password", danger: true, text: "A new temporary password is generated and all their sessions end." },
    role: { title: "Change role?", label: "Change role", danger: false, text: pending.kind === "role" ? `New role: ${roleLabel(pending.role)}. Their sessions end so it applies immediately.` : "" },
  }[pending.kind];

  if (!allowed)
    return (
      <div className="page">
        <p className="page-status">Only super admins can manage the team.</p>
      </div>
    );

  return (
    <div className="page">
      <h1>Team</h1>

      {secret && (
        <div className="notice" role="alert">
          <p>
            Temporary password for <strong>{secret.who}</strong> (shown once, they must change it at first sign-in):
          </p>
          <code className="secret">{secret.password}</code>
          <div>
            <button type="button" className="secondary" onClick={() => setSecret(null)}>
              I have copied it
            </button>
          </div>
        </div>
      )}

      <section className="card">
        <h2>Add an admin</h2>
        <form className="form-row" onSubmit={add}>
          <label>
            Name
            <input value={name} onChange={(e) => setName(e.target.value)} required maxLength={100} />
          </label>
          <label>
            Email
            <input type="email" value={email} onChange={(e) => setEmail(e.target.value)} required />
          </label>
          <label>
            Role
            <select value={role} onChange={(e) => setRole(e.target.value as Role)}>
              {ROLES.map((r) => (
                <option key={r} value={r}>
                  {roleLabel(r)}
                </option>
              ))}
            </select>
          </label>
          <button type="submit" disabled={busy || !name.trim() || !email}>
            Add admin
          </button>
        </form>
      </section>

      {state === "loading" && <p className="page-status">Loading…</p>}
      {state === "error" && <ErrorRetry message="Failed to load the team." onRetry={load} />}
      {state === "ready" && (
        <ul className="vendor-list section-gap">
          {admins.map((a) => {
            const isMe = a.id === me?.id;
            return (
              <li key={a.id} className="card admin-row">
                <div>
                  <strong>{a.name}</strong> {isMe && <span className="badge badge-neutral">You</span>}{" "}
                  <StatusBadge status={a.status} />
                  <div className="muted">
                    {a.email} · {a.lastLoginAt ? `last login ${formatDate(a.lastLoginAt)}` : "never logged in"}
                    {a.mustChangePassword ? " · must change password" : ""}
                  </div>
                </div>
                {!isMe && (
                  <div className="review-actions">
                    <select
                      aria-label={`Role for ${a.name}`}
                      value={a.role}
                      onChange={(e) => setPending({ kind: "role", admin: a, role: e.target.value as Role })}
                    >
                      {ROLES.map((r) => (
                        <option key={r} value={r}>
                          {roleLabel(r)}
                        </option>
                      ))}
                    </select>
                    <button type="button" className="secondary" onClick={() => setPending({ kind: "reset", admin: a })}>
                      Reset password
                    </button>
                    <button
                      type="button"
                      className={a.status === "active" ? "danger" : undefined}
                      onClick={() => setPending({ kind: a.status === "active" ? "disable" : "enable", admin: a })}
                    >
                      {a.status === "active" ? "Disable" : "Enable"}
                    </button>
                  </div>
                )}
              </li>
            );
          })}
        </ul>
      )}

      <ConfirmDialog
        open={pending !== null}
        title={dialog?.title ?? ""}
        confirmLabel={dialog?.label ?? "Confirm"}
        danger={dialog?.danger ?? false}
        busy={busy}
        onCancel={() => setPending(null)}
        onConfirm={() => void confirmPending()}
      >
        <p>
          <strong>{pending?.admin.name}</strong>: {dialog?.text}
        </p>
      </ConfirmDialog>
    </div>
  );
}
