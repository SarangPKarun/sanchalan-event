import { randomUUID } from "node:crypto";
import type { EventGroup, TaskCategory, Prisma } from "@prisma/client";
import { prisma } from "../lib/prisma.js";
import { AppError } from "../lib/errors.js";
import { toDateOnly } from "../lib/serialize.js";
import { generateCompletion } from "../lib/llm.js";
import { env } from "../lib/env.js";
import { validateRoadmapOutput, type RoadmapItem } from "../schemas/roadmap.schema.js";
import { getOwnedEventGroupOrThrow } from "./event-group.service.js";

interface TemplateForPrompt {
  id: string;
  taskKey: string;
  defaultNameEn: string;
  defaultLeadTimeDays: number;
  defaultDependencyKeys: string[];
  typicalOwnerType: string;
  categoryKey: string;
}

export function buildRoadmapPrompt(eventGroup: EventGroup, templates: TemplateForPrompt[]) {
  const systemPrompt = [
    "You are building a task roadmap for a wedding-planning app, by selecting and",
    "customizing from a fixed library of task templates — you do not invent a task",
    "graph from scratch. The bulk of the roadmap must come from the provided templates.",
    "",
    "Rules:",
    "- Select which of the provided templates genuinely apply to this event. Drop ones",
    "  that don't apply (e.g. skip a priest/officiant task if not relevant to this event).",
    "- You may adjust a template's lead time (dueDateOffsetDays) if the event's own",
    "  timeline is unusually short (primaryDate close to today) and the template's",
    "  default lead time wouldn't fit.",
    "- You may optionally add at most 3 custom tasks genuinely specific to the given",
    "  region/religionOrTradition that have no matching template. Do not add more than 3.",
    "- Respond with STRICT JSON ONLY: a single JSON object of the exact shape",
    '  { "tasks": [ ... ] }. No prose, no explanation, no markdown code fences.',
    "- Every task item has: taskKey (string), isCustom (boolean), category (string,",
    "  must be one of the category keys listed below), dueDateOffsetDays (integer,",
    "  days before the event's primaryDate), dependencyKeys (array of other tasks'",
    "  taskKey values in THIS response that must happen first), ownerType",
    '  ("organizer" | "vendor" | "planner").',
    "- For a template-based task, taskKey MUST be exactly one of the provided template",
    "  taskKeys, and isCustom must be false.",
    "- For a custom task, isCustom must be true, you must invent a new unique taskKey",
    '  (prefix it "custom_"), and you must also include a "name" field (string).',
    "- dependencyKeys may reference ANY task's taskKey in this same response —",
    "  template-based or custom — not just the template library's own default keys.",
  ].join("\n");

  const userPrompt = JSON.stringify(
    {
      event: {
        eventType: eventGroup.eventType,
        region: eventGroup.region,
        religionOrTradition: eventGroup.religionOrTradition,
        guestCountEstimate: eventGroup.guestCountEstimate,
        budgetTier: eventGroup.budgetTier,
        primaryDate: toDateOnly(eventGroup.primaryDate),
      },
      availableTemplates: templates.map((t) => ({
        taskKey: t.taskKey,
        defaultNameEn: t.defaultNameEn,
        defaultLeadTimeDays: t.defaultLeadTimeDays,
        defaultDependencyKeys: t.defaultDependencyKeys,
        typicalOwnerType: t.typicalOwnerType,
        category: t.categoryKey,
      })),
    },
    null,
    2
  );

  return { systemPrompt, userPrompt };
}

export async function generateAndValidateRoadmap(
  callLLM: (system: string, user: string) => Promise<string>,
  systemPrompt: string,
  userPrompt: string,
  knownTaskKeys: Set<string>,
  knownCategoryKeys: Set<string>
): Promise<{ tasks: RoadmapItem[] }> {
  let lastError = "";
  for (let attempt = 0; attempt < 2; attempt++) {
    const prompt =
      attempt === 0
        ? userPrompt
        : `${userPrompt}\n\nYour previous response was invalid: ${lastError}\nFix it and return valid JSON only, matching the exact shape described in the system prompt.`;
    const raw = await callLLM(systemPrompt, prompt);
    const result = validateRoadmapOutput(raw, knownTaskKeys, knownCategoryKeys);
    if (result.success) return result.data;
    lastError = result.error;
  }
  throw new AppError(502, "LLM failed to produce a valid roadmap after retry", { lastError });
}

export async function createRoadmapInTransaction(
  eventGroupId: string,
  primaryDate: Date,
  items: RoadmapItem[],
  categoryIdByKey: Map<string, string>,
  templates: TemplateForPrompt[],
  templateIdsUsed: string[],
  inputParams: Record<string, unknown>
) {
  const templateByKey = new Map(templates.map((t) => [t.taskKey, t]));
  const taskKeyToId = new Map(items.map((item) => [item.taskKey, randomUUID()]));

  const created = await prisma.$transaction(async (tx) => {
    const taskRows = items.map((item) => {
      const template = templateByKey.get(item.taskKey);
      const dueDate = new Date(primaryDate);
      dueDate.setDate(dueDate.getDate() - item.dueDateOffsetDays);
      const categoryId = categoryIdByKey.get(item.category);
      if (!categoryId) {
        // Unreachable post-validation (category is checked against
        // knownCategoryKeys) — defense in depth, rolls back the transaction.
        throw new AppError(500, `Unresolved category "${item.category}" survived validation.`);
      }
      return {
        id: taskKeyToId.get(item.taskKey)!,
        eventGroupId,
        taskCategoryId: categoryId,
        name: item.name ?? template?.defaultNameEn ?? item.taskKey,
        status: "not_started" as const,
        dueDate,
        source: "ai_generated" as const,
        ownerType: item.ownerType,
      };
    });
    await tx.task.createMany({ data: taskRows });

    const dependencyRows = items.flatMap((item) =>
      item.dependencyKeys.map((depKey) => {
        const dependsOnTaskId = taskKeyToId.get(depKey);
        if (!dependsOnTaskId) {
          // Unreachable post-validation — defense in depth. This is what
          // actually rolls back the transaction (Task rows included) if a
          // dependency key ever slips through validation.
          throw new AppError(500, `Unresolved dependency key "${depKey}" survived validation.`);
        }
        return { taskId: taskKeyToId.get(item.taskKey)!, dependsOnTaskId };
      })
    );
    if (dependencyRows.length > 0) {
      await tx.taskDependency.createMany({ data: dependencyRows });
    }

    await tx.roadmapGenerationLog.create({
      data: {
        eventGroupId,
        inputParams: inputParams as Prisma.InputJsonValue,
        templateIdsUsed,
        llmModelUsed: env.LLM_MODEL,
        rawOutput: { tasks: items } as Prisma.InputJsonValue,
      },
    });

    return taskRows;
  });

  return created.map((row) => ({
    ...row,
    dueDate: toDateOnly(row.dueDate),
    categoryKey: items.find((it) => taskKeyToId.get(it.taskKey) === row.id)!.category,
    dependsOnTaskIds: (
      items.find((it) => taskKeyToId.get(it.taskKey) === row.id)?.dependencyKeys ?? []
    ).map((k) => taskKeyToId.get(k)!),
  }));
}

export async function generateRoadmap(organizerId: string, eventGroupId: string) {
  const eventGroup = await getOwnedEventGroupOrThrow(organizerId, eventGroupId);

  const existingTaskCount = await prisma.task.count({ where: { eventGroupId } });
  if (existingTaskCount > 0) {
    throw new AppError(400, "Roadmap already generated for this event");
  }

  const [templateRows, categories] = await Promise.all([
    prisma.taskTemplate.findMany({
      where: { eventType: eventGroup.eventType },
      include: { taskCategory: true },
    }),
    // ALL categories, not just ones touched by matching templates — every
    // category is currently seeded applicableEventTypes:["wedding"] only,
    // so a non-wedding EventGroup could get zero/few templates and a
    // templates-derived category map would be wrong/empty exactly when a
    // custom task most needs a category to attach to.
    prisma.taskCategory.findMany(),
  ]);

  const templates: TemplateForPrompt[] = templateRows.map((t) => ({
    id: t.id,
    taskKey: t.taskKey,
    defaultNameEn: t.defaultNameEn,
    defaultLeadTimeDays: t.defaultLeadTimeDays,
    defaultDependencyKeys: t.defaultDependencyKeys,
    typicalOwnerType: t.typicalOwnerType,
    categoryKey: t.taskCategory.categoryKey,
  }));

  const knownTaskKeys = new Set(templates.map((t) => t.taskKey));
  const categoryIdByKey = new Map<string, string>(
    categories.map((c: TaskCategory) => [c.categoryKey, c.id])
  );
  const knownCategoryKeys = new Set(categoryIdByKey.keys());

  const { systemPrompt, userPrompt } = buildRoadmapPrompt(eventGroup, templates);

  const { tasks: items } = await generateAndValidateRoadmap(
    generateCompletion,
    systemPrompt,
    userPrompt,
    knownTaskKeys,
    knownCategoryKeys
  );

  const usedTemplateIds = templates
    .filter((t) => items.some((item) => !item.isCustom && item.taskKey === t.taskKey))
    .map((t) => t.id);

  const inputParams = {
    eventType: eventGroup.eventType,
    region: eventGroup.region,
    religionOrTradition: eventGroup.religionOrTradition,
    budgetTier: eventGroup.budgetTier,
    guestCountEstimate: eventGroup.guestCountEstimate,
  };

  return createRoadmapInTransaction(
    eventGroupId,
    eventGroup.primaryDate,
    items,
    categoryIdByKey,
    templates,
    usedTemplateIds,
    inputParams
  );
}
