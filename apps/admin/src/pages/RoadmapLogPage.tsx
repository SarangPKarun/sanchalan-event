import { Link, useParams } from "react-router-dom";
import { formatDateTime } from "../lib/format.ts";
import { useApi } from "../lib/useApi.ts";
import { ErrorRetry } from "../components/ErrorRetry.tsx";
import { usePageTitle } from "../components/usePageTitle.ts";

interface Detail {
  id: string;
  status: "success" | "failed";
  error: string | null;
  createdAt: string;
  llmModelUsed: string;
  latencyMs: number | null;
  attempts: number | null;
  inputTokens: number | null;
  outputTokens: number | null;
  inputParams: Record<string, unknown>;
  rawOutput: unknown;
  templates: { id: string; taskKey: string; defaultNameEn: string }[];
  eventGroup: { id: string; name: string };
}

export function RoadmapLogPage() {
  usePageTitle("Generation");
  const { id } = useParams<{ id: string }>();
  const { data, state, reload } = useApi<Detail>(`/admin/roadmap-logs/${id}`);

  if (state === "loading") return <div className="page"><p className="page-status">Loading…</p></div>;
  if (state === "notfound") return <div className="page"><p className="page-status">Not found. <Link to="/roadmap">Back</Link></p></div>;
  if (state === "error" || !data) return <div className="page"><ErrorRetry message="Failed to load this generation." onRetry={() => void reload()} /></div>;

  return (
    <div className="page">
      <header className="page-header">
        <Link to="/roadmap" className="link-button">← Back to generations</Link>
      </header>
      <div className="card">
        <h1>
          <Link to={`/events/${data.eventGroup.id}`}>{data.eventGroup.name}</Link>{" "}
          <span className={`badge ${data.status === "success" ? "badge-success" : "badge-danger"}`}>{data.status === "success" ? "Succeeded" : "Failed"}</span>
        </h1>
        <dl className="vendor-details">
          <dt>When</dt>
          <dd>{formatDateTime(data.createdAt)}</dd>
          <dt>Model</dt>
          <dd>{data.llmModelUsed}</dd>
          <dt>Tokens</dt>
          <dd>{data.inputTokens != null ? `${data.inputTokens} in · ${data.outputTokens ?? 0} out` : "not recorded"}</dd>
          <dt>Time</dt>
          <dd>{data.latencyMs != null ? `${(data.latencyMs / 1000).toFixed(1)}s over ${data.attempts ?? 1} attempt(s)` : "not recorded"}</dd>
          {data.error && (
            <>
              <dt>Error</dt>
              <dd className="error-text">{data.error}</dd>
            </>
          )}
        </dl>
        <h2>Input</h2>
        <pre className="code">{JSON.stringify(data.inputParams, null, 2)}</pre>
        <h2>Templates used ({data.templates.length})</h2>
        <p className="muted">{data.templates.map((t) => t.taskKey).join(", ") || "None"}</p>
        <h2>Model output</h2>
        <pre className="code">{JSON.stringify(data.rawOutput, null, 2)}</pre>
      </div>
    </div>
  );
}
