import { z } from "zod";

const taskItemSchema = z
  .object({
    taskKey: z.string().min(1),
    isCustom: z.boolean(),
    name: z.string().min(1).optional(),
    category: z.string().min(1),
    dueDateOffsetDays: z.number().int().min(0),
    dependencyKeys: z.array(z.string()).default([]),
    ownerType: z.enum(["organizer", "vendor", "planner"]),
  })
  .refine((t) => !t.isCustom || !!t.name, {
    message: "Custom tasks must include a name.",
    path: ["name"],
  });

const MAX_CUSTOM_TASKS = 3;

export function buildRoadmapSchema(
  knownTemplateTaskKeys: Set<string>,
  knownCategoryKeys: Set<string>
) {
  return z
    .object({ tasks: z.array(taskItemSchema).min(1) })
    .superRefine((body, ctx) => {
      const items = body.tasks;
      const seenKeys = new Set<string>();
      let customCount = 0;

      items.forEach((item, i) => {
        if (seenKeys.has(item.taskKey)) {
          ctx.addIssue({
            code: "custom",
            path: ["tasks", i, "taskKey"],
            message: `Duplicate taskKey "${item.taskKey}".`,
          });
        }
        seenKeys.add(item.taskKey);

        if (!knownCategoryKeys.has(item.category)) {
          ctx.addIssue({
            code: "custom",
            path: ["tasks", i, "category"],
            message: `Unknown category "${item.category}".`,
          });
        }

        if (item.isCustom) {
          customCount++;
          if (knownTemplateTaskKeys.has(item.taskKey)) {
            ctx.addIssue({
              code: "custom",
              path: ["tasks", i, "taskKey"],
              message: `Custom task taskKey "${item.taskKey}" collides with a real template key.`,
            });
          }
        } else if (!knownTemplateTaskKeys.has(item.taskKey)) {
          ctx.addIssue({
            code: "custom",
            path: ["tasks", i, "taskKey"],
            message: `Non-custom taskKey "${item.taskKey}" is not one of the templates that were sent.`,
          });
        }

        if (item.dependencyKeys.includes(item.taskKey)) {
          ctx.addIssue({
            code: "custom",
            path: ["tasks", i, "dependencyKeys"],
            message: `Task "${item.taskKey}" cannot depend on itself.`,
          });
        }
      });

      const allKeysInResponse = new Set(items.map((it) => it.taskKey));
      items.forEach((item, i) => {
        item.dependencyKeys.forEach((dep, di) => {
          if (!allKeysInResponse.has(dep)) {
            ctx.addIssue({
              code: "custom",
              path: ["tasks", i, "dependencyKeys", di],
              message: `Dependency "${dep}" does not match any taskKey in this response.`,
            });
          }
        });
      });

      if (customCount > MAX_CUSTOM_TASKS) {
        ctx.addIssue({
          code: "custom",
          path: ["tasks"],
          message: `Too many custom tasks (${customCount}); max ${MAX_CUSTOM_TASKS} per generation.`,
        });
      }

      // Dependency cycle check (DFS) — a longer A -> B -> A cycle isn't
      // caught by the self-dependency check above, and nothing downstream
      // repairs a cycle once the transaction commits.
      const adjacency = new Map(items.map((it) => [it.taskKey, it.dependencyKeys]));
      const visiting = new Set<string>();
      const visited = new Set<string>();
      function hasCycle(key: string): boolean {
        if (visited.has(key)) return false;
        if (visiting.has(key)) return true;
        visiting.add(key);
        for (const dep of adjacency.get(key) ?? []) {
          if (hasCycle(dep)) return true;
        }
        visiting.delete(key);
        visited.add(key);
        return false;
      }
      for (const key of adjacency.keys()) {
        if (hasCycle(key)) {
          ctx.addIssue({
            code: "custom",
            path: ["tasks"],
            message: `Dependency cycle detected involving "${key}".`,
          });
          break;
        }
      }
    });
}

export type RoadmapItem = z.infer<typeof taskItemSchema>;

export function extractJsonPayload(rawText: string): string {
  const fenced = rawText.match(/```(?:json)?\s*([\s\S]*?)```/);
  return (fenced ? fenced[1]! : rawText).trim();
}

export type ValidateRoadmapResult =
  | { success: true; data: { tasks: RoadmapItem[] } }
  | { success: false; error: string };

export function validateRoadmapOutput(
  rawText: string,
  knownTaskKeys: Set<string>,
  knownCategoryKeys: Set<string>
): ValidateRoadmapResult {
  let parsed: unknown;
  try {
    parsed = JSON.parse(extractJsonPayload(rawText));
  } catch {
    return { success: false, error: "Response was not valid JSON." };
  }
  const result = buildRoadmapSchema(knownTaskKeys, knownCategoryKeys).safeParse(parsed);
  return result.success
    ? { success: true, data: result.data }
    : { success: false, error: result.error.message };
}
