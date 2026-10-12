import { useState } from "react";
import { Link, useParams } from "react-router-dom";
import { api } from "../lib/api.ts";
import { useAuth } from "../lib/auth-context.tsx";
import { errorMessage, formatDate, formatMoney, timeAgo } from "../lib/format.ts";
import { useApi } from "../lib/useApi.ts";
import { useToast } from "../lib/toast.tsx";
import { ConfirmDialog } from "../components/ConfirmDialog.tsx";
import { ErrorRetry } from "../components/ErrorRetry.tsx";
import { StatusBadge } from "../components/StatusBadge.tsx";
import { usePageTitle } from "../components/usePageTitle.ts";

interface Detail {
  id: string;
  displayName: string | null;
  phoneNumber: string;
  email: string | null;
  organizerType: string | null;
  status: "active" | "suspended";
  createdAt: string;
  suspension: { metadata: { reason?: string } | null; createdAt: string; admin: { name: string } | null } | null;
  eventGroups: { id: string; name: string; eventType: string; region: string; primaryDate: string; totalBudget: string; status: string; _count: { tasks: number; guests: number } }[];
}

export function FamilyDetailPage() {
  const { id } = useParams<{ id: string }>();
  const { can } = useAuth();
  const toast = useToast();
  const { data, state, reload } = useApi<Detail>(`/admin/organizers/${id}`);
  const [dialog, setDialog] = useState<"suspend" | "unsuspend" | null>(null);
  const [reason, setReason] = useState("");
  const [busy, setBusy] = useState(false);
  usePageTitle(data?.displayName ?? "Family");

  async function run() {
    if (!dialog) return;
    setBusy(true);
    try {
      await api.post(`/admin/organizers/${id}/${dialog}`, dialog === "suspend" ? { reason: reason.trim() } : undefined);
      toast.success(dialog === "suspend" ? "Family suspended. They are signed out." : "Family restored.");
      setDialog(null);
      setReason("");
      await reload(true);
    } catch (err) {
      toast.error(errorMessage(err, "Action failed."));
      setDialog(null);
      await reload(true);
    } finally {
      setBusy(false);
    }
  }

  if (state === "loading") return <div className="page"><p className="page-status">Loading…</p></div>;
  if (state === "notfound") return <div className="page"><p className="page-status">Family not found. <Link to="/families">Back</Link></p></div>;
  if (state === "error" || !data) return <div className="page"><ErrorRetry message="Failed to load this family." onRetry={() => void reload()} /></div>;

  return (
    <div className="page">
      <header className="page-header">
        <Link to="/families" className="link-button">← Back to families</Link>
      </header>
      <div className="card">
        <h1>
          {data.displayName ?? "(no name yet)"} <StatusBadge status={data.status} />
        </h1>
        <dl className="vendor-details">
          <dt>Phone</dt>
          <dd><a href={`tel:${data.phoneNumber}`}>{data.phoneNumber}</a></dd>
          <dt>Email</dt>
          <dd>{data.email ?? "—"}</dd>
          <dt>Type</dt>
          <dd>{data.organizerType ?? "—"}</dd>
          <dt>Joined</dt>
          <dd>{formatDate(data.createdAt)} ({timeAgo(data.createdAt)})</dd>
          {data.suspension && (
            <>
              <dt>Suspended</dt>
              <dd>
                {data.suspension.metadata?.reason ?? "No reason recorded"}
                {data.suspension.admin ? ` · by ${data.suspension.admin.name}` : ""} · {formatDate(data.suspension.createdAt)}
              </dd>
            </>
          )}
        </dl>
        {can("organizer.manage") && (
          <div className="review-actions section-gap">
            {data.status === "active" ? (
              <button type="button" className="danger" onClick={() => setDialog("suspend")}>Suspend</button>
            ) : (
              <button type="button" onClick={() => setDialog("unsuspend")}>Restore access</button>
            )}
          </div>
        )}
      </div>

      <h2 className="section-gap">Events ({data.eventGroups.length})</h2>
      {data.eventGroups.length === 0 && <p className="page-status">No events yet.</p>}
      <ul className="vendor-list">
        {data.eventGroups.map((e) => (
          <li key={e.id}>
            <Link to={`/events/${e.id}`} className="vendor-row">
              <div className="vendor-row-info">
                <strong>{e.name}</strong>
                <span>
                  {formatDate(e.primaryDate)} · {e.region} · {formatMoney(e.totalBudget)} · {e._count.tasks} tasks · {e._count.guests} guests
                </span>
              </div>
              <StatusBadge status={e.status} />
            </Link>
          </li>
        ))}
      </ul>

      <ConfirmDialog
        open={dialog !== null}
        title={dialog === "suspend" ? "Suspend this family?" : "Restore access?"}
        confirmLabel={dialog === "suspend" ? "Suspend" : "Restore"}
        danger={dialog === "suspend"}
        busy={busy}
        confirmDisabled={dialog === "suspend" && !reason.trim()}
        onCancel={() => { setDialog(null); setReason(""); }}
        onConfirm={() => void run()}
      >
        {dialog === "suspend" ? (
          <>
            <p>They are signed out at once and cannot use the app until restored.</p>
            <label>
              Reason (recorded in the audit log)
              <textarea value={reason} onChange={(e) => setReason(e.target.value)} rows={3} maxLength={1000} />
            </label>
          </>
        ) : (
          <p>{data.displayName ?? data.phoneNumber} can sign in again.</p>
        )}
      </ConfirmDialog>
    </div>
  );
}
