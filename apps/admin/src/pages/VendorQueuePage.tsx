import { useCallback, useEffect, useState } from "react";
import { Link, useSearchParams } from "react-router-dom";
import { vendorCategoryLabel } from "@sanchalan/shared-types";
import type { VendorStatus } from "@sanchalan/shared-types";
import { useVendors } from "../lib/vendor-context.tsx";
import { api } from "../lib/api.ts";
import { useAuth } from "../lib/auth-context.tsx";
import { errorMessage, formatDate, tierLabel } from "../lib/format.ts";
import { useToast } from "../lib/toast.tsx";
import { Tabs, type TabItem } from "../components/Tabs.tsx";
import { StatusBadge } from "../components/StatusBadge.tsx";
import { ErrorRetry } from "../components/ErrorRetry.tsx";
import { ConfirmDialog } from "../components/ConfirmDialog.tsx";
import { Pagination } from "../components/Pagination.tsx";
import { SearchBox } from "../components/SearchBox.tsx";
import { usePageTitle } from "../components/usePageTitle.ts";

const TABS: { label: string; value: VendorStatus }[] = [
  { label: "Pending review", value: "pending_review" },
  { label: "Published", value: "published" },
  { label: "Rejected", value: "rejected" },
  { label: "Suspended", value: "suspended" },
  { label: "Drafts", value: "draft" },
];
const TIERS = ["essential", "standard", "premium", "luxury"];

interface Category {
  categoryKey: string;
  label: string | null;
}

export function VendorQueuePage() {
  usePageTitle("Vendors");
  const { vendors, total, pageSize, status, fetchVendors } = useVendors();
  const { can } = useAuth();
  const toast = useToast();
  const [params, setParams] = useSearchParams();
  const requested = params.get("status") as VendorStatus | null;
  const activeTab: VendorStatus = TABS.some((t) => t.value === requested) ? requested! : "pending_review";
  const q = params.get("q") ?? "";
  const category = params.get("category") ?? "";
  const priceTier = params.get("priceTier") ?? "";
  const sort = params.get("sort") ?? "";
  const page = Math.max(1, Number(params.get("page")) || 1);

  const [counts, setCounts] = useState<Record<string, number> | null>(null);
  const [categories, setCategories] = useState<Category[]>([]);
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [bulk, setBulk] = useState<"approve" | "reject" | null>(null);
  const [reason, setReason] = useState("");
  const [busy, setBusy] = useState(false);

  const update = useCallback(
    (patch: Record<string, string | null>) =>
      setParams(
        (prev) => {
          const next = new URLSearchParams(prev);
          for (const [k, v] of Object.entries(patch)) {
            if (v) next.set(k, v);
            else next.delete(k);
          }
          if (!("page" in patch)) next.delete("page");
          return next;
        },
        { replace: true }
      ),
    [setParams]
  );
  const onSearch = useCallback((v: string) => update({ q: v || null }), [update]);

  const query = { status: activeTab, q, category, priceTier, sort, page };
  const refreshCounts = useCallback(async () => {
    try {
      setCounts((await api.get<{ vendors: Record<string, number> }>("/admin/stats")).data.vendors);
    } catch {
      /* counts are a nicety */
    }
  }, []);

  useEffect(() => {
    void fetchVendors({ status: activeTab, q, category, priceTier, sort, page });
    setSelected(new Set());
  }, [activeTab, q, category, priceTier, sort, page, fetchVendors]);

  useEffect(() => {
    void refreshCounts();
    api.get<{ categories: Category[] }>("/admin/vendor-categories").then((r) => setCategories(r.data.categories)).catch(() => {});
  }, [refreshCounts]);

  const tabs: TabItem<VendorStatus>[] = TABS.map((t) => ({ ...t, count: counts?.[t.value] }));
  const canBulk = can("vendor.review") && activeTab === "pending_review";
  const allSelected = vendors.length > 0 && vendors.every((v) => selected.has(v.id));

  function toggle(id: string) {
    setSelected((s) => {
      const next = new Set(s);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  }

  async function runBulk() {
    if (!bulk) return;
    setBusy(true);
    try {
      const { data } = await api.post<{ results: { id: string; ok: boolean; error?: string }[] }>("/admin/vendors/bulk", {
        action: bulk,
        ids: [...selected],
        ...(bulk === "reject" ? { reason: reason.trim() } : {}),
      });
      const failed = data.results.filter((r) => !r.ok);
      const done = data.results.length - failed.length;
      if (done) toast.success(`${done} vendor${done === 1 ? "" : "s"} ${bulk === "approve" ? "approved" : "rejected"}.`);
      if (failed.length) toast.error(`${failed.length} failed: ${failed[0]!.error ?? "error"}`);
      setBulk(null);
      setReason("");
      setSelected(new Set());
      await Promise.all([fetchVendors(query, true), refreshCounts()]);
    } catch (err) {
      toast.error(errorMessage(err, "Bulk action failed."));
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="page">
      <header className="page-header">
        <h1>Vendors</h1>
      </header>

      <Tabs label="Vendor status" tabs={tabs} value={activeTab} onChange={(v) => update({ status: v })} />

      <div className="filters">
        <SearchBox value={q} onSearch={onSearch} label="Search vendors" placeholder="Search name, phone, area" />
        <label>
          <span className="sr-only">Category</span>
          <select value={category} onChange={(e) => update({ category: e.target.value || null })}>
            <option value="">All categories</option>
            {categories.map((c) => (
              <option key={c.categoryKey} value={c.categoryKey}>
                {c.label ?? vendorCategoryLabel(c.categoryKey)}
              </option>
            ))}
          </select>
        </label>
        <label>
          <span className="sr-only">Price tier</span>
          <select value={priceTier} onChange={(e) => update({ priceTier: e.target.value || null })}>
            <option value="">Any tier</option>
            {TIERS.map((t) => (
              <option key={t} value={t}>
                {tierLabel(t)}
              </option>
            ))}
          </select>
        </label>
        <label>
          <span className="sr-only">Sort</span>
          <select value={sort} onChange={(e) => update({ sort: e.target.value || null })}>
            <option value="">Default order</option>
            <option value="oldest">Oldest first</option>
            <option value="newest">Newest first</option>
            <option value="name">Name A–Z</option>
          </select>
        </label>
      </div>

      {canBulk && vendors.length > 0 && (
        <div className="bulk-bar">
          <label className="check">
            <input
              type="checkbox"
              checked={allSelected}
              onChange={() => setSelected(allSelected ? new Set() : new Set(vendors.map((v) => v.id)))}
            />
            Select all on this page
          </label>
          {selected.size > 0 && (
            <div className="review-actions">
              <span className="muted">{selected.size} selected</span>
              <button type="button" onClick={() => setBulk("approve")}>Approve selected</button>
              <button type="button" className="danger" onClick={() => setBulk("reject")}>Reject selected</button>
            </div>
          )}
        </div>
      )}

      <div role="tabpanel" aria-labelledby={`tab-${activeTab}`}>
        {status === "loading" && <p className="page-status">Loading…</p>}
        {status === "error" && <ErrorRetry message="Failed to load vendors." onRetry={() => void fetchVendors(query)} />}
        {status === "ready" && vendors.length === 0 && (
          <p className="page-status">{q || category || priceTier ? "No vendors match these filters." : "No vendors in this state."}</p>
        )}

        <ul className="vendor-list">
          {vendors.map((vendor) => (
            <li key={vendor.id} className="row-with-check">
              {canBulk && (
                <input
                  type="checkbox"
                  aria-label={`Select ${vendor.businessName ?? vendor.phoneNumber}`}
                  checked={selected.has(vendor.id)}
                  onChange={() => toggle(vendor.id)}
                />
              )}
              <Link to={`/vendors/${vendor.id}`} className="vendor-row">
                <div className="vendor-row-info">
                  <strong>{vendor.businessName ?? "(no business name)"}</strong>
                  <span>
                    {vendor.vendorVendorCategories.map((c) => vendorCategoryLabel(c.vendorCategory.categoryKey)).join(", ") || "No category"}
                    {" · "}
                    {tierLabel(vendor.priceTier)}
                    {" · "}
                    {vendor.serviceArea ?? "No area"}
                    {vendor.submittedAt ? ` · submitted ${formatDate(vendor.submittedAt)}` : ` · ${vendor.phoneNumber}`}
                  </span>
                </div>
                <StatusBadge status={vendor.status} />
              </Link>
            </li>
          ))}
        </ul>
        <Pagination page={page} pageSize={pageSize} total={total} onChange={(p) => update({ page: p > 1 ? String(p) : null })} />
      </div>

      <ConfirmDialog
        open={bulk !== null}
        title={bulk === "approve" ? `Approve ${selected.size} vendors?` : `Reject ${selected.size} vendors?`}
        confirmLabel={bulk === "approve" ? "Approve" : "Reject"}
        danger={bulk === "reject"}
        busy={busy}
        confirmDisabled={bulk === "reject" && !reason.trim()}
        onCancel={() => { setBulk(null); setReason(""); }}
        onConfirm={() => void runBulk()}
      >
        {bulk === "reject" ? (
          <label>
            Reason (shown to every rejected vendor)
            <textarea value={reason} onChange={(e) => setReason(e.target.value)} rows={3} maxLength={1000} />
          </label>
        ) : (
          <p>Each vendor is approved on its own; any that changed meanwhile are reported.</p>
        )}
      </ConfirmDialog>
    </div>
  );
}
