import { useCallback, useEffect, useState } from "react";
import { Link, useNavigate, useParams } from "react-router-dom";
import { vendorCategoryLabel } from "@sanchalan/shared-types";
import type { VendorDetail } from "../lib/vendor-context.tsx";
import { api } from "../lib/api.ts";

type Pending = "reject" | "suspend" | null;

function errorMessage(err: unknown, fallback: string): string {
  const message = (err as { response?: { data?: { error?: string } } })?.response?.data?.error;
  return message ?? fallback;
}

export function VendorDetailPage() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();

  const [vendor, setVendor] = useState<VendorDetail | null>(null);
  const [loadState, setLoadState] = useState<"loading" | "error" | "notfound" | "ready">("loading");
  const [pending, setPending] = useState<Pending>(null);
  const [reason, setReason] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

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
    load();
  }, [load]);

  if (loadState === "loading") {
    return (
      <div className="page">
        <p className="page-status">Loading…</p>
      </div>
    );
  }

  if (loadState !== "ready" || !vendor) {
    return (
      <div className="page">
        <p className="page-status">
          {loadState === "notfound" ? "Vendor not found." : "Failed to load vendor."}{" "}
          <Link to="/vendors">Back to queue</Link>
        </p>
      </div>
    );
  }

  async function act(path: string, body?: object, failure = "Action failed."): Promise<boolean> {
    setSubmitting(true);
    setError(null);
    try {
      await api.post(`/admin/vendors/${vendor!.id}/${path}`, body);
      setPending(null);
      setReason("");
      await load();
      return true;
    } catch (err) {
      setError(errorMessage(err, failure));
      return false;
    } finally {
      setSubmitting(false);
    }
  }

  const showReasonForm = pending !== null;

  return (
    <div className="page">
      <header className="page-header">
        <Link to="/vendors" className="link-button">
          ← Back to queue
        </Link>
      </header>

      <div className="card">
        <h1>{vendor.businessName ?? "(no business name)"}</h1>
        <dl className="vendor-details">
          <dt>Contact</dt>
          <dd>
            {vendor.contactPersonName ?? "—"} · {vendor.phoneNumber}
            {vendor.email ? ` · ${vendor.email}` : ""}
          </dd>
          <dt>Categories</dt>
          <dd>
            {vendor.vendorVendorCategories
              .map((c) => vendorCategoryLabel(c.vendorCategory.categoryKey))
              .join(", ") || "—"}
          </dd>
          <dt>Price tier</dt>
          <dd>{vendor.priceTier ?? "—"}</dd>
          <dt>Starting price</dt>
          <dd>{vendor.startingPrice != null ? `₹${vendor.startingPrice.toLocaleString("en-IN")}` : "—"}</dd>
          <dt>Experience</dt>
          <dd>{vendor.yearsOfExperience != null ? `${vendor.yearsOfExperience} years` : "—"}</dd>
          <dt>Service area</dt>
          <dd>{vendor.serviceArea ?? "—"}</dd>
          <dt>Links</dt>
          <dd>
            {[vendor.instagramUrl, vendor.websiteUrl].filter(Boolean).join(" · ") || "—"}
          </dd>
          <dt>Status</dt>
          <dd>{vendor.status.replace("_", " ")}</dd>
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
                <span> · {new Date(log.createdAt).toLocaleString()}</span>
                {log.reason && <div>{log.reason}</div>}
              </li>
            ))}
          </ul>
        )}

        {error && <p className="error-text">{error}</p>}

        <div className="review-actions">
          {vendor.status === "pending_review" && !showReasonForm && (
            <>
              <button onClick={() => act("approve", undefined, "Failed to approve vendor.")} disabled={submitting}>
                Approve
              </button>
              <button className="danger" onClick={() => setPending("reject")} disabled={submitting}>
                Reject
              </button>
            </>
          )}
          {vendor.status === "published" && !showReasonForm && (
            <button className="danger" onClick={() => setPending("suspend")} disabled={submitting}>
              Suspend
            </button>
          )}
          {vendor.status === "suspended" && (
            <button onClick={() => act("unsuspend", undefined, "Failed to unsuspend vendor.")} disabled={submitting}>
              Unsuspend
            </button>
          )}
        </div>

        {showReasonForm && (
          <div className="reject-form">
            <label>
              {pending === "reject" ? "Reason for rejection" : "Reason for suspension"}
              <textarea value={reason} onChange={(e) => setReason(e.target.value)} rows={3} />
            </label>
            <div className="review-actions">
              <button
                className="danger"
                onClick={() =>
                  act(pending!, { reason: reason.trim() }, `Failed to ${pending} vendor.`).then((ok) => {
                    if (ok && pending === "reject") navigate("/vendors");
                  })
                }
                disabled={submitting || !reason.trim()}
              >
                Confirm {pending}
              </button>
              <button onClick={() => setPending(null)} disabled={submitting}>
                Cancel
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
