import { createContext, useCallback, useContext, useEffect, useState, type ReactNode } from "react";
import { api } from "./api";
import type { Organizer, EventGroupWithSubEvents } from "@sanchalan/shared-types";

type OrganizerDataState =
  | { status: "loading" }
  | { status: "error" }
  | { status: "needs-profile" }
  | { status: "needs-event"; organizer: Organizer }
  | { status: "ready"; organizer: Organizer; eventGroupId: string };

type OrganizerDataContextValue = OrganizerDataState & { refetch: () => Promise<void> };

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
      if (eventGroups.length === 0) {
        setState({ status: "needs-event", organizer });
        return;
      }
      // Organizer may have more than one event group; no switcher UI yet —
      // take the first. Not an oversight, just out of scope for now.
      setState({ status: "ready", organizer, eventGroupId: eventGroups[0]!.id });
    } catch {
      // A plain fetch failure here isn't an auth failure — real 401s are
      // already handled by api.ts's interceptor (which redirects to login
      // itself). Give this its own retryable state instead of getting stuck
      // on a spinner forever or misreporting it as "needs-profile".
      setState({ status: "error" });
    }
  }, []);

  useEffect(() => {
    refetch();
  }, [refetch]);

  return (
    <OrganizerDataContext.Provider value={{ ...state, refetch }}>
      {children}
    </OrganizerDataContext.Provider>
  );
}

export function useOrganizerData() {
  const ctx = useContext(OrganizerDataContext);
  if (!ctx) throw new Error("useOrganizerData must be used within OrganizerDataProvider");
  return ctx;
}
