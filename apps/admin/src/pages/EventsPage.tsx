import { Link } from "react-router-dom";
import { formatDate, formatMoney } from "../lib/format.ts";
import { EVENT_TYPES, eventTypeLabel } from "../lib/event-types.ts";
import { useApi } from "../lib/useApi.ts";
import { useListParams } from "../lib/useListParams.ts";
import { ErrorRetry } from "../components/ErrorRetry.tsx";
import { Pagination } from "../components/Pagination.tsx";
import { SearchBox } from "../components/SearchBox.tsx";
import { StatusBadge } from "../components/StatusBadge.tsx";
import { usePageTitle } from "../components/usePageTitle.ts";

interface EventRow {
  id: string;
  name: string;
  eventType: string;
  region: string;
  primaryDate: string;
  totalBudget: string;
  status: string;
  organizer: { id: string; displayName: string | null; phoneNumber: string };
  _count: { tasks: number; guests: number };
}

const STATUSES = ["planning", "active", "completed", "archived"];

export function EventsPage() {
  usePageTitle("Events");
  const { params, update, page } = useListParams();
  const q = params.get("q") ?? "";
  const status = params.get("status") ?? "";
  const eventType = params.get("eventType") ?? "";
  const { data, state, reload } = useApi<{ events: EventRow[]; total: number; pageSize: number }>("/admin/events", { q, status, eventType, page });

  return (
    <div className="page">
      <header className="page-header">
        <h1>Events</h1>
      </header>
      <div className="filters">
        <SearchBox value={q} onSearch={(v) => update({ q: v || null })} label="Search events" placeholder="Search event, region, family" />
        <label>
          <span className="sr-only">Status</span>
          <select value={status} onChange={(e) => update({ status: e.target.value || null })}>
            <option value="">Any status</option>
            {STATUSES.map((s) => <option key={s} value={s}>{s[0]!.toUpperCase() + s.slice(1)}</option>)}
          </select>
        </label>
        <label>
          <span className="sr-only">Event type</span>
          <select value={eventType} onChange={(e) => update({ eventType: e.target.value || null })}>
            <option value="">Any type</option>
            {EVENT_TYPES.map((t) => <option key={t} value={t}>{eventTypeLabel(t)}</option>)}
          </select>
        </label>
      </div>

      {state === "loading" && <p className="page-status">Loading…</p>}
      {state === "error" && <ErrorRetry message="Failed to load events." onRetry={() => void reload()} />}
      {state === "ready" && data && data.events.length === 0 && <p className="page-status">No events found.</p>}
      <ul className="vendor-list">
        {data?.events.map((e) => (
          <li key={e.id}>
            <Link to={`/events/${e.id}`} className="vendor-row">
              <div className="vendor-row-info">
                <strong>{e.name}</strong>
                <span>
                  {eventTypeLabel(e.eventType)} · {formatDate(e.primaryDate)} · {e.region} · {formatMoney(e.totalBudget)} · {e.organizer.displayName ?? e.organizer.phoneNumber} · {e._count.tasks} tasks
                </span>
              </div>
              <StatusBadge status={e.status} />
            </Link>
          </li>
        ))}
      </ul>
      {data && <Pagination page={page} pageSize={data.pageSize} total={data.total} onChange={(p) => update({ page: p > 1 ? String(p) : null })} />}
    </div>
  );
}
