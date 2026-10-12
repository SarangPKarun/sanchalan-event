import { useCallback } from "react";
import { useSearchParams } from "react-router-dom";

/** Filter and page state kept in the URL, so refresh, back and shared links keep the view. */
export function useListParams() {
  const [params, setParams] = useSearchParams();
  const update = useCallback(
    (patch: Record<string, string | null>) =>
      setParams(
        (prev) => {
          const next = new URLSearchParams(prev);
          for (const [k, v] of Object.entries(patch)) (v ? next.set(k, v) : next.delete(k));
          if (!("page" in patch)) next.delete("page");
          return next;
        },
        { replace: true }
      ),
    [setParams]
  );
  return { params, update, page: Math.max(1, Number(params.get("page")) || 1) };
}
