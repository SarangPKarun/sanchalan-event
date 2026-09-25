import { createContext, useContext, useCallback, useState, type ReactNode } from "react";
import type { Vendor, VendorCategory, VendorPortfolioItem, VendorStatus } from "@sanchalan/shared-types";
import { api } from "./api.ts";

export interface VendorWithReview extends Vendor {
  vendorVendorCategories: { vendorCategory: VendorCategory }[];
  portfolioItems: VendorPortfolioItem[];
}

interface VendorContextValue {
  vendors: VendorWithReview[];
  status: "idle" | "loading" | "error" | "ready";
  fetchVendors: (statusFilter: VendorStatus) => Promise<void>;
  getVendor: (id: string) => VendorWithReview | undefined;
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

  const getVendor = useCallback((id: string) => vendors.find((v) => v.id === id), [vendors]);

  return (
    <VendorContext.Provider value={{ vendors, status, fetchVendors, getVendor }}>
      {children}
    </VendorContext.Provider>
  );
}

export function useVendors() {
  const ctx = useContext(VendorContext);
  if (!ctx) throw new Error("useVendors must be used within VendorProvider");
  return ctx;
}
