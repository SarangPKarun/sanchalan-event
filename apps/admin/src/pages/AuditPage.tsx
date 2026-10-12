import { useState } from "react";
import { Link } from "react-router-dom";
import { api } from "../lib/api.ts";
import { formatDateTime } from "../lib/format.ts";
import { useApi } from "../lib/useApi.ts";
import { useListParams } from "../lib/useListParams.ts";
import { useToast } from "../lib/toast.tsx";
import { ErrorRetry } from "../components/ErrorRetry.tsx";
import { Pagination } from "../components/Pagination.tsx";
import { SearchBox } from "../components/SearchBox.tsx";
import { usePageTitle } from "../components/usePageTitle.ts";

export interface AuditEntry {
  id: string;
  action: string;
  entityType: string | null;
  entityId: string | null;
  metadata: Record<string, unknown> | null;
  ip: string | null;
  createdAt: string;
  admin: { id: string; name: string } | null;
}

const ENTITY_LINKS: Record<string, string> = { vendor: "/vendors/", organizer: "/families/", category_proposal: "/categories/proposals", category: "/categories/" };

export function entityLink(e: Pick<AuditEntry, "entityType" | "entityId">): string | null {
  const base = e.entityType ? ENTITY_LINKS[e.entityType] : undefined;
  if (!base || !e.entityId) return null;
  return base.endsWith("/") ? `${base}${e.entityId}` : base;
}

const ENTITY_TYPES = ["vendor", "organizer", "category", "category_proposal", "task_template", "admin"];

export function AuditPage() {
  usePageTitle("Audit log");
  const toast = useToast();
  const { params, update, page } = useListParams();
  const action = params.get("action") ?? "";
  const entityType = params.get("entityType") ?? "";
  const from = params.get("from") ?? "";
  const to = params.get("to") ?? "";
  const query = { action, entityType, from, to: to ? `${to}T23:59:59` : "", page };
  const { data, state, reload } = useApi<{ entries: AuditEntry[]; total: number; pageSize: number }>("/admin/audit-logs", query);
  const [exporting, setExporting] = useState(false);

  async function exportCsv() {
    setExporting(true);
    try {
      const { data: csv } = await api.get<Blob>("/admin/audit-logs.csv", { params: { action, entityType, from, to: query.to }, responseType: "blob" });
      const url = URL.createObjectURL(csv);
      const a = document.createElement("a");
      a.href = url;
      a.download = "audit-log.csv";
      a.click();
      URL.revokeObjectURL(url);
    } catch {
      toast.error("Could not export the audit log.");
    } finally {
      setExporting(false);
    }
  }

  return (
    <div className="page">
      <header className="page-header">
        <h1>Audit log</h1>
        <button type="button" className="secondary" disabled={exporting} onClick={() => void exportCsv()}>
          {exporting ? "Exporting…" : "Export CSV"}
        </button>
      </header>
      <div className="filters">
        <SearchBox value={action} onSearch={(v) => update({ action: v || null })} label="Filter by action" placeholder="Action, e.g. vendor.approved" />
        <label>
          <span className="sr-only">Entity</span>
          <select value={entityType} onChange={(e) => update({ entityType: e.target.value || null })}>
            <option value="">Any entity</option>
            {ENTITY_TYPES.map((t) => <option key={t} value={t}>{t.replace(/_/g, " ")}</option>)}
          </select>
        </label>
        <label>
          From
          <input type="date" value={from} onChange={(e) => update({ from: e.target.value || null })} />
        </label>
        <label>
          To
          <input type="date" value={to} onChange={(e) => update({ to: e.target.value || null })} />
        </label>
      </div>

      {state === "loading" && <p className="page-status">Loading…</p>}
      {state === "error" && <ErrorRetry message="Failed to load the audit log." onRetry={() => void reload()} />}
      {state === "ready" && data && data.entries.length === 0 && <p className="page-status">No entries match.</p>}
      <ul className="vendor-list">
        {data?.entries.map((e) => {
          const link = entityLink(e);
          return (
            <li key={e.id} className="card">
              <strong>{e.action}</strong> <span className="muted">· {e.admin?.name ?? "system"} · {formatDateTime(e.createdAt)}{e.ip ? ` · ${e.ip}` : ""}</span>
              {link && <> · <Link to={link}>open</Link></>}
              {e.metadata && <div className="muted">{JSON.stringify(e.metadata)}</div>}
            </li>
          );
        })}
      </ul>
      {data && <Pagination page={page} pageSize={data.pageSize} total={data.total} onChange={(p) => update({ page: p > 1 ? String(p) : null })} />}
    </div>
  );
}
