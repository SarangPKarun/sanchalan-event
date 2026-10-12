import { Link, NavLink } from "react-router-dom";
import { formatDate, formatMoney } from "../lib/format.ts";
import { useApi } from "../lib/useApi.ts";
import { useListParams } from "../lib/useListParams.ts";
import { ErrorRetry } from "../components/ErrorRetry.tsx";
import { Pagination } from "../components/Pagination.tsx";
import { SearchBox } from "../components/SearchBox.tsx";
import { StatusBadge } from "../components/StatusBadge.tsx";
import { usePageTitle } from "../components/usePageTitle.ts";

export interface PaymentRow {
  id: string;
  milestoneType: string;
  amount: string;
  dueDate: string;
  paidAt: string | null;
  status: string;
}

export interface BookingRow {
  id: string;
  status: string;
  agreedPrice: string;
  createdAt: string;
  vendor: { id: string; businessName: string | null };
  eventGroup: { id: string; name: string; organizer: { id: string; displayName: string | null } };
  payments: PaymentRow[];
  paymentSummary: { count: number; paidAmount: number; agreedPrice: number; overdueCount: number };
}

export const NOT_LIVE = "Bookings and payments are not live in the app yet, so there is nothing to show. They will appear here once families start booking vendors.";

export function CommerceNav() {
  const cls = ({ isActive }: { isActive: boolean }) => (isActive ? "tab tab-active" : "tab");
  return (
    <nav className="tabs" aria-label="Bookings sections">
      <NavLink to="/bookings" end className={cls}>Bookings</NavLink>
      <NavLink to="/bookings/payments" className={cls}>Payments</NavLink>
    </nav>
  );
}

const STATUSES = ["requested", "confirmed", "completed", "cancelled"];

export function BookingsPage() {
  usePageTitle("Bookings");
  const { params, update, page } = useListParams();
  const q = params.get("q") ?? "";
  const status = params.get("status") ?? "";
  const { data, state, reload } = useApi<{ bookings: BookingRow[]; total: number; pageSize: number }>("/admin/bookings", { q, status, page });
  const filtered = !!q || !!status;

  return (
    <div className="page">
      <header className="page-header">
        <h1>Bookings</h1>
      </header>
      <CommerceNav />
      <p className="muted">Read-only. Admins cannot change bookings or move money.</p>
      <div className="filters">
        <SearchBox value={q} onSearch={(v) => update({ q: v || null })} label="Search bookings" placeholder="Search vendor or event" />
        <label>
          <span className="sr-only">Status</span>
          <select value={status} onChange={(e) => update({ status: e.target.value || null })}>
            <option value="">Any status</option>
            {STATUSES.map((s) => <option key={s} value={s}>{s[0]!.toUpperCase() + s.slice(1)}</option>)}
          </select>
        </label>
      </div>

      {state === "loading" && <p className="page-status">Loading…</p>}
      {state === "error" && <ErrorRetry message="Failed to load bookings." onRetry={() => void reload()} />}
      {state === "ready" && data && data.bookings.length === 0 && <p className="page-status">{filtered ? "No bookings match." : NOT_LIVE}</p>}
      <ul className="vendor-list">
        {data?.bookings.map((b) => (
          <li key={b.id}>
            <Link to={`/bookings/${b.id}`} className="vendor-row">
              <div className="vendor-row-info">
                <strong>{b.vendor.businessName ?? "Vendor"} · {b.eventGroup.name}</strong>
                <span>
                  {formatMoney(b.agreedPrice)} agreed · {formatMoney(b.paymentSummary.paidAmount)} paid
                  {b.paymentSummary.overdueCount > 0 ? ` · ${b.paymentSummary.overdueCount} overdue` : ""} · {formatDate(b.createdAt)}
                </span>
              </div>
              <StatusBadge status={b.status} />
            </Link>
          </li>
        ))}
      </ul>
      {data && <Pagination page={page} pageSize={data.pageSize} total={data.total} onChange={(p) => update({ page: p > 1 ? String(p) : null })} />}
    </div>
  );
}
