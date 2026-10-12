import { useCallback, useEffect, useState } from "react";
import { Link, useSearchParams } from "react-router-dom";
import { vendorCategoryLabel } from "@sanchalan/shared-types";
import { api } from "../lib/api.ts";
import { useAuth } from "../lib/auth-context.tsx";
import { errorMessage as apiError, formatDate } from "../lib/format.ts";
import { useToast } from "../lib/toast.tsx";
import { Tabs } from "../components/Tabs.tsx";
import { ErrorRetry } from "../components/ErrorRetry.tsx";
import { StatusBadge } from "../components/StatusBadge.tsx";
import { usePageTitle } from "../components/usePageTitle.ts";

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

interface Category {
  id: string;
  categoryKey: string;
  label: string | null;
}

interface TemplateDraft {
  taskKey: string;
  defaultNameEn: string;
  defaultLeadTimeDays: string;
}

const TABS: { label: string; value: Status }[] = [
  { label: "Pending", value: "pending" },
  { label: "Approved", value: "approved" },
  { label: "Merged", value: "merged" },
  { label: "Rejected", value: "rejected" },
];

function blankTemplate(key: string): TemplateDraft {
  return { taskKey: `book_${key}`, defaultNameEn: "", defaultLeadTimeDays: "60" };
}

function ProposalCard({
  proposal,
  categories,
  onDone,
}: {
  proposal: Proposal;
  categories: Category[];
  onDone: () => void;
}) {
  const { can } = useAuth();
  const toast = useToast();
  const canReview = can("category.review");
  const [mode, setMode] = useState<"approve" | "reject" | "merge" | null>(null);
  const [label, setLabel] = useState(proposal.label);
  const [templates, setTemplates] = useState<TemplateDraft[]>([blankTemplate(proposal.categoryKey)]);
  const [reason, setReason] = useState("");
  const [mergeId, setMergeId] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function run(path: string, body: object) {
    setBusy(true);
    setError(null);
    try {
      await api.post(`/admin/category-proposals/${proposal.id}/${path}`, body);
      toast.success(`Proposal ${path === "approve" ? "approved" : path === "merge" ? "merged" : "rejected"}.`);
      onDone();
    } catch (err) {
      setError(apiError(err, `Failed to ${path}.`));
    } finally {
      setBusy(false);
    }
  }

  const templatesValid = templates.every(
    (t) =>
      /^[a-z0-9_]+$/.test(t.taskKey) &&
      t.defaultNameEn.trim() &&
      Number.isInteger(Number(t.defaultLeadTimeDays)) &&
      Number(t.defaultLeadTimeDays) >= 0
  );

  function updateTemplate(i: number, patch: Partial<TemplateDraft>) {
    setTemplates((ts) => ts.map((t, j) => (j === i ? { ...t, ...patch } : t)));
  }

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
          {proposal.resolvedCategory.label ?? vendorCategoryLabel(proposal.resolvedCategory.categoryKey)}
        </p>
      )}

      {proposal.status === "pending" && mode === null && canReview && (
        <div className="review-actions">
          <button onClick={() => setMode("approve")}>Approve…</button>
          <button onClick={() => setMode("merge")}>Merge into existing…</button>
          <button className="danger" onClick={() => setMode("reject")}>
            Reject…
          </button>
        </div>
      )}

      {mode === "approve" && (
        <div className="reject-form">
          <label>
            Category name
            <input value={label} onChange={(e) => setLabel(e.target.value)} />
          </label>
          <p>Starter tasks for the roadmap (at least one):</p>
          {templates.map((t, i) => (
            <div key={i} className="review-actions">
              <label>
                Task key
              <input
                placeholder="task_key"
                value={t.taskKey}
                onChange={(e) => updateTemplate(i, { taskKey: e.target.value })}
              />
              </label>
              <label>
                Task name
              <input
                placeholder="Task name"
                value={t.defaultNameEn}
                onChange={(e) => updateTemplate(i, { defaultNameEn: e.target.value })}
              />
              </label>
              <label>
                Lead time (days)
              <input
                type="number"
                min={0}
                title="Lead time (days before event)"
                value={t.defaultLeadTimeDays}
                onChange={(e) => updateTemplate(i, { defaultLeadTimeDays: e.target.value })}
              />
              </label>
              {templates.length > 1 && (
                <button type="button" className="secondary" onClick={() => setTemplates((ts) => ts.filter((_, j) => j !== i))}>Remove</button>
              )}
            </div>
          ))}
          <div className="review-actions">
            <button
              onClick={() =>
                setTemplates((ts) => [...ts, blankTemplate(`${proposal.categoryKey}_${ts.length + 1}`)])
              }
            >
              Add task
            </button>
            <button
              disabled={busy || label.trim().length < 3 || !templatesValid}
              onClick={() =>
                run("approve", {
                  label: label.trim(),
                  applicableEventTypes: ["wedding"],
                  templates: templates.map((t) => ({
                    taskKey: t.taskKey,
                    defaultNameEn: t.defaultNameEn.trim(),
                    defaultLeadTimeDays: Number(t.defaultLeadTimeDays),
                  })),
                })
              }
            >
              Confirm approve
            </button>
            <button type="button" className="secondary" onClick={() => setMode(null)}>Cancel</button>
          </div>
        </div>
      )}

      {mode === "merge" && (
        <div className="reject-form">
          <label>
            Existing category
            <select value={mergeId} onChange={(e) => setMergeId(e.target.value)}>
              <option value="">Select…</option>
              {categories.map((c) => (
                <option key={c.id} value={c.id}>
                  {c.label ?? vendorCategoryLabel(c.categoryKey)}
                </option>
              ))}
            </select>
          </label>
          <div className="review-actions">
            <button disabled={busy || !mergeId} onClick={() => run("merge", { vendorCategoryId: mergeId })}>
              Confirm merge
            </button>
            <button type="button" className="secondary" onClick={() => setMode(null)}>Cancel</button>
          </div>
        </div>
      )}

      {mode === "reject" && (
        <div className="reject-form">
          <label>
            Reason for rejection
            <textarea value={reason} onChange={(e) => setReason(e.target.value)} rows={3} />
          </label>
          <div className="review-actions">
            <button
              className="danger"
              disabled={busy || !reason.trim()}
              onClick={() => run("reject", { reason: reason.trim() })}
            >
              Confirm reject
            </button>
            <button type="button" className="secondary" onClick={() => setMode(null)}>Cancel</button>
          </div>
        </div>
      )}

      {error && <p className="error-text">{error}</p>}
    </li>
  );
}

export function CategoryProposalsPage() {
  usePageTitle("Categories");
  const [params, setParams] = useSearchParams();
  const requested = params.get("status") as Status | null;
  const tab: Status = TABS.some((t) => t.value === requested) ? requested! : "pending";
  const [proposals, setProposals] = useState<Proposal[]>([]);
  const [categories, setCategories] = useState<Category[]>([]);
  const [state, setState] = useState<"loading" | "error" | "ready">("loading");

  const load = useCallback(async (silent = false) => {
    if (!silent) setState("loading");
    try {
      const [p, c] = await Promise.all([
        api.get<{ proposals: Proposal[] }>("/admin/category-proposals", { params: { status: tab } }),
        api.get<{ categories: Category[] }>("/admin/vendor-categories"),
      ]);
      setProposals(p.data.proposals);
      setCategories(c.data.categories);
      setState("ready");
    } catch {
      setState("error");
    }
  }, [tab]);

  useEffect(() => {
    void load();
  }, [load]);

  return (
    <div className="page">
      <header className="page-header">
        <h1>Category proposals</h1>
      </header>

      <Tabs label="Proposal status" tabs={TABS} value={tab} onChange={(v) => setParams({ status: v }, { replace: true })} />

      {state === "loading" && <p className="page-status">Loading…</p>}
      {state === "error" && <ErrorRetry message="Failed to load proposals." onRetry={() => void load()} />}
      {state === "ready" && proposals.length === 0 && <p className="page-status">Nothing here.</p>}

      <ul className="vendor-list">
        {proposals.map((p) => (
          <ProposalCard key={p.id} proposal={p} categories={categories} onDone={() => void load(true)} />
        ))}
      </ul>
    </div>
  );
}
