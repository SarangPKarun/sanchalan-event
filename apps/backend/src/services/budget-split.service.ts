import { generateCompletion } from "../lib/llm.js";
import { DEFAULT_BUDGET_SPLIT } from "../config/budget-splits.js";
import { validateBudgetSplitOutput } from "../schemas/budget-split.schema.js";

export interface BudgetSplitInput {
  eventType: string;
  name: string;
  region: string;
  religionOrTradition?: string | null;
  guestCountEstimate: number;
  budgetTier: string;
  totalBudget: number;
}

export function buildBudgetSplitPrompt(input: BudgetSplitInput) {
  const systemPrompt = [
    "You are setting up the budget categories for an event-planning app.",
    "Given an event's details, choose the budget categories that make sense for THIS specific event",
    "and how the total budget should be split between them.",
    "",
    "Rules:",
    "- Return between 4 and 10 categories.",
    "- Only include categories that genuinely apply to this event. Do not reuse a generic list: a",
    "  corporate conference, a child's birthday, a religious ceremony and a wedding need different categories.",
    "  For a custom event, infer what is needed from its name and details.",
    "- categoryKey is lowercase snake_case, short and specific (e.g. venue, catering, stage_and_av).",
    "- percentage is a positive number, no single category above 70, and ALL percentages sum to exactly 100.",
    "- Include one small contingency / miscellaneous category (3 to 10 percent).",
    "- Scale the split sensibly to the budget tier, guest count and region.",
    "- Respond with STRICT JSON ONLY: a single object of the exact shape",
    '  { "categories": [ { "categoryKey": "venue", "percentage": 30 }, ... ] }.',
    "  No prose, no explanation, no markdown code fences.",
  ].join("\n");

  const userPrompt = JSON.stringify(
    {
      event: {
        eventType: input.eventType,
        name: input.name,
        region: input.region,
        religionOrTradition: input.religionOrTradition ?? null,
        guestCountEstimate: input.guestCountEstimate,
        budgetTier: input.budgetTier,
        totalBudget: input.totalBudget,
      },
    },
    null,
    2
  );

  return { systemPrompt, userPrompt };
}

/** Asks the LLM for event-specific budget categories (as fractions summing to 1).
 * One retry with the validation error fed back; if the LLM is down or keeps returning
 * invalid output, falls back to DEFAULT_BUDGET_SPLIT so event creation never fails because of it. */
export async function generateBudgetSplit(
  input: BudgetSplitInput,
  callLLM: (system: string, user: string) => Promise<string> = generateCompletion
): Promise<Record<string, number>> {
  const { systemPrompt, userPrompt } = buildBudgetSplitPrompt(input);

  let lastError = "";
  for (let attempt = 0; attempt < 2; attempt++) {
    const prompt =
      attempt === 0
        ? userPrompt
        : `${userPrompt}\n\nYour previous response was invalid: ${lastError}\nFix it and return valid JSON only, matching the exact shape described in the system prompt.`;
    try {
      const result = validateBudgetSplitOutput(await callLLM(systemPrompt, prompt));
      if (result.success) return result.split;
      lastError = result.error;
    } catch (err) {
      lastError = err instanceof Error ? err.message : String(err);
    }
  }

  console.warn(`[budget-split] LLM failed, using default categories: ${lastError}`);
  return DEFAULT_BUDGET_SPLIT;
}
