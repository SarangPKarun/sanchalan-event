import { randomUUID } from "node:crypto";
import type { EventGroup, TaskCategory, Prisma } from "@prisma/client";
import { prisma } from "../lib/prisma.js";
import { AppError } from "../lib/errors.js";
import { toDateOnly } from "../lib/serialize.js";
import { generateCompletionDetailed } from "../lib/llm.js";
import { env } from "../lib/env.js";
import {
  validateRoadmapOutput,
  type RoadmapItem,
  type RoadmapRegenMode,
} from "../schemas/roadmap.schema.js";
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

export function buildRoadmapPrompt(
  eventGroup: EventGroup,
  templates: TemplateForPrompt[],
  existingTaskNames: string[] = []
) {
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
    "- If the input lists alreadyExistingTasks, the user already has those tasks. Do not",
    "  select a template or add a custom task that duplicates one of them.",
  ].join("\n");

  const userPrompt = JSON.stringify(
    {
      event: {
        eventType: eventGroup.eventType,
        region: eventGroup.region,
        religionOrTradition: eventGroup.religionOrTradition,
        details: eventGroup.details ?? null,
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
      ...(existingTaskNames.length > 0 ? { alreadyExistingTasks: existingTaskNames } : {}),
    },
    null,
    2
  );

  return { systemPrompt, userPrompt };
}

/** What the log keeps about the model calls behind one generation. */
export interface LlmMeta {
  latencyMs?: number;
  attempts?: number;
  inputTokens?: number;
  outputTokens?: number;
}

/** Wraps the LLM call to total up latency, attempts, tokens and raw replies for the generation log. */
function meterLlm() {
  const meta = { latencyMs: 0, attempts: 0, inputTokens: 0, outputTokens: 0 };
  const raws: string[] = [];
  const call = async (system: string, user: string): Promise<string> => {
    const started = Date.now();
    meta.attempts += 1;
    try {
      const { text, usage } = await generateCompletionDetailed(system, user);
      raws.push(text);
      meta.inputTokens += usage.inputTokens ?? 0;
      meta.outputTokens += usage.outputTokens ?? 0;
      return text;
    } finally {
      meta.latencyMs += Date.now() - started;
    }
  };
  return { call, meta, raws };
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
  inputParams: Record<string, unknown>,
  replace: { taskIds: string[]; changedBy: string } = { taskIds: [], changedBy: "" },
  llmMeta: LlmMeta = {}
) {
  const templateByKey = new Map(templates.map((t) => [t.taskKey, t]));
  const taskKeyToId = new Map(items.map((item) => [item.taskKey, randomUUID()]));

  const created = await prisma.$transaction(async (tx) => {
    if (replace.taskIds.length > 0) {
      const toRemove = await tx.task.findMany({
        where: { id: { in: replace.taskIds } },
        select: { id: true, status: true },
      });
      await tx.task.updateMany({
        where: { id: { in: replace.taskIds } },
        data: { status: "not_applicable" },
      });
      await tx.taskEditLog.createMany({
        data: toRemove.map((t) => ({
          taskId: t.id,
          eventGroupId,
          action: "marked_not_applicable" as const,
          previousValue: { status: t.status, reason: "roadmap_regenerated" } as Prisma.InputJsonValue,
          newValue: { status: "not_applicable" } as Prisma.InputJsonValue,
          changedBy: replace.changedBy,
          changedAt: new Date(),
        })),
      });
    }

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
        ...llmMeta,
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

// Decides which existing tasks survive a re-run and which get soft-deleted.
async function planRegeneration(eventGroupId: string, mode: RoadmapRegenMode) {
  const active = await prisma.task.findMany({
    where: { eventGroupId, status: { not: "not_applicable" } },
    select: { id: true, name: true, status: true, source: true },
  });

  if (mode === "replace_all") {
    return { removeIds: active.map((t) => t.id), keptNames: [] as string[] };
  }
  if (mode === "add_missing") {
    return { removeIds: [] as string[], keptNames: active.map((t) => t.name) };
  }

  // keep_my_work: keep user-added tasks, tasks that have progressed, and tasks the user edited.
  const edited = await prisma.taskEditLog.findMany({
    where: { eventGroupId, action: "edited" },
    select: { taskId: true },
  });
  const editedIds = new Set(edited.map((e) => e.taskId));
  const isMine = (t: (typeof active)[number]) =>
    t.source === "user_added" || t.status !== "not_started" || editedIds.has(t.id);
  return {
    removeIds: active.filter((t) => !isMine(t)).map((t) => t.id),
    keptNames: active.filter(isMine).map((t) => t.name),
  };
}

export async function generateRoadmap(
  organizerId: string,
  eventGroupId: string,
  mode?: RoadmapRegenMode
) {
  const eventGroup = await getOwnedEventGroupOrThrow(organizerId, eventGroupId);

  const existingTaskCount = await prisma.task.count({ where: { eventGroupId } });
  if (existingTaskCount > 0 && !mode) {
    throw new AppError(400, "Roadmap already generated for this event");
  }

  const plan =
    existingTaskCount > 0 && mode
      ? await planRegeneration(eventGroupId, mode)
      : { removeIds: [] as string[], keptNames: [] as string[] };

  const [templateRows, categories] = await Promise.all([
    prisma.taskTemplate.findMany({
      where: { eventType: eventGroup.eventType, taskCategory: { isActive: true } },
      include: { taskCategory: true },
    }),
    // ALL categories, not just ones touched by matching templates — every
    // category is currently seeded applicableEventTypes:["wedding"] only,
    // so a non-wedding EventGroup could get zero/few templates and a
    // templates-derived category map would be wrong/empty exactly when a
    // custom task most needs a category to attach to.
    prisma.taskCategory.findMany({ where: { isActive: true } }),
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

  const { systemPrompt, userPrompt } = buildRoadmapPrompt(eventGroup, templates, plan.keptNames);

  const metered = meterLlm();
  let generated: RoadmapItem[];
  try {
    ({ tasks: generated } = await generateAndValidateRoadmap(
      metered.call,
      systemPrompt,
      userPrompt,
      knownTaskKeys,
      knownCategoryKeys
    ));
  } catch (err) {
    // Keep failed attempts so a human can see what the model returned and why it was rejected.
    await prisma.roadmapGenerationLog
      .create({
        data: {
          eventGroupId,
          inputParams: {
            eventType: eventGroup.eventType,
            region: eventGroup.region,
            budgetTier: eventGroup.budgetTier,
            guestCountEstimate: eventGroup.guestCountEstimate,
          },
          templateIdsUsed: [],
          llmModelUsed: env.LLM_MODEL,
          rawOutput: { attempts: metered.raws } as Prisma.InputJsonValue,
          status: "failed",
          error: (err instanceof AppError && err.details ? `${err.message}: ${JSON.stringify(err.details)}` : String(err instanceof Error ? err.message : err)).slice(0, 2000),
          ...metered.meta,
        },
      })
      .catch(() => {});
    throw err;
  }

  // Kept tasks carry no template key, so duplicates are caught by name as a backstop
  // to the prompt instruction. Drop dependencies that pointed at a filtered-out task.
  const keptNameSet = new Set(plan.keptNames.map((n) => n.trim().toLowerCase()));
  const templateNameByKey = new Map(templates.map((t) => [t.taskKey, t.defaultNameEn]));
  const items =
    keptNameSet.size === 0
      ? generated
      : (() => {
          const nameOf = (it: RoadmapItem) => it.name ?? templateNameByKey.get(it.taskKey) ?? it.taskKey;
          const surviving = generated.filter((it) => !keptNameSet.has(nameOf(it).trim().toLowerCase()));
          const survivingKeys = new Set(surviving.map((it) => it.taskKey));
          return surviving.map((it) => ({
            ...it,
            dependencyKeys: it.dependencyKeys.filter((k) => survivingKeys.has(k)),
          }));
        })();

  const usedTemplateIds = templates
    .filter((t) => items.some((item) => !item.isCustom && item.taskKey === t.taskKey))
    .map((t) => t.id);

  const inputParams = {
    eventType: eventGroup.eventType,
    region: eventGroup.region,
    religionOrTradition: eventGroup.religionOrTradition,
    details: eventGroup.details ?? null,
    budgetTier: eventGroup.budgetTier,
    guestCountEstimate: eventGroup.guestCountEstimate,
  };

  const tasks = await createRoadmapInTransaction(
    eventGroupId,
    eventGroup.primaryDate,
    items,
    categoryIdByKey,
    templates,
    usedTemplateIds,
    { ...inputParams, ...(mode ? { regenerationMode: mode } : {}) },
    { taskIds: plan.removeIds, changedBy: organizerId },
    metered.meta
  );

  return { tasks, removedTaskCount: plan.removeIds.length };
}
