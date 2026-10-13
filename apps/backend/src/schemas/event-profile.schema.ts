import { z } from "zod";
import { extractJsonPayload } from "./roadmap.schema.js";
import { CORE_QUESTION_KEYS, type Step } from "../config/event-type-profiles.js";

// The LLM only picks from this small vocabulary. It cannot set `mapsTo` or `showIf`, and it
// cannot ask for dates or budgets (the core steps already do), so a bad answer cannot break creation.
const MAX_STEPS = 3;
const MAX_QUESTIONS = 8;

const optionSchema = z.object({
  value: z.string().regex(/^[a-z][a-z0-9_]{0,29}$/, "option value must be lowercase snake_case"),
  label: z.string().min(1).max(40),
});

const questionSchema = z.object({
  key: z.string().regex(/^[a-z][a-zA-Z0-9]{2,29}$/, "key must be camelCase, 3-30 characters"),
  label: z.string().min(3).max(100),
  kind: z.enum(["single_select", "multi_select", "text", "number"]),
  options: z.array(optionSchema).min(2).max(8).optional(),
  allowOther: z.boolean().optional(),
  required: z.boolean().optional(),
});

const generatedProfileSchema = z
  .object({
    steps: z
      .array(
        z.object({
          title: z.string().min(2).max(40),
          subtitle: z.string().max(100).optional(),
          questions: z.array(questionSchema).min(1).max(3),
        })
      )
      .min(1)
      .max(MAX_STEPS),
  })
  .superRefine((body, ctx) => {
    const keys = new Set<string>(CORE_QUESTION_KEYS);
    let total = 0;
    body.steps.forEach((step, si) =>
      step.questions.forEach((q, qi) => {
        total += 1;
        const path = ["steps", si, "questions", qi];
        if (keys.has(q.key)) {
          ctx.addIssue({ code: "custom", path: [...path, "key"], message: `Duplicate or reserved key "${q.key}".` });
        }
        keys.add(q.key);
        const isSelect = q.kind === "single_select" || q.kind === "multi_select";
        if (isSelect && !q.options) {
          ctx.addIssue({ code: "custom", path: [...path, "options"], message: "Select questions need options." });
        }
        if (!isSelect && q.options) {
          ctx.addIssue({ code: "custom", path: [...path, "options"], message: "Only select questions take options." });
        }
        const values = (q.options ?? []).map((o) => o.value);
        if (new Set(values).size !== values.length) {
          ctx.addIssue({ code: "custom", path: [...path, "options"], message: "Duplicate option values." });
        }
      })
    );
    if (total > MAX_QUESTIONS) {
      ctx.addIssue({ code: "custom", path: ["steps"], message: `At most ${MAX_QUESTIONS} questions in total.` });
    }
  });

export type ValidateGeneratedProfileResult =
  | { success: true; steps: Step[] }
  | { success: false; error: string };

export function validateGeneratedProfileOutput(rawText: string): ValidateGeneratedProfileResult {
  let parsed: unknown;
  try {
    parsed = JSON.parse(extractJsonPayload(rawText));
  } catch {
    return { success: false, error: "Response was not valid JSON." };
  }
  const result = generatedProfileSchema.safeParse(parsed);
  if (!result.success) return { success: false, error: result.error.message };

  const steps: Step[] = result.data.steps.map((s, i) => ({
    id: `gen${i + 1}`,
    title: s.title,
    ...(s.subtitle ? { subtitle: s.subtitle } : {}),
    questions: s.questions.map((q) => ({
      key: q.key,
      label: q.label,
      kind: q.kind,
      ...(q.options ? { options: q.options } : {}),
      ...(q.allowOther ? { allowOther: true } : {}),
      ...(q.required ? { required: true } : {}),
    })),
  }));
  return { success: true, steps };
}

export const generateEventProfileSchema = z.object({
  description: z.string().trim().min(5, "Describe your event in a few words.").max(300),
});
export type GenerateEventProfileInput = z.infer<typeof generateEventProfileSchema>;
