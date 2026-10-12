import { Link } from "react-router-dom";
import { useAuth } from "../lib/auth-context.tsx";
import { formatDateTime, timeAgo } from "../lib/format.ts";
import { useApi } from "../lib/useApi.ts";
import { ErrorRetry } from "../components/ErrorRetry.tsx";
import { usePageTitle } from "../components/usePageTitle.ts";
import { entityLink, type AuditEntry } from "./AuditPage.tsx";

interface Stats {
  vendors: Record<string, number>;
  proposals: Record<string, number>;
  organizers: number;
  events: number;
  roadmaps: { lastSevenDays: number; total: number; failedLastSevenDays: number; tokensLastThirtyDays: { input: number; output: number } };
  commerce: { bookings: number; overduePayments: number; flaggedReviews: number };
  oldestPending: { vendor: { id: string; businessName: string | null; submittedAt: string | null } | null; proposal: { id: string; label: string; submittedAt: string } | null };
}

function Card({ to, label, value, note, warn }: { to?: string; label: string; value: string | number; note?: string | undefined; warn?: boolean }) {
  const body = (
    <>
      <span className="muted">{label}</span>
      <strong className={warn ? "stat stat-warn" : "stat"}>{value}</strong>
      {note && <span className="muted">{note}</span>}
    </>
  );
  return to ? <Link to={to} className="card stat-card">{body}</Link> : <div className="card stat-card">{body}</div>;
}

export function DashboardPage() {
  usePageTitle("Dashboard");
  const { admin, can } = useAuth();
  const stats = useApi<Stats>("/admin/stats");
  const showAudit = can("audit.read");
  const audit = useApi<{ entries: AuditEntry[] }>("/admin/audit-logs", { pageSize: 8 }, showAudit);
  const s = stats.data;

  return (
    <div className="page">
      <header className="page-header">
        <h1>Hello, {admin?.name.split(" ")[0]}</h1>
      </header>
      {stats.state === "loading" && <p className="page-status">Loading…</p>}
      {stats.state === "error" && <ErrorRetry message="Failed to load the dashboard." onRetry={() => void stats.reload()} />}
      {s && (
        <>
          <h2>Needs attention</h2>
          <div className="stat-grid">
            <Card
              to="/vendors?status=pending_review"
              label="Vendors awaiting review"
              value={s.vendors["pending_review"] ?? 0}
              warn={(s.vendors["pending_review"] ?? 0) > 0}
              note={s.oldestPending.vendor?.submittedAt ? `oldest waiting ${timeAgo(s.oldestPending.vendor.submittedAt)}` : undefined}
            />
            <Card
              to="/categories/proposals"
              label="Category proposals"
              value={s.proposals["pending"] ?? 0}
              warn={(s.proposals["pending"] ?? 0) > 0}
              note={s.oldestPending.proposal ? `oldest waiting ${timeAgo(s.oldestPending.proposal.submittedAt)}` : undefined}
            />
            <Card
              to="/roadmap?status=failed"
              label="Failed roadmaps (7 days)"
              value={s.roadmaps.failedLastSevenDays}
              warn={s.roadmaps.failedLastSevenDays > 0}
            />
            {s.commerce.overduePayments > 0 && (
              <Card to="/bookings/payments?status=overdue" label="Overdue payments" value={s.commerce.overduePayments} warn />
            )}
            {s.commerce.flaggedReviews > 0 && (
              <Card to="/reviews?status=flagged" label="Flagged reviews" value={s.commerce.flaggedReviews} warn />
            )}
          </div>

          <h2 className="section-gap">Platform</h2>
          <div className="stat-grid">
            <Card to="/vendors?status=published" label="Live vendors" value={s.vendors["published"] ?? 0} />
            <Card to="/families" label="Families" value={s.organizers} />
            <Card to="/events" label="Events" value={s.events} />
            <Card to="/roadmap" label="Roadmaps (7 days)" value={s.roadmaps.lastSevenDays} note={`${s.roadmaps.total} in total`} />
            <Card
              label="AI tokens (30 days)"
              value={(s.roadmaps.tokensLastThirtyDays.input + s.roadmaps.tokensLastThirtyDays.output).toLocaleString("en-IN")}
              note={`${s.roadmaps.tokensLastThirtyDays.input.toLocaleString("en-IN")} in · ${s.roadmaps.tokensLastThirtyDays.output.toLocaleString("en-IN")} out`}
            />
          </div>
        </>
      )}

      {showAudit && (
        <>
          <div className="page-header section-gap">
            <h2>Recent activity</h2>
            <Link to="/audit">View all</Link>
          </div>
          {audit.state === "ready" && audit.data?.entries.length === 0 && <p className="page-status">Nothing yet.</p>}
          <ul className="vendor-list">
            {audit.data?.entries.map((e) => {
              const link = entityLink(e);
              return (
                <li key={e.id} className="card">
                  <strong>{e.action}</strong> <span className="muted">· {e.admin?.name ?? "system"} · {formatDateTime(e.createdAt)}</span>
                  {link && <> · <Link to={link}>open</Link></>}
                </li>
              );
            })}
          </ul>
        </>
      )}
    </div>
  );
}
