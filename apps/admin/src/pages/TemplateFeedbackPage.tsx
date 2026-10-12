import { vendorCategoryLabel } from "@sanchalan/shared-types";
import { useApi } from "../lib/useApi.ts";
import { ErrorRetry } from "../components/ErrorRetry.tsx";
import { usePageTitle } from "../components/usePageTitle.ts";
import { RoadmapNav } from "./RoadmapPage.tsx";
import { Link } from "react-router-dom";

interface Stats {
  days: number;
  byAction: Record<string, number>;
  topChanged: { name: string; category: string; edited: number; removed: number; statusChanged: number; total: number }[];
  truncated: boolean;
}

export function TemplateFeedbackPage() {
  usePageTitle("Template feedback");
  const { data, state, reload } = useApi<Stats>("/admin/task-edit-stats");

  return (
    <div className="page">
      <header className="page-header">
        <h1>Roadmap</h1>
      </header>
      <RoadmapNav />
      <p className="muted">
        AI and template tasks that families edit or remove most often in the last {data?.days ?? 90} days. Use this to improve the{" "}
        <Link to="/categories">starter tasks</Link>.
      </p>
      {state === "loading" && <p className="page-status">Loading…</p>}
      {state === "error" && <ErrorRetry message="Failed to load feedback." onRetry={() => void reload()} />}
      {state === "ready" && data && (
        <>
          {data.truncated && <p className="muted">Showing the newest 20,000 edits only.</p>}
          <p>
            {Object.entries(data.byAction).map(([k, v]) => `${k.replace(/_/g, " ")}: ${v}`).join(" · ") || "No edits recorded yet."}
          </p>
          <ul className="vendor-list">
            {data.topChanged.map((t) => (
              <li key={`${t.category}-${t.name}`} className="card admin-row">
                <div>
                  <strong>{t.name}</strong>
                  <div className="muted">{vendorCategoryLabel(t.category)}</div>
                </div>
                <span>
                  {t.edited} edited · {t.removed} removed
                </span>
              </li>
            ))}
          </ul>
        </>
      )}
    </div>
  );
}
