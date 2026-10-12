import { useCallback, useEffect, useState } from "react";
import { Link, useParams } from "react-router-dom";
import { api } from "../lib/api.ts";
import { useAuth } from "../lib/auth-context.tsx";
import { errorMessage } from "../lib/format.ts";
import { eventTypeLabel } from "../lib/event-types.ts";
import { useToast } from "../lib/toast.tsx";
import { ConfirmDialog } from "../components/ConfirmDialog.tsx";
import { ErrorRetry } from "../components/ErrorRetry.tsx";
import { EventTypePicker } from "../components/EventTypePicker.tsx";
import { TemplateFields, blankTemplate, templatePayload, templateValid, type TemplateDraft } from "../components/TemplateFields.tsx";
import { usePageTitle } from "../components/usePageTitle.ts";
import { categoryName, type CategoryRow } from "./CategoriesPage.tsx";

interface Template {
  id: string;
  eventType: string;
  taskKey: string;
  defaultNameEn: string;
  defaultLeadTimeDays: number;
  defaultDependencyKeys: string[];
  typicalOwnerType: TemplateDraft["typicalOwnerType"];
  version: number;
}

const toDraft = (t: Template): TemplateDraft => ({
  taskKey: t.taskKey,
  defaultNameEn: t.defaultNameEn,
  defaultLeadTimeDays: String(t.defaultLeadTimeDays),
  typicalOwnerType: t.typicalOwnerType,
  dependencies: t.defaultDependencyKeys.join(", "),
});

export function CategoryDetailPage() {
  const { key } = useParams<{ key: string }>();
  const { can } = useAuth();
  const toast = useToast();
  const canEdit = can("category.manage");
  const [category, setCategory] = useState<CategoryRow | null>(null);
  const [templates, setTemplates] = useState<Template[]>([]);
  const [state, setState] = useState<"loading" | "error" | "notfound" | "ready">("loading");
  const [label, setLabel] = useState("");
  const [types, setTypes] = useState<string[]>([]);
  const [editing, setEditing] = useState<{ id: string | null; draft: TemplateDraft; eventType: string } | null>(null);
  const [deleting, setDeleting] = useState<Template | null>(null);
  const [busy, setBusy] = useState(false);
  usePageTitle(category ? categoryName(category) : "Category");

  const load = useCallback(async () => {
    try {
      const [c, t] = await Promise.all([
        api.get<{ categories: CategoryRow[] }>("/admin/categories"),
        api.get<{ templates: Template[] }>("/admin/task-templates", { params: { category: key } }),
      ]);
      const found = c.data.categories.find((x) => x.categoryKey === key);
      if (!found) return setState("notfound");
      setCategory(found);
      setLabel(found.label ?? "");
      setTypes(found.applicableEventTypes);
      setTemplates(t.data.templates);
      setState("ready");
    } catch {
      setState("error");
    }
  }, [key]);

  useEffect(() => {
    void load();
  }, [load]);

  async function saveCategory() {
    setBusy(true);
    try {
      await api.patch(`/admin/categories/${key}`, { ...(label.trim() ? { label: label.trim() } : {}), applicableEventTypes: types });
      toast.success("Category saved.");
      await load();
    } catch (err) {
      toast.error(errorMessage(err, "Could not save the category."));
    } finally {
      setBusy(false);
    }
  }

  async function saveTemplate() {
    if (!editing) return;
    setBusy(true);
    try {
      const body = templatePayload(editing.draft);
      if (editing.id) {
        await api.patch(`/admin/task-templates/${editing.id}`, body);
      } else await api.post("/admin/task-templates", { ...body, categoryKey: key, eventType: editing.eventType });
      toast.success("Task saved.");
      setEditing(null);
      await load();
    } catch (err) {
      toast.error(errorMessage(err, "Could not save the task."));
    } finally {
      setBusy(false);
    }
  }

  async function removeTemplate() {
    if (!deleting) return;
    setBusy(true);
    try {
      await api.delete(`/admin/task-templates/${deleting.id}`);
      toast.success("Task deleted.");
      setDeleting(null);
      await load();
    } catch (err) {
      toast.error(errorMessage(err, "Could not delete the task."));
      setDeleting(null);
    } finally {
      setBusy(false);
    }
  }

  if (state === "loading") return <div className="page"><p className="page-status">Loading…</p></div>;
  if (state === "notfound") return <div className="page"><p className="page-status">Category not found. <Link to="/categories">Back</Link></p></div>;
  if (state === "error" || !category) return <div className="page"><ErrorRetry message="Failed to load the category." onRetry={() => void load()} /></div>;

  return (
    <div className="page">
      <header className="page-header">
        <Link to="/categories" className="link-button">← Back to categories</Link>
      </header>
      <h1>
        {categoryName(category)} {!category.isActive && <span className="badge badge-danger">Retired</span>}
      </h1>
      <p className="muted">Key: {category.categoryKey}</p>

      <section className="card">
        <h2>Details</h2>
        <div className="form-stack">
          <label>
            Display name
            <input value={label} placeholder={categoryName(category)} disabled={!canEdit} onChange={(e) => setLabel(e.target.value)} />
          </label>
          <EventTypePicker value={types} onChange={canEdit ? setTypes : () => {}} />
          {canEdit && (
            <div>
              <button type="button" disabled={busy || types.length === 0} onClick={() => void saveCategory()}>Save details</button>
            </div>
          )}
        </div>
      </section>

      <section className="card section-gap">
        <div className="page-header">
          <h2>Starter tasks ({templates.length})</h2>
          {canEdit && (
            <button type="button" onClick={() => setEditing({ id: null, draft: blankTemplate(category.categoryKey), eventType: types[0] ?? "wedding" })}>
              Add task
            </button>
          )}
        </div>
        <p className="muted">These feed roadmap generation. Editing a task bumps its version.</p>
        {templates.length === 0 && <p className="page-status">No starter tasks yet.</p>}
        <ul className="vendor-list">
          {templates.map((t) => (
            <li key={t.id} className="card admin-row">
              <div>
                <strong>{t.defaultNameEn}</strong> <span className="badge badge-neutral">{eventTypeLabel(t.eventType)}</span>
                <div className="muted">
                  {t.taskKey} · {t.defaultLeadTimeDays} days before · {t.typicalOwnerType} · v{t.version}
                  {t.defaultDependencyKeys.length > 0 && ` · after ${t.defaultDependencyKeys.join(", ")}`}
                </div>
              </div>
              {canEdit && (
                <div className="review-actions">
                  <button type="button" className="secondary" onClick={() => setEditing({ id: t.id, draft: toDraft(t), eventType: t.eventType })}>Edit</button>
                  <button type="button" className="danger" onClick={() => setDeleting(t)}>Delete</button>
                </div>
              )}
            </li>
          ))}
        </ul>
      </section>

      <ConfirmDialog
        open={editing !== null}
        title={editing?.id ? "Edit starter task" : "Add starter task"}
        confirmLabel="Save task"
        busy={busy}
        confirmDisabled={!editing || !templateValid(editing.draft)}
        onCancel={() => setEditing(null)}
        onConfirm={() => void saveTemplate()}
      >
        {editing && (
          <div className="form-stack">
            {!editing.id && (
              <label>
                Event type
                <select value={editing.eventType} onChange={(e) => setEditing({ ...editing, eventType: e.target.value })}>
                  {types.map((t) => <option key={t} value={t}>{eventTypeLabel(t)}</option>)}
                </select>
              </label>
            )}
            <TemplateFields value={editing.draft} lockKey={false} onChange={(patch) => setEditing({ ...editing, draft: { ...editing.draft, ...patch } })} />
          </div>
        )}
      </ConfirmDialog>

      <ConfirmDialog
        open={deleting !== null}
        title="Delete this starter task?"
        confirmLabel="Delete"
        danger
        busy={busy}
        onCancel={() => setDeleting(null)}
        onConfirm={() => void removeTemplate()}
      >
        <p>{deleting?.defaultNameEn}. Future roadmaps will no longer include it; existing ones are unchanged.</p>
      </ConfirmDialog>
    </div>
  );
}
