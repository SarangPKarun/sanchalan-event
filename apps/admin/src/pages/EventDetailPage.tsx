import { Link, useParams } from "react-router-dom";
import { vendorCategoryLabel } from "@sanchalan/shared-types";
import { formatDate, formatDateTime, formatMoney } from "../lib/format.ts";
import { eventTypeLabel } from "../lib/event-types.ts";
import { useApi } from "../lib/useApi.ts";
import { ErrorRetry } from "../components/ErrorRetry.tsx";
import { StatusBadge } from "../components/StatusBadge.tsx";
import { usePageTitle } from "../components/usePageTitle.ts";

interface Detail {
  id: string;
  name: string;
  eventType: string;
  region: string;
  religionOrTradition: string | null;
  totalBudget: string;
  budgetTier: string;
  guestCountEstimate: number;
  primaryDate: string;
  status: string;
  organizer: { id: string; displayName: string | null; phoneNumber: string };
  subEvents: { id: string; name: string; date: string; venueName: string | null; expectedGuestCount: number | null; status: string }[];
  tasks: { id: string; name: string; status: string; dueDate: string | null; ownerType: string; taskCategory: { categoryKey: string; label: string | null }; linkedVendor: { id: string; businessName: string | null } | null }[];
  budgetCategories: { id: string; categoryKey: string; allocatedAmount: string }[];
  budgetLines: { id: string; description: string; amount: string; entryType: string; budgetCategory: { categoryKey: string }; linkedVendor: { id: string; businessName: string | null } | null }[];
  roadmapGenerationLogs: { id: string; status: string; createdAt: string; llmModelUsed: string; inputTokens: number | null; outputTokens: number | null }[];
}

const taskStatusLabel = (s: string) => (s === "not_applicable" ? "Removed" : s[0]!.toUpperCase() + s.slice(1).replace(/_/g, " "));

export function EventDetailPage() {
  const { id } = useParams<{ id: string }>();
  const { data, state, reload } = useApi<Detail>(`/admin/events/${id}`);
  usePageTitle(data?.name ?? "Event");

  if (state === "loading") return <div className="page"><p className="page-status">Loading…</p></div>;
  if (state === "notfound") return <div className="page"><p className="page-status">Event not found. <Link to="/events">Back</Link></p></div>;
  if (state === "error" || !data) return <div className="page"><ErrorRetry message="Failed to load this event." onRetry={() => void reload()} /></div>;

  const live = data.tasks.filter((t) => t.status !== "not_applicable");
  const counts = live.reduce<Record<string, number>>((acc, t) => ({ ...acc, [t.status]: (acc[t.status] ?? 0) + 1 }), {});
  const spent = data.budgetLines.reduce((sum, l) => sum + Number(l.amount), 0);

  return (
    <div className="page">
      <header className="page-header">
        <Link to="/events" className="link-button">← Back to events</Link>
      </header>
      <div className="card">
        <h1>
          {data.name} <StatusBadge status={data.status} />
        </h1>
        <dl className="vendor-details">
          <dt>Family</dt>
          <dd><Link to={`/families/${data.organizer.id}`}>{data.organizer.displayName ?? data.organizer.phoneNumber}</Link></dd>
          <dt>Type</dt>
          <dd>{eventTypeLabel(data.eventType)}{data.religionOrTradition ? ` · ${data.religionOrTradition}` : ""}</dd>
          <dt>Date and place</dt>
          <dd>{formatDate(data.primaryDate)} · {data.region}</dd>
          <dt>Guests</dt>
          <dd>~{data.guestCountEstimate}</dd>
          <dt>Budget</dt>
          <dd>{formatMoney(data.totalBudget)} ({data.budgetTier}) · recorded {formatMoney(spent)}</dd>
        </dl>
      </div>

      <h2 className="section-gap">Sub-events ({data.subEvents.length})</h2>
      {data.subEvents.length === 0 && <p className="page-status">None.</p>}
      <ul className="vendor-list">
        {data.subEvents.map((s) => (
          <li key={s.id} className="card admin-row">
            <div>
              <strong>{s.name}</strong>
              <div className="muted">{formatDate(s.date)}{s.venueName ? ` · ${s.venueName}` : ""}{s.expectedGuestCount ? ` · ${s.expectedGuestCount} guests` : ""}</div>
            </div>
            <StatusBadge status={s.status} />
          </li>
        ))}
      </ul>

      <h2 className="section-gap">Roadmap ({live.length} tasks)</h2>
      <p className="muted">{Object.entries(counts).map(([k, v]) => `${v} ${taskStatusLabel(k).toLowerCase()}`).join(" · ") || "No tasks."}</p>
      <ul className="vendor-list">
        {data.tasks.map((t) => (
          <li key={t.id} className="card admin-row">
            <div>
              <strong>{t.name}</strong>
              <div className="muted">
                {t.taskCategory.label ?? vendorCategoryLabel(t.taskCategory.categoryKey)} · {t.ownerType}
                {t.dueDate ? ` · due ${formatDate(t.dueDate)}` : ""}
                {t.linkedVendor && (
                  <>
                    {" · "}
                    <Link to={`/vendors/${t.linkedVendor.id}`}>{t.linkedVendor.businessName ?? "vendor"}</Link>
                  </>
                )}
              </div>
            </div>
            <span className="badge badge-neutral">{taskStatusLabel(t.status)}</span>
          </li>
        ))}
      </ul>

      <h2 className="section-gap">Budget</h2>
      {data.budgetCategories.length === 0 && data.budgetLines.length === 0 && <p className="page-status">Nothing recorded.</p>}
      <ul className="vendor-list">
        {data.budgetCategories.map((c) => {
          const lines = data.budgetLines.filter((l) => l.budgetCategory.categoryKey === c.categoryKey);
          return (
            <li key={c.id} className="card">
              <strong>{vendorCategoryLabel(c.categoryKey)}</strong> <span className="muted">allocated {formatMoney(c.allocatedAmount)}</span>
              {lines.map((l) => (
                <div key={l.id} className="muted">
                  {l.description} · {formatMoney(l.amount)} ({l.entryType})
                  {l.linkedVendor ? ` · ${l.linkedVendor.businessName ?? "vendor"}` : ""}
                </div>
              ))}
            </li>
          );
        })}
      </ul>

      <h2 className="section-gap">AI generations</h2>
      {data.roadmapGenerationLogs.length === 0 && <p className="page-status">None.</p>}
      <ul className="vendor-list">
        {data.roadmapGenerationLogs.map((l) => (
          <li key={l.id}>
            <Link to={`/roadmap/${l.id}`} className="vendor-row">
              <span>{formatDateTime(l.createdAt)} · {l.llmModelUsed}{l.inputTokens != null ? ` · ${l.inputTokens + (l.outputTokens ?? 0)} tokens` : ""}</span>
              <span className={`badge ${l.status === "success" ? "badge-success" : "badge-danger"}`}>{l.status === "success" ? "Succeeded" : "Failed"}</span>
            </Link>
          </li>
        ))}
      </ul>
    </div>
  );
}
