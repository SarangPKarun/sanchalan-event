import { Link, NavLink } from "react-router-dom";
import { formatDateTime } from "../lib/format.ts";
import { useApi } from "../lib/useApi.ts";
import { useListParams } from "../lib/useListParams.ts";
import { ErrorRetry } from "../components/ErrorRetry.tsx";
import { Pagination } from "../components/Pagination.tsx";
import { usePageTitle } from "../components/usePageTitle.ts";

export interface RoadmapLogRow {
  id: string;
  status: "success" | "failed";
  error: string | null;
  createdAt: string;
  llmModelUsed: string;
  latencyMs: number | null;
  attempts: number | null;
  inputTokens: number | null;
  outputTokens: number | null;
  eventGroup: { id: string; name: string };
}

export function RoadmapNav() {
  const cls = ({ isActive }: { isActive: boolean }) => (isActive ? "tab tab-active" : "tab");
  return (
    <nav className="tabs" aria-label="Roadmap sections">
      <NavLink to="/roadmap" end className={cls}>Generations</NavLink>
      <NavLink to="/roadmap/feedback" className={cls}>Template feedback</NavLink>
    </nav>
  );
}

export function RoadmapPage() {
  usePageTitle("Roadmap generations");
  const { params, update, page } = useListParams();
  const status = params.get("status") ?? "";
  const { data, state, reload } = useApi<{ logs: RoadmapLogRow[]; total: number; pageSize: number }>("/admin/roadmap-logs", { status, page });

  return (
    <div className="page">
      <header className="page-header">
        <h1>Roadmap</h1>
      </header>
      <RoadmapNav />
      <div className="filters">
        <label>
          <span className="sr-only">Result</span>
          <select value={status} onChange={(e) => update({ status: e.target.value || null })}>
            <option value="">All results</option>
            <option value="success">Succeeded</option>
            <option value="failed">Failed</option>
          </select>
        </label>
      </div>

      {state === "loading" && <p className="page-status">Loading…</p>}
      {state === "error" && <ErrorRetry message="Failed to load generations." onRetry={() => void reload()} />}
      {state === "ready" && data && data.logs.length === 0 && <p className="page-status">No generations yet.</p>}
      <ul className="vendor-list">
        {data?.logs.map((l) => (
          <li key={l.id}>
            <Link to={`/roadmap/${l.id}`} className="vendor-row">
              <div className="vendor-row-info">
                <strong>{l.eventGroup.name}</strong>
                <span>
                  {formatDateTime(l.createdAt)} · {l.llmModelUsed}
                  {l.inputTokens != null ? ` · ${l.inputTokens + (l.outputTokens ?? 0)} tokens` : ""}
                  {l.latencyMs != null ? ` · ${(l.latencyMs / 1000).toFixed(1)}s` : ""}
                  {l.attempts && l.attempts > 1 ? ` · ${l.attempts} attempts` : ""}
                </span>
                {l.error && <span className="error-text">{l.error}</span>}
              </div>
              <span className={`badge ${l.status === "success" ? "badge-success" : "badge-danger"}`}>{l.status === "success" ? "Succeeded" : "Failed"}</span>
            </Link>
          </li>
        ))}
      </ul>
      {data && <Pagination page={page} pageSize={data.pageSize} total={data.total} onChange={(p) => update({ page: p > 1 ? String(p) : null })} />}
    </div>
  );
}
