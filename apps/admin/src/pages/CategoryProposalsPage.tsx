import { useCallback, useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { vendorCategoryLabel } from "@sanchalan/shared-types";
import { api } from "../lib/api.ts";

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

function errorMessage(err: unknown, fallback: string): string {
  return (err as { response?: { data?: { error?: string } } })?.response?.data?.error ?? fallback;
}

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
      onDone();
    } catch (err) {
      setError(errorMessage(err, `Failed to ${path}.`));
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
      <strong>{proposal.label}</strong> <small>({proposal.categoryKey})</small>
      {proposal.description && <p>{proposal.description}</p>}
      <p>
        Requested by:{" "}
        {proposal.vendors.map((v) => v.vendor.businessName ?? v.vendor.phoneNumber).join(", ")}
      </p>
      {proposal.status === "rejected" && <p>Rejected: {proposal.rejectionReason}</p>}
      {proposal.resolvedCategory && (
        <p>
          → {proposal.status === "merged" ? "merged into" : "created"}{" "}
          {proposal.resolvedCategory.label ?? vendorCategoryLabel(proposal.resolvedCategory.categoryKey)}
        </p>
      )}

      {proposal.status === "pending" && mode === null && (
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
              <input
                placeholder="task_key"
                value={t.taskKey}
                onChange={(e) => updateTemplate(i, { taskKey: e.target.value })}
              />
              <input
                placeholder="Task name"
                value={t.defaultNameEn}
                onChange={(e) => updateTemplate(i, { defaultNameEn: e.target.value })}
              />
              <input
                type="number"
                min={0}
                title="Lead time (days before event)"
                value={t.defaultLeadTimeDays}
                onChange={(e) => updateTemplate(i, { defaultLeadTimeDays: e.target.value })}
              />
              {templates.length > 1 && (
                <button onClick={() => setTemplates((ts) => ts.filter((_, j) => j !== i))}>Remove</button>
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
            <button onClick={() => setMode(null)}>Cancel</button>
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
            <button onClick={() => setMode(null)}>Cancel</button>
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
            <button onClick={() => setMode(null)}>Cancel</button>
          </div>
        </div>
      )}

      {error && <p className="error-text">{error}</p>}
    </li>
  );
}

export function CategoryProposalsPage() {
  const [tab, setTab] = useState<Status>("pending");
  const [proposals, setProposals] = useState<Proposal[]>([]);
  const [categories, setCategories] = useState<Category[]>([]);
  const [state, setState] = useState<"loading" | "error" | "ready">("loading");

  const load = useCallback(async () => {
    setState("loading");
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
    load();
  }, [load]);

  return (
    <div className="page">
      <header className="page-header">
        <h1>Category proposals</h1>
        <Link to="/vendors">Vendor queue</Link>
      </header>

      <div className="tabs">
        {TABS.map((t) => (
          <button
            key={t.value}
            className={t.value === tab ? "tab tab-active" : "tab"}
            onClick={() => setTab(t.value)}
          >
            {t.label}
          </button>
        ))}
      </div>

      {state === "loading" && <p className="page-status">Loading…</p>}
      {state === "error" && <p className="page-status error-text">Failed to load proposals.</p>}
      {state === "ready" && proposals.length === 0 && <p className="page-status">Nothing here.</p>}

      <ul className="vendor-list">
        {proposals.map((p) => (
          <ProposalCard key={p.id} proposal={p} categories={categories} onDone={load} />
        ))}
      </ul>
    </div>
  );
}
