import { Link, useParams } from "react-router-dom";
import { formatDate, formatMoney } from "../lib/format.ts";
import { useApi } from "../lib/useApi.ts";
import { ErrorRetry } from "../components/ErrorRetry.tsx";
import { StatusBadge } from "../components/StatusBadge.tsx";
import { usePageTitle } from "../components/usePageTitle.ts";
import type { BookingRow } from "./BookingsPage.tsx";

export function BookingDetailPage() {
  const { id } = useParams<{ id: string }>();
  const { data, state, reload } = useApi<BookingRow>(`/admin/bookings/${id}`);
  usePageTitle("Booking");

  if (state === "loading") return <div className="page"><p className="page-status">Loading…</p></div>;
  if (state === "notfound") return <div className="page"><p className="page-status">Booking not found. <Link to="/bookings">Back</Link></p></div>;
  if (state === "error" || !data) return <div className="page"><ErrorRetry message="Failed to load this booking." onRetry={() => void reload()} /></div>;

  const today = new Date().toISOString().slice(0, 10);
  return (
    <div className="page">
      <header className="page-header">
        <Link to="/bookings" className="link-button">← Back to bookings</Link>
      </header>
      <div className="card">
        <h1>
          {data.vendor.businessName ?? "Vendor"} <StatusBadge status={data.status} />
        </h1>
        <dl className="vendor-details">
          <dt>Vendor</dt>
          <dd><Link to={`/vendors/${data.vendor.id}`}>{data.vendor.businessName ?? "Open vendor"}</Link></dd>
          <dt>Event</dt>
          <dd><Link to={`/events/${data.eventGroup.id}`}>{data.eventGroup.name}</Link> · {data.eventGroup.organizer.displayName ?? "family"}</dd>
          <dt>Agreed price</dt>
          <dd>{formatMoney(data.agreedPrice)}</dd>
          <dt>Paid</dt>
          <dd>{formatMoney(data.paymentSummary.paidAmount)} of {formatMoney(data.paymentSummary.agreedPrice)}</dd>
          <dt>Created</dt>
          <dd>{formatDate(data.createdAt)}</dd>
        </dl>
        <h2>Payments</h2>
        {data.payments.length === 0 && <p className="page-status">No payment milestones.</p>}
        <ul className="vendor-list">
          {data.payments.map((p) => {
            const overdue = p.status !== "paid" && p.dueDate.slice(0, 10) < today;
            return (
              <li key={p.id} className="card admin-row">
                <div>
                  <strong>{p.milestoneType[0]!.toUpperCase() + p.milestoneType.slice(1)}</strong> · {formatMoney(p.amount)}
                  <div className="muted">due {formatDate(p.dueDate)}{p.paidAt ? ` · paid ${formatDate(p.paidAt)}` : ""}</div>
                </div>
                <span className={`badge ${p.status === "paid" ? "badge-success" : overdue ? "badge-danger" : "badge-warn"}`}>
                  {p.status === "paid" ? "Paid" : overdue ? "Overdue" : "Pending"}
                </span>
              </li>
            );
          })}
        </ul>
      </div>
    </div>
  );
}
