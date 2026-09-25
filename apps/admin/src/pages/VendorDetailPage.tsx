import { useState } from "react";
import { Link, useNavigate, useParams } from "react-router-dom";
import { useVendors } from "../lib/vendor-context.tsx";
import { api } from "../lib/api.ts";

export function VendorDetailPage() {
  const { id } = useParams<{ id: string }>();
  const { getVendor } = useVendors();
  const navigate = useNavigate();
  const vendor = id ? getVendor(id) : undefined;

  const [showRejectForm, setShowRejectForm] = useState(false);
  const [reason, setReason] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  if (!vendor) {
    return (
      <div className="page">
        <p className="page-status">
          Vendor not found here — go back to the <Link to="/vendors">queue</Link> and open it from
          there.
        </p>
      </div>
    );
  }

  async function handleApprove() {
    setSubmitting(true);
    setError(null);
    try {
      await api.post(`/admin/vendors/${vendor!.id}/approve`);
      navigate("/vendors");
    } catch {
      setError("Failed to approve vendor.");
      setSubmitting(false);
    }
  }

  async function handleReject() {
    if (!reason.trim()) return;
    setSubmitting(true);
    setError(null);
    try {
      await api.post(`/admin/vendors/${vendor!.id}/reject`, { reason });
      navigate("/vendors");
    } catch {
      setError("Failed to reject vendor.");
      setSubmitting(false);
    }
  }

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
            {vendor.vendorVendorCategories.map((c) => c.vendorCategory.categoryKey).join(", ") ||
              "—"}
          </dd>
          <dt>Price tier</dt>
          <dd>{vendor.priceTier ?? "—"}</dd>
          <dt>Service area</dt>
          <dd>{vendor.serviceArea ?? "—"}</dd>
          <dt>Status</dt>
          <dd>{vendor.status}</dd>
          {vendor.rejectionReason && (
            <>
              <dt>Rejection reason</dt>
              <dd>{vendor.rejectionReason}</dd>
            </>
          )}
        </dl>

        <h2>Portfolio</h2>
        <div className="portfolio-grid">
          {vendor.portfolioItems.map((item) => (
            <figure key={item.id}>
              <img src={item.mediaUrl} alt={item.caption ?? ""} />
              {item.caption && <figcaption>{item.caption}</figcaption>}
            </figure>
          ))}
        </div>

        {error && <p className="error-text">{error}</p>}

        {vendor.status === "pending_review" && (
          <div className="review-actions">
            {!showRejectForm ? (
              <>
                <button onClick={handleApprove} disabled={submitting}>
                  Approve
                </button>
                <button
                  className="danger"
                  onClick={() => setShowRejectForm(true)}
                  disabled={submitting}
                >
                  Reject
                </button>
              </>
            ) : (
              <div className="reject-form">
                <label>
                  Reason for rejection
                  <textarea value={reason} onChange={(e) => setReason(e.target.value)} rows={3} />
                </label>
                <div className="review-actions">
                  <button
                    className="danger"
                    onClick={handleReject}
                    disabled={submitting || !reason.trim()}
                  >
                    Confirm reject
                  </button>
                  <button onClick={() => setShowRejectForm(false)} disabled={submitting}>
                    Cancel
                  </button>
                </div>
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  );
}
