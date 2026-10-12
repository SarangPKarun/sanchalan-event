import { Link } from "react-router-dom";
import { formatDate, timeAgo } from "../lib/format.ts";
import { useApi } from "../lib/useApi.ts";
import { useListParams } from "../lib/useListParams.ts";
import { ErrorRetry } from "../components/ErrorRetry.tsx";
import { Pagination } from "../components/Pagination.tsx";
import { SearchBox } from "../components/SearchBox.tsx";
import { StatusBadge } from "../components/StatusBadge.tsx";
import { usePageTitle } from "../components/usePageTitle.ts";

export interface OrganizerRow {
  id: string;
  displayName: string | null;
  phoneNumber: string;
  email: string | null;
  organizerType: string | null;
  status: "active" | "suspended";
  createdAt: string;
  lastSignInAt: string | null;
  _count: { eventGroups: number };
}

export function FamiliesPage() {
  usePageTitle("Families");
  const { params, update, page } = useListParams();
  const q = params.get("q") ?? "";
  const status = params.get("status") ?? "";
  const { data, state, reload } = useApi<{ organizers: OrganizerRow[]; total: number; pageSize: number }>("/admin/organizers", { q, status, page });

  return (
    <div className="page">
      <header className="page-header">
        <h1>Families</h1>
      </header>
      <div className="filters">
        <SearchBox value={q} onSearch={(v) => update({ q: v || null })} label="Search families" placeholder="Search name, phone, email" />
        <label>
          <span className="sr-only">Status</span>
          <select value={status} onChange={(e) => update({ status: e.target.value || null })}>
            <option value="">Any status</option>
            <option value="active">Active</option>
            <option value="suspended">Suspended</option>
          </select>
        </label>
      </div>

      {state === "loading" && <p className="page-status">Loading…</p>}
      {state === "error" && <ErrorRetry message="Failed to load families." onRetry={() => void reload()} />}
      {state === "ready" && data && data.organizers.length === 0 && <p className="page-status">No families found.</p>}
      <ul className="vendor-list">
        {data?.organizers.map((o) => (
          <li key={o.id}>
            <Link to={`/families/${o.id}`} className="vendor-row">
              <div className="vendor-row-info">
                <strong>{o.displayName ?? "(no name yet)"}</strong>
                <span>
                  {o.phoneNumber} · {o._count.eventGroups} event{o._count.eventGroups === 1 ? "" : "s"} · joined {formatDate(o.createdAt)} · last sign-in {timeAgo(o.lastSignInAt)}
                </span>
              </div>
              <StatusBadge status={o.status} />
            </Link>
          </li>
        ))}
      </ul>
      {data && <Pagination page={page} pageSize={data.pageSize} total={data.total} onChange={(p) => update({ page: p > 1 ? String(p) : null })} />}
    </div>
  );
}
