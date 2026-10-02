import { createContext, useCallback, useContext, useEffect, useState, type ReactNode } from "react";
import { api } from "./api";
import type { Organizer, EventGroupWithSubEvents } from "@sanchalan/shared-types";

type OrganizerDataState =
  | { status: "loading" }
  | { status: "error" }
  | { status: "needs-profile" }
  | { status: "ready"; organizer: Organizer; eventGroups: EventGroupWithSubEvents[] };

type OrganizerDataContextValue = OrganizerDataState & {
  refetch: () => Promise<void>;
  // Re-fetches the event list without flipping to "loading" (which would unmount the
  // navigator and reset the navigation state) — use after creating/editing an event.
  reloadEvents: () => Promise<void>;
};

const OrganizerDataContext = createContext<OrganizerDataContextValue | null>(null);

export function OrganizerDataProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState<OrganizerDataState>({ status: "loading" });

  const refetch = useCallback(async () => {
    setState({ status: "loading" });
    try {
      const { data: organizer } = await api.get<Organizer>("/organizers/me");
      if (!organizer.displayName || !organizer.organizerType) {
        setState({ status: "needs-profile" });
        return;
      }
      const { data: eventGroups } = await api.get<EventGroupWithSubEvents[]>("/event-groups/me");
      // Zero events is a valid "ready" state — the Events screen shows an empty state.
      setState({ status: "ready", organizer, eventGroups });
    } catch {
      // A plain fetch failure here isn't an auth failure — real 401s are
      // already handled by api.ts's interceptor (which redirects to login
      // itself). Give this its own retryable state instead of getting stuck
      // on a spinner forever or misreporting it as "needs-profile".
      setState({ status: "error" });
    }
  }, []);

  const reloadEvents = useCallback(async () => {
    try {
      const { data: eventGroups } = await api.get<EventGroupWithSubEvents[]>("/event-groups/me");
      setState((prev) => (prev.status === "ready" ? { ...prev, eventGroups } : prev));
    } catch {
      // Keep the list we already have; the next focus/reload will retry.
    }
  }, []);

  useEffect(() => {
    refetch();
  }, [refetch]);

  return (
    <OrganizerDataContext.Provider value={{ ...state, refetch, reloadEvents }}>
      {children}
    </OrganizerDataContext.Provider>
  );
}

export function useOrganizerData() {
  const ctx = useContext(OrganizerDataContext);
  if (!ctx) throw new Error("useOrganizerData must be used within OrganizerDataProvider");
  return ctx;
}
