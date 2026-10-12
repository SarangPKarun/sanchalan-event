import { useState } from "react";
import { Link } from "react-router-dom";
import { api } from "../lib/api.ts";
import { useAuth } from "../lib/auth-context.tsx";
import { errorMessage, formatDate } from "../lib/format.ts";
import { useApi } from "../lib/useApi.ts";
import { useListParams } from "../lib/useListParams.ts";
import { useToast } from "../lib/toast.tsx";
import { ConfirmDialog } from "../components/ConfirmDialog.tsx";
import { ErrorRetry } from "../components/ErrorRetry.tsx";
import { Pagination } from "../components/Pagination.tsx";
import { SearchBox } from "../components/SearchBox.tsx";
import { usePageTitle } from "../components/usePageTitle.ts";

interface ReviewRow {
  id: string;
  rating: number;
  comment: string | null;
  status: "visible" | "flagged" | "hidden";
  moderationReason: string | null;
  createdAt: string;
  vendor: { id: string; businessName: string | null };
  eventGroup: { id: string; name: string };
  moderator: { name: string } | null;
}

const TONE = { visible: "badge-success", flagged: "badge-warn", hidden: "badge-danger" } as const;
const LABEL = { visible: "Visible", flagged: "Flagged", hidden: "Hidden" } as const;

export function ReviewsPage() {
  usePageTitle("Reviews");
  const { can } = useAuth();
  const toast = useToast();
  const { params, update, page } = useListParams();
  const q = params.get("q") ?? "";
  const status = params.get("status") ?? "";
  const rating = params.get("rating") ?? "";
  const { data, state, reload } = useApi<{ reviews: ReviewRow[]; total: number; pageSize: number }>("/admin/reviews", { q, status, rating, page });
  const [target, setTarget] = useState<{ review: ReviewRow; action: "hide" | "restore" } | null>(null);
  const [reason, setReason] = useState("");
  const [busy, setBusy] = useState(false);
  const canModerate = can("review.moderate");

  async function run() {
    if (!target) return;
    setBusy(true);
    try {
      await api.post(`/admin/reviews/${target.review.id}/${target.action}`, target.action === "hide" ? { reason: reason.trim() } : undefined);
      toast.success(target.action === "hide" ? "Review hidden." : "Review restored.");
    } catch (err) {
      toast.error(errorMessage(err, "Action failed."));
    } finally {
      setBusy(false);
      setTarget(null);
      setReason("");
      await reload(true);
    }
  }

  return (
    <div className="page">
      <header className="page-header">
        <h1>Reviews</h1>
      </header>
      <p className="muted">Hidden reviews are kept but should not be shown to families. Reviews from families are not live in the app yet.</p>
      <div className="filters">
        <SearchBox value={q} onSearch={(v) => update({ q: v || null })} label="Search reviews" placeholder="Search comment or vendor" />
        <label>
          <span className="sr-only">Status</span>
          <select value={status} onChange={(e) => update({ status: e.target.value || null })}>
            <option value="">Any status</option>
            <option value="flagged">Flagged</option>
            <option value="visible">Visible</option>
            <option value="hidden">Hidden</option>
          </select>
        </label>
        <label>
          <span className="sr-only">Rating</span>
          <select value={rating} onChange={(e) => update({ rating: e.target.value || null })}>
            <option value="">Any rating</option>
            {[5, 4, 3, 2, 1].map((r) => <option key={r} value={r}>{r} star{r === 1 ? "" : "s"}</option>)}
          </select>
        </label>
      </div>

      {state === "loading" && <p className="page-status">Loading…</p>}
      {state === "error" && <ErrorRetry message="Failed to load reviews." onRetry={() => void reload()} />}
      {state === "ready" && data && data.reviews.length === 0 && (
        <p className="page-status">{q || status || rating ? "No reviews match." : "No reviews yet. Families cannot leave reviews in the app yet."}</p>
      )}
      <ul className="vendor-list">
        {data?.reviews.map((r) => (
          <li key={r.id} className="card admin-row">
            <div>
              <strong>{"★".repeat(r.rating)}{"☆".repeat(5 - r.rating)}</strong>{" "}
              <span className={`badge ${TONE[r.status]}`}>{LABEL[r.status]}</span>
              <p>{r.comment ?? <span className="muted">No comment</span>}</p>
              <div className="muted">
                <Link to={`/vendors/${r.vendor.id}`}>{r.vendor.businessName ?? "Vendor"}</Link> · <Link to={`/events/${r.eventGroup.id}`}>{r.eventGroup.name}</Link> · {formatDate(r.createdAt)}
                {r.status === "hidden" && r.moderationReason ? ` · hidden: ${r.moderationReason}${r.moderator ? ` (${r.moderator.name})` : ""}` : ""}
              </div>
            </div>
            {canModerate && (
              <button type="button" className={r.status === "hidden" ? undefined : "danger"} onClick={() => setTarget({ review: r, action: r.status === "hidden" ? "restore" : "hide" })}>
                {r.status === "hidden" ? "Restore" : "Hide"}
              </button>
            )}
          </li>
        ))}
      </ul>
      {data && <Pagination page={page} pageSize={data.pageSize} total={data.total} onChange={(p) => update({ page: p > 1 ? String(p) : null })} />}

      <ConfirmDialog
        open={target !== null}
        title={target?.action === "hide" ? "Hide this review?" : "Restore this review?"}
        confirmLabel={target?.action === "hide" ? "Hide" : "Restore"}
        danger={target?.action === "hide"}
        busy={busy}
        confirmDisabled={target?.action === "hide" && !reason.trim()}
        onCancel={() => { setTarget(null); setReason(""); }}
        onConfirm={() => void run()}
      >
        {target?.action === "hide" ? (
          <label>
            Reason (recorded in the audit log)
            <textarea value={reason} onChange={(e) => setReason(e.target.value)} rows={3} maxLength={1000} />
          </label>
        ) : (
          <p>The review becomes visible again.</p>
        )}
      </ConfirmDialog>
    </div>
  );
}
