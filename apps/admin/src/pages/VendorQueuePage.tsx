import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import type { VendorStatus } from "@sanchalan/shared-types";
import { useVendors } from "../lib/vendor-context.tsx";
import { useAuth } from "../lib/auth-context.tsx";

const TABS: { label: string; value: VendorStatus }[] = [
  { label: "Pending review", value: "pending_review" },
  { label: "Published", value: "published" },
  { label: "Rejected", value: "rejected" },
];

export function VendorQueuePage() {
  const { vendors, status, fetchVendors } = useVendors();
  const { signOut } = useAuth();
  const [activeTab, setActiveTab] = useState<VendorStatus>("pending_review");

  useEffect(() => {
    fetchVendors(activeTab);
  }, [activeTab, fetchVendors]);

  return (
    <div className="page">
      <header className="page-header">
        <h1>Vendor review queue</h1>
        <button className="link-button" onClick={() => signOut()}>
          Log out
        </button>
      </header>

      <div className="tabs">
        {TABS.map((tab) => (
          <button
            key={tab.value}
            className={tab.value === activeTab ? "tab tab-active" : "tab"}
            onClick={() => setActiveTab(tab.value)}
          >
            {tab.label}
          </button>
        ))}
      </div>

      {status === "loading" && <p className="page-status">Loading…</p>}
      {status === "error" && <p className="page-status error-text">Failed to load vendors.</p>}
      {status === "ready" && vendors.length === 0 && (
        <p className="page-status">No vendors in this state.</p>
      )}

      <ul className="vendor-list">
        {vendors.map((vendor) => (
          <li key={vendor.id}>
            <Link to={`/vendors/${vendor.id}`} className="vendor-row">
              <div className="vendor-thumbs">
                {vendor.portfolioItems.slice(0, 3).map((item) => (
                  <img key={item.id} src={item.mediaUrl} alt="" />
                ))}
              </div>
              <div className="vendor-row-info">
                <strong>{vendor.businessName ?? "(no business name)"}</strong>
                <span>
                  {vendor.vendorVendorCategories.map((c) => c.vendorCategory.categoryKey).join(", ") ||
                    "no category"}
                  {" · "}
                  {vendor.priceTier ?? "no tier"}
                  {" · "}
                  {vendor.serviceArea ?? "no area"}
                </span>
              </div>
            </Link>
          </li>
        ))}
      </ul>
    </div>
  );
}
