import { useEffect } from "react";
import { Link, useSearchParams } from "react-router-dom";
import { vendorCategoryLabel } from "@sanchalan/shared-types";
import type { VendorStatus } from "@sanchalan/shared-types";
import { useVendors } from "../lib/vendor-context.tsx";
import { formatDate, tierLabel } from "../lib/format.ts";
import { Tabs, type TabItem } from "../components/Tabs.tsx";
import { StatusBadge } from "../components/StatusBadge.tsx";
import { ErrorRetry } from "../components/ErrorRetry.tsx";
import { usePageTitle } from "../components/usePageTitle.ts";

const TABS: TabItem<VendorStatus>[] = [
  { label: "Pending review", value: "pending_review" },
  { label: "Published", value: "published" },
  { label: "Rejected", value: "rejected" },
  { label: "Suspended", value: "suspended" },
  { label: "Drafts", value: "draft" },
];

export function VendorQueuePage() {
  usePageTitle("Vendors");
  const { vendors, status, fetchVendors } = useVendors();
  const [params, setParams] = useSearchParams();
  const requested = params.get("status") as VendorStatus | null;
  const activeTab = TABS.some((t) => t.value === requested) ? requested! : "pending_review";

  useEffect(() => {
    void fetchVendors(activeTab);
  }, [activeTab, fetchVendors]);

  return (
    <div className="page">
      <header className="page-header">
        <h1>Vendors</h1>
      </header>

      <Tabs label="Vendor status" tabs={TABS} value={activeTab} onChange={(v) => setParams({ status: v }, { replace: true })} />

      <div role="tabpanel" aria-labelledby={`tab-${activeTab}`}>
        {status === "loading" && <p className="page-status">Loading…</p>}
        {status === "error" && <ErrorRetry message="Failed to load vendors." onRetry={() => void fetchVendors(activeTab)} />}
        {status === "ready" && vendors.length === 0 && <p className="page-status">No vendors in this state.</p>}

        <ul className="vendor-list">
          {vendors.map((vendor) => (
            <li key={vendor.id}>
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
      </div>
    </div>
  );
}
