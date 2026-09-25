import type { EventType } from "@sanchalan/shared-types";

export const DEFAULT_BUDGET_SPLIT: Record<string, number> = {
  venue: 0.3,
  catering: 0.25,
  decor: 0.15,
  photography: 0.15,
  attire: 0.1,
  misc: 0.05,
};

// Signature future-proofed for per-eventType/region variation; ignores both for now.
export function getBudgetSplit(_eventType: EventType, _region: string): Record<string, number> {
  return DEFAULT_BUDGET_SPLIT;
}

function round2(n: number): number {
  return Math.round(n * 100) / 100;
}

/** Sums of the returned amounts may drift a cent or two from `totalBudget`
 * for non-round inputs (independent per-category rounding) — acceptable
 * for v1, not corrected. */
export function computeBudgetAllocations(
  totalBudget: number,
  split: Record<string, number>
): Record<string, number> {
  return Object.fromEntries(
    Object.entries(split).map(([key, pct]) => [key, round2(totalBudget * pct)])
  );
}
