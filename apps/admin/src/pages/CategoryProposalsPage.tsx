import { useCallback, useEffect, useState } from "react";
import { Link, useSearchParams } from "react-router-dom";
import { api } from "../lib/api.ts";
import { useAuth } from "../lib/auth-context.tsx";
import { errorMessage, formatDate } from "../lib/format.ts";
import { useToast } from "../lib/toast.tsx";
import { CategoriesNav } from "../components/CategoriesNav.tsx";
import { ErrorRetry } from "../components/ErrorRetry.tsx";
import { EventTypePicker } from "../components/EventTypePicker.tsx";
import { Pagination } from "../components/Pagination.tsx";
import { SearchBox } from "../components/SearchBox.tsx";
import { StatusBadge } from "../components/StatusBadge.tsx";
import { Tabs } from "../components/Tabs.tsx";
import { TemplateFields, blankTemplate, templatePayload, templateValid, type TemplateDraft } from "../components/TemplateFields.tsx";
import { usePageTitle } from "../components/usePageTitle.ts";
import { categoryName, type CategoryRow } from "./CategoriesPage.tsx";

type Status = "pending" | "approved" | "rejected" | "merged";

interface Proposal {
  id: string;
  label: string;
  categoryKey: string;
  description: string | null;
  status: Status;
  rejectionReason: string | null;
  submittedAt: string;
  vendors: { vendor: { id: string; businessName: string | null; phoneNumber: string } }[];
  resolvedCategory: { categoryKey: string; label: string | null } | null;
}

const TABS: { label: string; value: Status }[] = [
  { label: "Pending", value: "pending" },
  { label: "Approved", value: "approved" },
  { label: "Merged", value: "merged" },
  { label: "Rejected", value: "rejected" },
];

function ProposalCard({ proposal, categories, onDone }: { proposal: Proposal; categories: CategoryRow[]; onDone: () => void }) {
  const { can } = useAuth();
  const toast = useToast();
  const canReview = can("category.review");
  const [mode, setMode] = useState<"approve" | "reject" | "merge" | null>(null);
  const [label, setLabel] = useState(proposal.label);
  const [types, setTypes] = useState<string[]>(["wedding"]);
  const [templates, setTemplates] = useState<TemplateDraft[]>([blankTemplate(proposal.categoryKey)]);
  const [reason, setReason] = useState("");
  const [mergeKey, setMergeKey] = useState("");
  const [busy, setBusy] = useState(false);
  const [drafting, setDrafting] = useState(false);

  async function run(path: string, body: object) {
    setBusy(true);
    try {
      await api.post(`/admin/category-proposals/${proposal.id}/${path}`, body);
      toast.success(`Proposal ${path === "approve" ? "approved" : path === "merge" ? "merged" : "rejected"}.`);
      onDone();
    } catch (err) {
      toast.error(errorMessage(err, `Failed to ${path}.`));
    } finally {
      setBusy(false);
    }
  }

  async function draft() {
    setDrafting(true);
    try {
      const { data } = await api.post<{ templates: { taskKey: string; defaultNameEn: string; defaultLeadTimeDays: number; typicalOwnerType: TemplateDraft["typicalOwnerType"] }[] }>(
        `/admin/category-proposals/${proposal.id}/draft-templates`
      );
      setTemplates(data.templates.map((t) => ({ ...t, defaultLeadTimeDays: String(t.defaultLeadTimeDays), dependencies: "" })));
      toast.success("Draft ready. Review and edit before approving.");
    } catch (err) {
      toast.error(errorMessage(err, "The AI draft failed."));
    } finally {
      setDrafting(false);
    }
  }

  const update = (i: number, patch: Partial<TemplateDraft>) => setTemplates((ts) => ts.map((t, j) => (j === i ? { ...t, ...patch } : t)));
  const mergeTarget = categories.find((c) => c.categoryKey === mergeKey);
  const approvable = label.trim().length >= 3 && types.length > 0 && templates.every(templateValid);

  return (
    <li className="card">
      <strong>{proposal.label}</strong> <small>({proposal.categoryKey})</small> <StatusBadge status={proposal.status} />
      <p className="muted">Submitted {formatDate(proposal.submittedAt)}</p>
      {proposal.description && <p>{proposal.description}</p>}
      <p>
        Requested by:{" "}
        {proposal.vendors.map((v, i) => (
          <span key={v.vendor.id}>
            {i > 0 && ", "}
            <Link to={`/vendors/${v.vendor.id}`}>{v.vendor.businessName ?? v.vendor.phoneNumber}</Link>
          </span>
        ))}
      </p>
      {proposal.status === "rejected" && <p>Rejected: {proposal.rejectionReason}</p>}
      {proposal.resolvedCategory && (
        <p>
          → {proposal.status === "merged" ? "merged into" : "created"}{" "}
          <Link to={`/categories/${proposal.resolvedCategory.categoryKey}`}>{categoryName(proposal.resolvedCategory)}</Link>
        </p>
      )}

      {proposal.status === "pending" && mode === null && canReview && (
        <div className="review-actions">
          <button type="button" onClick={() => setMode("approve")}>Approve…</button>
          <button type="button" className="secondary" onClick={() => setMode("merge")}>Merge into existing…</button>
          <button type="button" className="danger" onClick={() => setMode("reject")}>Reject…</button>
        </div>
      )}

      {mode === "approve" && (
        <div className="reject-form">
          <label>
            Category name
            <input value={label} onChange={(e) => setLabel(e.target.value)} maxLength={40} />
          </label>
          <EventTypePicker value={types} onChange={setTypes} />
          <div className="page-header">
            <strong>Starter tasks for the roadmap</strong>
            <button type="button" className="secondary" disabled={drafting} onClick={() => void draft()}>
              {drafting ? "Drafting…" : "Draft with AI"}
            </button>
          </div>
          {templates.map((t, i) => (
            <div key={i} className="card">
              <TemplateFields value={t} onChange={(patch) => update(i, patch)} />
              {templates.length > 1 && (
                <button type="button" className="secondary" onClick={() => setTemplates((ts) => ts.filter((_, j) => j !== i))}>
                  Remove task
                </button>
              )}
            </div>
          ))}
          <div className="review-actions">
            <button type="button" className="secondary" onClick={() => setTemplates((ts) => [...ts, blankTemplate(`${proposal.categoryKey}_${ts.length + 1}`)])}>
              Add task
            </button>
            <button
              type="button"
              disabled={busy || !approvable}
              onClick={() => void run("approve", { label: label.trim(), applicableEventTypes: types, templates: templates.map(templatePayload) })}
            >
              Confirm approve
            </button>
            <button type="button" className="secondary" onClick={() => setMode(null)}>Cancel</button>
          </div>
          <p className="muted">
            Approving creates a global category for every vendor and family, and assigns it to {proposal.vendors.length} requesting vendor
            {proposal.vendors.length === 1 ? "" : "s"}.
          </p>
        </div>
      )}

      {mode === "merge" && (
        <div className="reject-form">
          <label>
            Existing category
            <select value={mergeKey} onChange={(e) => setMergeKey(e.target.value)}>
              <option value="">Select…</option>
              {categories.filter((c) => c.vendorCategoryId && c.isActive).map((c) => (
                <option key={c.categoryKey} value={c.categoryKey}>{categoryName(c)}</option>
              ))}
            </select>
          </label>
          {mergeTarget && (
            <p className="muted">
              {proposal.vendors.length} vendor{proposal.vendors.length === 1 ? "" : "s"} will be added to “{categoryName(mergeTarget)}”, which has{" "}
              {mergeTarget.vendorCount} vendor{mergeTarget.vendorCount === 1 ? "" : "s"} now. No new category is created.
            </p>
          )}
          <div className="review-actions">
            <button
              type="button"
              disabled={busy || !mergeTarget}
              onClick={() => void run("merge", { vendorCategoryId: mergeTarget!.vendorCategoryId })}
            >
              Confirm merge
            </button>
            <button type="button" className="secondary" onClick={() => setMode(null)}>Cancel</button>
          </div>
        </div>
      )}

      {mode === "reject" && (
        <div className="reject-form">
          <label>
            Reason for rejection (shown to the vendor)
            <textarea value={reason} onChange={(e) => setReason(e.target.value)} rows={3} maxLength={1000} />
          </label>
          <div className="review-actions">
            <button type="button" className="danger" disabled={busy || !reason.trim()} onClick={() => void run("reject", { reason: reason.trim() })}>
              Confirm reject
            </button>
            <button type="button" className="secondary" onClick={() => setMode(null)}>Cancel</button>
          </div>
        </div>
      )}
    </li>
  );
}

export function CategoryProposalsPage() {
  usePageTitle("Category proposals");
  const [params, setParams] = useSearchParams();
  const requested = params.get("status") as Status | null;
  const tab: Status = TABS.some((t) => t.value === requested) ? requested! : "pending";
  const q = params.get("q") ?? "";
  const page = Math.max(1, Number(params.get("page")) || 1);

  const [proposals, setProposals] = useState<Proposal[]>([]);
  const [total, setTotal] = useState(0);
  const [pageSize, setPageSize] = useState(20);
  const [categories, setCategories] = useState<CategoryRow[]>([]);
  const [counts, setCounts] = useState<Record<string, number> | null>(null);
  const [state, setState] = useState<"loading" | "error" | "ready">("loading");

  const update = useCallback(
    (patch: Record<string, string | null>) =>
      setParams(
        (prev) => {
          const next = new URLSearchParams(prev);
          for (const [k, v] of Object.entries(patch)) (v ? next.set(k, v) : next.delete(k));
          if (!("page" in patch)) next.delete("page");
          return next;
        },
        { replace: true }
      ),
    [setParams]
  );
  const onSearch = useCallback((v: string) => update({ q: v || null }), [update]);

  const load = useCallback(
    async (silent = false) => {
      if (!silent) setState("loading");
      try {
        const [p, c, s] = await Promise.all([
          api.get<{ proposals: Proposal[]; total: number; pageSize: number }>("/admin/category-proposals", { params: { status: tab, q, page } }),
          api.get<{ categories: CategoryRow[] }>("/admin/categories"),
          api.get<{ proposals: Record<string, number> }>("/admin/stats"),
        ]);
        setProposals(p.data.proposals);
        setTotal(p.data.total);
        setPageSize(p.data.pageSize);
        setCategories(c.data.categories);
        setCounts(s.data.proposals);
        setState("ready");
      } catch {
        setState("error");
      }
    },
    [tab, q, page]
  );

  useEffect(() => {
    void load();
  }, [load]);

  return (
    <div className="page">
      <header className="page-header">
        <h1>Categories</h1>
      </header>
      <CategoriesNav pending={counts?.["pending"]} />

      <Tabs
        label="Proposal status"
        tabs={TABS.map((t) => ({ ...t, count: counts?.[t.value] }))}
        value={tab}
        onChange={(v) => update({ status: v })}
      />
      <div className="filters">
        <SearchBox value={q} onSearch={onSearch} label="Search proposals" placeholder="Search proposals" />
      </div>

      {state === "loading" && <p className="page-status">Loading…</p>}
      {state === "error" && <ErrorRetry message="Failed to load proposals." onRetry={() => void load()} />}
      {state === "ready" && proposals.length === 0 && <p className="page-status">Nothing here.</p>}

      <ul className="vendor-list">
        {proposals.map((p) => (
          <ProposalCard key={p.id} proposal={p} categories={categories} onDone={() => void load(true)} />
        ))}
      </ul>
      <Pagination page={page} pageSize={pageSize} total={total} onChange={(n) => update({ page: n > 1 ? String(n) : null })} />
    </div>
  );
}
