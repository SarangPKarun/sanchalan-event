import { createContext, useContext, useCallback, useState, type ReactNode } from "react";
import type {
  Vendor,
  VendorCategory,
  VendorPortfolioItem,
  VendorReviewLog,
} from "@sanchalan/shared-types";
import { api } from "./api.ts";

export interface VendorWithReview extends Vendor {
  vendorVendorCategories: { vendorCategory: VendorCategory }[];
  portfolioItems: VendorPortfolioItem[];
}

export interface VendorDetail extends VendorWithReview {
  reviewLogs: (VendorReviewLog & { admin: { id: string; name: string } | null })[];
}

export interface VendorListParams {
  status: string;
  q?: string;
  category?: string;
  priceTier?: string;
  sort?: string;
  page?: number;
}

interface VendorContextValue {
  vendors: VendorWithReview[];
  total: number;
  pageSize: number;
  status: "idle" | "loading" | "error" | "ready";
  /** `silent` keeps the current rows on screen while refreshing (after an action). */
  fetchVendors: (params: VendorListParams, silent?: boolean) => Promise<void>;
}

const VendorContext = createContext<VendorContextValue | null>(null);

export function VendorProvider({ children }: { children: ReactNode }) {
  const [vendors, setVendors] = useState<VendorWithReview[]>([]);
  const [total, setTotal] = useState(0);
  const [pageSize, setPageSize] = useState(20);
  const [status, setStatus] = useState<VendorContextValue["status"]>("idle");

  const fetchVendors = useCallback(async (params: VendorListParams, silent = false) => {
    if (!silent) setStatus("loading");
    try {
      const { data } = await api.get("/admin/vendors", { params });
      setVendors(data.vendors);
      setTotal(data.total ?? data.vendors.length);
      setPageSize(data.pageSize ?? 20);
      setStatus("ready");
    } catch {
      setStatus("error");
    }
  }, []);

  return (
    <VendorContext.Provider value={{ vendors, total, pageSize, status, fetchVendors }}>
      {children}
    </VendorContext.Provider>
  );
}

export function useVendors() {
  const ctx = useContext(VendorContext);
  if (!ctx) throw new Error("useVendors must be used within VendorProvider");
  return ctx;
}
