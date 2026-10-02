import { createContext, useContext, useCallback, useState, type ReactNode } from "react";
import type {
  Vendor,
  VendorCategory,
  VendorPortfolioItem,
  VendorReviewLog,
  VendorStatus,
} from "@sanchalan/shared-types";
import { api } from "./api.ts";

export interface VendorWithReview extends Vendor {
  vendorVendorCategories: { vendorCategory: VendorCategory }[];
  portfolioItems: VendorPortfolioItem[];
}

export interface VendorDetail extends VendorWithReview {
  reviewLogs: (VendorReviewLog & { admin: { id: string; name: string } | null })[];
}

interface VendorContextValue {
  vendors: VendorWithReview[];
  status: "idle" | "loading" | "error" | "ready";
  fetchVendors: (statusFilter: VendorStatus) => Promise<void>;
}

const VendorContext = createContext<VendorContextValue | null>(null);

export function VendorProvider({ children }: { children: ReactNode }) {
  const [vendors, setVendors] = useState<VendorWithReview[]>([]);
  const [status, setStatus] = useState<VendorContextValue["status"]>("idle");

  const fetchVendors = useCallback(async (statusFilter: VendorStatus) => {
    setStatus("loading");
    try {
      const { data } = await api.get("/admin/vendors", { params: { status: statusFilter } });
      setVendors(data.vendors);
      setStatus("ready");
    } catch {
      setStatus("error");
    }
  }, []);

  return (
    <VendorContext.Provider value={{ vendors, status, fetchVendors }}>
      {children}
    </VendorContext.Provider>
  );
}

export function useVendors() {
  const ctx = useContext(VendorContext);
  if (!ctx) throw new Error("useVendors must be used within VendorProvider");
  return ctx;
}
