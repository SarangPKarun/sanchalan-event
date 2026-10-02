import { z } from "zod";
import { extractJsonPayload } from "./roadmap.schema.js";

const MIN_CATEGORIES = 4;
const MAX_CATEGORIES = 10;
const MAX_SINGLE_PERCENTAGE = 70;

const categoryItemSchema = z.object({
  categoryKey: z.string().regex(/^[a-z][a-z0-9_]{1,39}$/, "categoryKey must be lowercase snake_case"),
  percentage: z.number().positive().max(MAX_SINGLE_PERCENTAGE),
});

const budgetSplitSchema = z
  .object({ categories: z.array(categoryItemSchema).min(MIN_CATEGORIES).max(MAX_CATEGORIES) })
  .superRefine((body, ctx) => {
    const seen = new Set<string>();
    body.categories.forEach((c, i) => {
      if (seen.has(c.categoryKey)) {
        ctx.addIssue({
          code: "custom",
          path: ["categories", i, "categoryKey"],
          message: `Duplicate categoryKey "${c.categoryKey}".`,
        });
      }
      seen.add(c.categoryKey);
    });
    const sum = body.categories.reduce((total, c) => total + c.percentage, 0);
    if (sum < 99 || sum > 101) {
      ctx.addIssue({
        code: "custom",
        path: ["categories"],
        message: `Percentages must sum to 100 (got ${sum}).`,
      });
    }
  });

export type ValidateBudgetSplitResult =
  | { success: true; split: Record<string, number> } // fractions summing to exactly 1
  | { success: false; error: string };

export function validateBudgetSplitOutput(rawText: string): ValidateBudgetSplitResult {
  let parsed: unknown;
  try {
    parsed = JSON.parse(extractJsonPayload(rawText));
  } catch {
    return { success: false, error: "Response was not valid JSON." };
  }
  const result = budgetSplitSchema.safeParse(parsed);
  if (!result.success) return { success: false, error: result.error.message };

  const sum = result.data.categories.reduce((total, c) => total + c.percentage, 0);
  return {
    success: true,
    split: Object.fromEntries(result.data.categories.map((c) => [c.categoryKey, c.percentage / sum])),
  };
}
