import { useCallback, useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { vendorCategoryLabel } from "@sanchalan/shared-types";
import { api } from "../lib/api.ts";
import { useAuth } from "../lib/auth-context.tsx";
import { errorMessage } from "../lib/format.ts";
import { eventTypeLabel } from "../lib/event-types.ts";
import { useToast } from "../lib/toast.tsx";
import { CategoriesNav } from "../components/CategoriesNav.tsx";
import { ErrorRetry } from "../components/ErrorRetry.tsx";
import { usePageTitle } from "../components/usePageTitle.ts";

export interface CategoryRow {
  categoryKey: string;
  vendorCategoryId: string | null;
  label: string | null;
  isActive: boolean;
  applicableEventTypes: string[];
  vendorCount: number | null;
  templateCount: number | null;
}

export const categoryName = (c: { categoryKey: string; label: string | null }) => c.label ?? vendorCategoryLabel(c.categoryKey);

export function CategoriesPage() {
  usePageTitle("Categories");
  const { can } = useAuth();
  const toast = useToast();
  const [rows, setRows] = useState<CategoryRow[]>([]);
  const [pending, setPending] = useState<number | undefined>();
  const [state, setState] = useState<"loading" | "error" | "ready">("loading");

  const load = useCallback(async () => {
    try {
      const [c, s] = await Promise.all([
        api.get<{ categories: CategoryRow[] }>("/admin/categories"),
        api.get<{ proposals: { pending: number } }>("/admin/stats"),
      ]);
      setRows(c.data.categories);
      setPending(s.data.proposals.pending);
      setState("ready");
    } catch {
      setState("error");
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  async function toggle(c: CategoryRow) {
    try {
      await api.patch(`/admin/categories/${c.categoryKey}`, { isActive: !c.isActive });
      toast.success(c.isActive ? "Category retired." : "Category restored.");
      await load();
    } catch (err) {
      toast.error(errorMessage(err, "Could not update the category."));
    }
  }

  return (
    <div className="page">
      <header className="page-header">
        <h1>Categories</h1>
      </header>
      <CategoriesNav pending={pending} />

      {state === "loading" && <p className="page-status">Loading…</p>}
      {state === "error" && <ErrorRetry message="Failed to load categories." onRetry={() => void load()} />}
      {state === "ready" && (
        <ul className="vendor-list">
          {rows.map((c) => (
            <li key={c.categoryKey} className="card admin-row">
              <div>
                <Link to={`/categories/${c.categoryKey}`}>
                  <strong>{categoryName(c)}</strong>
                </Link>{" "}
                {!c.isActive && <span className="badge badge-danger">Retired</span>}
                <div className="muted">
                  {c.vendorCount === null ? "Not a vendor category" : `${c.vendorCount} vendor${c.vendorCount === 1 ? "" : "s"}`}
                  {" · "}
                  {c.templateCount === null ? "No roadmap tasks" : `${c.templateCount} starter task${c.templateCount === 1 ? "" : "s"}`}
                  {" · "}
                  {c.applicableEventTypes.map(eventTypeLabel).join(", ")}
                </div>
              </div>
              {can("category.manage") && (
                <button type="button" className={c.isActive ? "secondary" : undefined} onClick={() => void toggle(c)}>
                  {c.isActive ? "Retire" : "Restore"}
                </button>
              )}
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
