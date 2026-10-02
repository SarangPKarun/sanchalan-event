import { createContext, useCallback, useContext, useEffect, useState, type ReactNode } from "react";
import { api } from "./api";
import type { VendorMeResponse } from "@sanchalan/shared-types";

type VendorDataState =
  | { status: "loading" }
  | { status: "error" }
  | { status: "ready"; vendor: VendorMeResponse };

type VendorDataContextValue = VendorDataState & {
  refetch: () => Promise<void>;
  // Replaces the vendor with a fresh server response without flipping to "loading"
  // (which would unmount the navigator) — use after any edit/submit/withdraw call.
  apply: (vendor: VendorMeResponse) => void;
};

const VendorDataContext = createContext<VendorDataContextValue | null>(null);

export function VendorDataProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState<VendorDataState>({ status: "loading" });

  const refetch = useCallback(async () => {
    setState({ status: "loading" });
    try {
      const { data } = await api.get<VendorMeResponse>("/vendor/me");
      setState({ status: "ready", vendor: data });
    } catch {
      // Real 401s are handled by api.ts's interceptor; this is a retryable fetch failure.
      setState({ status: "error" });
    }
  }, []);

  const apply = useCallback((vendor: VendorMeResponse) => {
    setState({ status: "ready", vendor });
  }, []);

  useEffect(() => {
    refetch();
  }, [refetch]);

  return (
    <VendorDataContext.Provider value={{ ...state, refetch, apply }}>
      {children}
    </VendorDataContext.Provider>
  );
}

export function useVendorData() {
  const ctx = useContext(VendorDataContext);
  if (!ctx) throw new Error("useVendorData must be used within VendorDataProvider");
  return ctx;
}

export function apiErrorMessage(err: unknown, fallback: string): string {
  const message = (err as { response?: { data?: { error?: string } } })?.response?.data?.error;
  return message ?? fallback;
}
