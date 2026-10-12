import type { EventType, Prisma, TaskOwnerType } from "@prisma/client";
import { prisma } from "../lib/prisma.js";
import { AppError } from "../lib/errors.js";
import { audit } from "../lib/audit.js";
import { generateCompletion } from "../lib/llm.js";
import { extractJsonPayload } from "../schemas/roadmap.schema.js";
import { z } from "zod";
import type { updateTemplateSchema } from "../schemas/admin-list.schema.js";

type UpdateTemplateInput = z.infer<typeof updateTemplateSchema>;

type Tx = Prisma.TransactionClient;

// ── Categories ─────────────────────────────────────────────────────────────

/** Vendor and task categories are separate tables that share keys; the admin sees one row per key. */
export async function listCategories() {
  const [vendor, task] = await Promise.all([
    prisma.vendorCategory.findMany({ include: { _count: { select: { vendorVendorCategories: true } } } }),
    prisma.taskCategory.findMany({ include: { _count: { select: { taskTemplates: true } } } }),
  ]);
  const byKey = new Map<string, {
    categoryKey: string;
    vendorCategoryId: string | null;
    label: string | null;
    isActive: boolean;
    applicableEventTypes: EventType[];
    vendorCount: number | null;
    templateCount: number | null;
  }>();
  for (const v of vendor)
    byKey.set(v.categoryKey, {
      categoryKey: v.categoryKey,
      vendorCategoryId: v.id,
      label: v.label,
      isActive: v.isActive,
      applicableEventTypes: v.applicableEventTypes,
      vendorCount: v._count.vendorVendorCategories,
      templateCount: null,
    });
  for (const t of task) {
    const existing = byKey.get(t.categoryKey);
    if (existing) {
      existing.templateCount = t._count.taskTemplates;
      existing.label ??= t.label;
      existing.isActive = existing.isActive && t.isActive;
    } else
      byKey.set(t.categoryKey, {
        categoryKey: t.categoryKey,
        vendorCategoryId: null,
        label: t.label,
        isActive: t.isActive,
        applicableEventTypes: t.applicableEventTypes,
        vendorCount: null,
        templateCount: t._count.taskTemplates,
      });
  }
  return { categories: [...byKey.values()].sort((a, b) => a.categoryKey.localeCompare(b.categoryKey)) };
}

export async function updateCategory(
  adminId: string,
  key: string,
  input: { label?: string | undefined; applicableEventTypes?: EventType[] | undefined; isActive?: boolean | undefined }
) {
  const data = {
    ...(input.label !== undefined ? { label: input.label } : {}),
    ...(input.applicableEventTypes ? { applicableEventTypes: input.applicableEventTypes } : {}),
    ...(input.isActive !== undefined ? { isActive: input.isActive } : {}),
  };
  await prisma.$transaction(async (tx) => {
    const [v, t] = await Promise.all([
      tx.vendorCategory.updateMany({ where: { categoryKey: key }, data }),
      tx.taskCategory.updateMany({ where: { categoryKey: key }, data }),
    ]);
    if (v.count + t.count === 0) throw new AppError(404, "Category not found");
    await audit({ adminId, action: "category.updated", entityType: "category", entityId: key, metadata: { ...input } }, tx);
  });
  return (await listCategories()).categories.find((c) => c.categoryKey === key);
}

// ── Task templates ─────────────────────────────────────────────────────────

const TEMPLATE_INCLUDE = { taskCategory: { select: { categoryKey: true, label: true } } } as const;

export async function listTemplates(categoryKey?: string) {
  const templates = await prisma.taskTemplate.findMany({
    where: categoryKey ? { taskCategory: { categoryKey } } : {},
    include: TEMPLATE_INCLUDE,
    orderBy: [{ taskCategory: { categoryKey: "asc" } }, { defaultLeadTimeDays: "desc" }, { taskKey: "asc" }],
  });
  return { templates };
}

/** Every dependency must exist (same event type) and the graph must stay acyclic. */
async function assertValidDependencies(
  tx: Tx,
  eventType: EventType,
  taskKey: string,
  dependencyKeys: string[],
  ignoreId?: string
) {
  if (dependencyKeys.includes(taskKey)) throw new AppError(400, "A task cannot depend on itself");
  const all = await tx.taskTemplate.findMany({
    where: { eventType, ...(ignoreId ? { id: { not: ignoreId } } : {}) },
    select: { taskKey: true, defaultDependencyKeys: true },
  });
  const graph = new Map(all.map((t) => [t.taskKey, t.defaultDependencyKeys]));
  const unknown = dependencyKeys.filter((k) => !graph.has(k));
  if (unknown.length) throw new AppError(400, `Unknown dependency task key(s): ${unknown.join(", ")}`);

  graph.set(taskKey, dependencyKeys);
  const seen = new Set<string>();
  const walk = (k: string, path: Set<string>): void => {
    if (path.has(k)) throw new AppError(400, "These dependencies would create a loop");
    if (seen.has(k)) return;
    seen.add(k);
    for (const d of graph.get(k) ?? []) walk(d, new Set([...path, k]));
  };
  walk(taskKey, new Set());
}

export async function createTemplate(
  adminId: string,
  input: {
    categoryKey: string;
    eventType: EventType;
    taskKey: string;
    defaultNameEn: string;
    defaultLeadTimeDays: number;
    defaultDependencyKeys: string[];
    typicalOwnerType: TaskOwnerType;
  }
) {
  return prisma.$transaction(async (tx) => {
    const category = await tx.taskCategory.findUnique({ where: { categoryKey: input.categoryKey } });
    if (!category) throw new AppError(404, "Category not found");
    if (await tx.taskTemplate.findFirst({ where: { taskKey: input.taskKey } }))
      throw new AppError(409, "A template with this task key already exists");
    await assertValidDependencies(tx, input.eventType, input.taskKey, input.defaultDependencyKeys);

    const { categoryKey: _omit, ...fields } = input;
    const created = await tx.taskTemplate.create({
      data: { ...fields, taskCategoryId: category.id, version: 1 },
      include: TEMPLATE_INCLUDE,
    });
    await audit({ adminId, action: "template.created", entityType: "task_template", entityId: created.id, metadata: { taskKey: input.taskKey } }, tx);
    return created;
  });
}

export async function updateTemplate(
  adminId: string,
  id: string,
  input: UpdateTemplateInput
) {
  const changes = Object.fromEntries(Object.entries(input).filter(([, v]) => v !== undefined)) as Prisma.TaskTemplateUpdateInput;
  return prisma.$transaction(async (tx) => {
    const current = await tx.taskTemplate.findUnique({ where: { id } });
    if (!current) throw new AppError(404, "Template not found");

    const newKey = input.taskKey ?? current.taskKey;
    if (newKey !== current.taskKey) {
      if (await tx.taskTemplate.findFirst({ where: { taskKey: newKey } }))
        throw new AppError(409, "A template with this task key already exists");
      const dependents = await tx.taskTemplate.count({ where: { defaultDependencyKeys: { has: current.taskKey } } });
      if (dependents > 0) throw new AppError(409, "Other templates depend on this task key, so it cannot be renamed");
    }
    await assertValidDependencies(tx, current.eventType, newKey, input.defaultDependencyKeys ?? current.defaultDependencyKeys, id);

    const updated = await tx.taskTemplate.update({
      where: { id },
      data: { ...changes, version: { increment: 1 } },
      include: TEMPLATE_INCLUDE,
    });
    await audit({ adminId, action: "template.updated", entityType: "task_template", entityId: id, metadata: { ...changes } as Prisma.InputJsonValue }, tx);
    return updated;
  });
}

export async function deleteTemplate(adminId: string, id: string) {
  await prisma.$transaction(async (tx) => {
    const current = await tx.taskTemplate.findUnique({ where: { id } });
    if (!current) throw new AppError(404, "Template not found");
    // A dangling dependency key would make roadmap generation fail validation.
    const dependents = await tx.taskTemplate.findMany({
      where: { defaultDependencyKeys: { has: current.taskKey } },
      select: { taskKey: true },
    });
    if (dependents.length)
      throw new AppError(409, `Used as a dependency by: ${dependents.map((d) => d.taskKey).join(", ")}`);
    await tx.taskTemplate.delete({ where: { id } });
    await audit({ adminId, action: "template.deleted", entityType: "task_template", entityId: id, metadata: { taskKey: current.taskKey } }, tx);
  });
}

// ── AI-drafted starter tasks for a proposal (admin edits before saving) ───────

const draftSchema = z.object({
  templates: z
    .array(
      z.object({
        taskKey: z.string().regex(/^[a-z0-9_]+$/).max(60),
        defaultNameEn: z.string().min(1).max(120),
        defaultLeadTimeDays: z.number().int().min(0).max(730),
        typicalOwnerType: z.enum(["organizer", "vendor", "planner"]).default("organizer"),
      })
    )
    .min(1)
    .max(5),
});

export async function draftTemplates(proposalId: string) {
  const proposal = await prisma.categoryProposal.findUnique({ where: { id: proposalId } });
  if (!proposal) throw new AppError(404, "Proposal not found");

  const system =
    'You write starter planning tasks for an event-planning app used by Indian families. Reply with JSON only: {"templates":[{"taskKey":"snake_case","defaultNameEn":"short task name","defaultLeadTimeDays":number,"typicalOwnerType":"organizer"|"vendor"|"planner"}]}. 2 to 4 tasks, practical and specific, lead time = days before the event the task should be done.';
  const user = `Vendor service category: ${proposal.label}${proposal.description ? `\nDescription: ${proposal.description}` : ""}\nEvent type: wedding`;

  let parsed: z.infer<typeof draftSchema>;
  try {
    parsed = draftSchema.parse(JSON.parse(extractJsonPayload(await generateCompletion(system, user))));
  } catch {
    throw new AppError(502, "The AI draft failed. Write the tasks by hand or try again.");
  }

  const taken = new Set(
    (await prisma.taskTemplate.findMany({ select: { taskKey: true } })).map((t) => t.taskKey)
  );
  const templates = parsed.templates.map((t) => {
    let key = t.taskKey;
    for (let i = 2; taken.has(key); i++) key = `${t.taskKey}_${i}`;
    taken.add(key);
    return { ...t, taskKey: key, defaultDependencyKeys: [] as string[] };
  });
  return { templates };
}

// ── Dashboard counts ───────────────────────────────────────────────────────

export async function stats() {
  const weekAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
  const [vendorRows, proposalRows, organizers, events, roadmapsWeek, roadmapsTotal] = await Promise.all([
    prisma.vendor.groupBy({ by: ["status"], _count: true }),
    prisma.categoryProposal.groupBy({ by: ["status"], _count: true }),
    prisma.organizer.count(),
    prisma.eventGroup.count(),
    prisma.roadmapGenerationLog.count({ where: { createdAt: { gte: weekAgo } } }),
    prisma.roadmapGenerationLog.count(),
  ]);
  const vendors = { draft: 0, pending_review: 0, published: 0, rejected: 0, suspended: 0 };
  for (const r of vendorRows) vendors[r.status] = r._count;
  const proposals = { pending: 0, approved: 0, rejected: 0, merged: 0 };
  for (const r of proposalRows) proposals[r.status] = r._count;
  return { vendors, proposals, organizers, events, roadmaps: { lastSevenDays: roadmapsWeek, total: roadmapsTotal } };
}
