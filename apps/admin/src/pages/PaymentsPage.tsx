import { Link } from "react-router-dom";
import { formatDate, formatMoney } from "../lib/format.ts";
import { useApi } from "../lib/useApi.ts";
import { useListParams } from "../lib/useListParams.ts";
import { ErrorRetry } from "../components/ErrorRetry.tsx";
import { Pagination } from "../components/Pagination.tsx";
import { usePageTitle } from "../components/usePageTitle.ts";
import { CommerceNav, NOT_LIVE, type PaymentRow } from "./BookingsPage.tsx";

interface Row extends PaymentRow {
  overdue: boolean;
  booking: { id: string; vendor: { id: string; businessName: string | null }; eventGroup: { id: string; name: string } };
}

export function PaymentsPage() {
  usePageTitle("Payments");
  const { params, update, page } = useListParams();
  const status = params.get("status") ?? "";
  const { data, state, reload } = useApi<{ payments: Row[]; total: number; pageSize: number }>("/admin/payments", { status, page });

  return (
    <div className="page">
      <header className="page-header">
        <h1>Bookings</h1>
      </header>
      <CommerceNav />
      <p className="muted">Read-only. Overdue means unpaid past the due date.</p>
      <div className="filters">
        <label>
          <span className="sr-only">Status</span>
          <select value={status} onChange={(e) => update({ status: e.target.value || null })}>
            <option value="">All payments</option>
            <option value="overdue">Overdue</option>
            <option value="pending">Upcoming</option>
            <option value="paid">Paid</option>
          </select>
        </label>
      </div>

      {state === "loading" && <p className="page-status">Loading…</p>}
      {state === "error" && <ErrorRetry message="Failed to load payments." onRetry={() => void reload()} />}
      {state === "ready" && data && data.payments.length === 0 && <p className="page-status">{status ? "No payments match." : NOT_LIVE}</p>}
      <ul className="vendor-list">
        {data?.payments.map((p) => (
          <li key={p.id}>
            <Link to={`/bookings/${p.booking.id}`} className="vendor-row">
              <div className="vendor-row-info">
                <strong>
                  {formatMoney(p.amount)} · {p.milestoneType} · {p.booking.vendor.businessName ?? "Vendor"}
                </strong>
                <span>
                  {p.booking.eventGroup.name} · due {formatDate(p.dueDate)}
                  {p.paidAt ? ` · paid ${formatDate(p.paidAt)}` : ""}
                </span>
              </div>
              <span className={`badge ${p.status === "paid" ? "badge-success" : p.overdue ? "badge-danger" : "badge-warn"}`}>
                {p.status === "paid" ? "Paid" : p.overdue ? "Overdue" : "Upcoming"}
              </span>
            </Link>
          </li>
        ))}
      </ul>
      {data && <Pagination page={page} pageSize={data.pageSize} total={data.total} onChange={(n) => update({ page: n > 1 ? String(n) : null })} />}
    </div>
  );
}
