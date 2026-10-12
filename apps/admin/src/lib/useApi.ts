import { useCallback, useEffect, useState } from "react";
import { api } from "./api.ts";

export type LoadState = "loading" | "error" | "notfound" | "ready";

/** GETs `path` with `query`; reloads when either changes. `reload(true)` refreshes without a loading flash. */
export function useApi<T>(path: string, query: Record<string, unknown> = {}, enabled = true) {
  const [data, setData] = useState<T | null>(null);
  const [state, setState] = useState<LoadState>(enabled ? "loading" : "ready");
  const queryKey = JSON.stringify(query);

  const reload = useCallback(
    async (silent = false) => {
      if (!silent) setState("loading");
      try {
        const res = await api.get<T>(path, { params: JSON.parse(queryKey) });
        setData(res.data);
        setState("ready");
      } catch (err) {
        setState((err as { response?: { status?: number } })?.response?.status === 404 ? "notfound" : "error");
      }
    },
    [path, queryKey]
  );

  useEffect(() => {
    if (enabled) void reload();
  }, [reload, enabled]);

  return { data, state, reload };
}
