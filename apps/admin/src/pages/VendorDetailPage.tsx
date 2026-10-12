import { useCallback, useEffect, useState } from "react";
import { Link, useNavigate, useParams } from "react-router-dom";
import { vendorCategoryLabel } from "@sanchalan/shared-types";
import type { VendorDetail } from "../lib/vendor-context.tsx";
import { api } from "../lib/api.ts";
import { useAuth } from "../lib/auth-context.tsx";
import { errorMessage, formatDateTime, tierLabel } from "../lib/format.ts";
import { useToast } from "../lib/toast.tsx";
import { ConfirmDialog } from "../components/ConfirmDialog.tsx";
import { ErrorRetry } from "../components/ErrorRetry.tsx";
import { StatusBadge } from "../components/StatusBadge.tsx";
import { usePageTitle } from "../components/usePageTitle.ts";

type Action = "approve" | "reject" | "suspend" | "unsuspend";

const COPY: Record<Action, { title: string; label: string; done: string; danger: boolean; needsReason: boolean }> = {
  approve: { title: "Approve this vendor?", label: "Approve", done: "Vendor approved.", danger: false, needsReason: false },
  reject: { title: "Reject this vendor?", label: "Reject", done: "Vendor rejected.", danger: true, needsReason: true },
  suspend: { title: "Suspend this vendor?", label: "Suspend", done: "Vendor suspended.", danger: true, needsReason: true },
  unsuspend: { title: "Unsuspend this vendor?", label: "Unsuspend", done: "Vendor unsuspended.", danger: false, needsReason: false },
};

const whatsappLink = (n: string) => `https://wa.me/${n.replace(/\D/g, "")}`;

export function VendorDetailPage() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const { can } = useAuth();
  const toast = useToast();

  const [vendor, setVendor] = useState<VendorDetail | null>(null);
  const [loadState, setLoadState] = useState<"loading" | "error" | "notfound" | "ready">("loading");
  const [action, setAction] = useState<Action | null>(null);
  const [reason, setReason] = useState("");
  const [submitting, setSubmitting] = useState(false);
  usePageTitle(vendor?.businessName ?? "Vendor");

  const load = useCallback(async () => {
    try {
      const { data } = await api.get<VendorDetail>(`/admin/vendors/${id}`);
      setVendor(data);
      setLoadState("ready");
    } catch (err) {
      const status = (err as { response?: { status?: number } })?.response?.status;
      setLoadState(status === 404 ? "notfound" : "error");
    }
  }, [id]);

  useEffect(() => {
    void load();
  }, [load]);

  async function run() {
    if (!action || !vendor) return;
    setSubmitting(true);
    try {
      await api.post(`/admin/vendors/${vendor.id}/${action}`, COPY[action].needsReason ? { reason: reason.trim() } : undefined);
      toast.success(COPY[action].done);
      const wasReject = action === "reject";
      setAction(null);
      setReason("");
      if (wasReject) navigate("/vendors?status=pending_review");
      else await load();
    } catch (err) {
      toast.error(errorMessage(err, `Failed to ${action} vendor.`));
      setAction(null);
      await load(); // the vendor may have changed under us (409)
    } finally {
      setSubmitting(false);
    }
  }

  if (loadState === "loading")
    return (
      <div className="page">
        <p className="page-status">Loading…</p>
      </div>
    );
  if (loadState === "notfound")
    return (
      <div className="page">
        <p className="page-status">
          Vendor not found. <Link to="/vendors">Back to vendors</Link>
        </p>
      </div>
    );
  if (loadState === "error" || !vendor)
    return (
      <div className="page">
        <ErrorRetry message="Failed to load vendor." onRetry={() => void load()} />
      </div>
    );

  const canReview = can("vendor.review");
  const copy = action ? COPY[action] : null;

  return (
    <div className="page">
      <header className="page-header">
        <Link to="/vendors" className="link-button">
          ← Back to vendors
        </Link>
      </header>

      <div className="card">
        <h1>
          {vendor.businessName ?? "(no business name)"} <StatusBadge status={vendor.status} />
        </h1>
        <dl className="vendor-details">
          <dt>Contact</dt>
          <dd>
            {vendor.contactPersonName ?? "—"} · <a href={`tel:${vendor.phoneNumber}`}>{vendor.phoneNumber}</a>
            {vendor.email && (
              <>
                {" · "}
                <a href={`mailto:${vendor.email}`}>{vendor.email}</a>
              </>
            )}
          </dd>
          <dt>Categories</dt>
          <dd>{vendor.vendorVendorCategories.map((c) => vendorCategoryLabel(c.vendorCategory.categoryKey)).join(", ") || "—"}</dd>
          <dt>Price tier</dt>
          <dd>{vendor.priceTier ? tierLabel(vendor.priceTier) : "—"}</dd>
          <dt>Starting price</dt>
          <dd>{vendor.startingPrice != null ? `₹${vendor.startingPrice.toLocaleString("en-IN")}` : "—"}</dd>
          <dt>Experience</dt>
          <dd>{vendor.yearsOfExperience != null ? `${vendor.yearsOfExperience} years` : "—"}</dd>
          <dt>Service area</dt>
          <dd>{vendor.serviceArea ?? "—"}</dd>
          <dt>Links</dt>
          <dd className="link-list">
            {vendor.whatsappNumber && <a href={whatsappLink(vendor.whatsappNumber)} target="_blank" rel="noreferrer">WhatsApp</a>}
            {vendor.instagramUrl && <a href={vendor.instagramUrl} target="_blank" rel="noreferrer">Instagram</a>}
            {vendor.websiteUrl && <a href={vendor.websiteUrl} target="_blank" rel="noreferrer">Website</a>}
            {!vendor.whatsappNumber && !vendor.instagramUrl && !vendor.websiteUrl && "—"}
          </dd>
          {vendor.rejectionReason && (
            <>
              <dt>Rejection reason</dt>
              <dd>{vendor.rejectionReason}</dd>
            </>
          )}
        </dl>

        <h2>About</h2>
        <p className="vendor-description">{vendor.description ?? "—"}</p>

        <h2>Past work</h2>
        {vendor.portfolioItems.length === 0 ? (
          <p>—</p>
        ) : (
          <ul className="past-work-list">
            {vendor.portfolioItems.map((item) => (
              <li key={item.id}>
                <strong>{item.title}</strong>
                {item.caption && <span>{item.caption}</span>}
              </li>
            ))}
          </ul>
        )}

        <h2>Review history</h2>
        {vendor.reviewLogs.length === 0 ? (
          <p>No activity yet.</p>
        ) : (
          <ul className="review-log">
            {vendor.reviewLogs.map((log) => (
              <li key={log.id}>
                <strong>{log.action.replace(/_/g, " ")}</strong>
                {log.admin ? ` by ${log.admin.name}` : ""}
                <span className="muted"> · {formatDateTime(log.createdAt)}</span>
                {log.reason && <div>{log.reason}</div>}
              </li>
            ))}
          </ul>
        )}

        {canReview ? (
          <div className="review-actions section-gap">
            {vendor.status === "pending_review" && (
              <>
                <button type="button" onClick={() => setAction("approve")}>Approve</button>
                <button type="button" className="danger" onClick={() => setAction("reject")}>Reject</button>
              </>
            )}
            {vendor.status === "published" && (
              <button type="button" className="danger" onClick={() => setAction("suspend")}>Suspend</button>
            )}
            {vendor.status === "suspended" && (
              <button type="button" onClick={() => setAction("unsuspend")}>Unsuspend</button>
            )}
          </div>
        ) : (
          <p className="muted section-gap">Your role can view vendors but not review them.</p>
        )}
      </div>

      <ConfirmDialog
        open={action !== null}
        title={copy?.title ?? ""}
        confirmLabel={copy?.label ?? "Confirm"}
        danger={copy?.danger ?? false}
        busy={submitting}
        confirmDisabled={!!copy?.needsReason && !reason.trim()}
        onCancel={() => { setAction(null); setReason(""); }}
        onConfirm={() => void run()}
      >
        {copy?.needsReason ? (
          <label>
            Reason (shown to the vendor)
            <textarea value={reason} onChange={(e) => setReason(e.target.value)} rows={3} maxLength={1000} />
          </label>
        ) : (
          <p>{vendor.businessName ?? "This vendor"}</p>
        )}
      </ConfirmDialog>
    </div>
  );
}
