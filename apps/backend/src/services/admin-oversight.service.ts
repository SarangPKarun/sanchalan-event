import type { Prisma } from "@prisma/client";
import { prisma } from "../lib/prisma.js";
import { AppError } from "../lib/errors.js";
import { audit } from "../lib/audit.js";
import type { z } from "zod";
import type {
  auditQuerySchema,
  listEventsQuerySchema,
  listOrganizersQuerySchema,
  listRoadmapLogsQuerySchema,
} from "../schemas/admin-list.schema.js";

type Page = { page: number; pageSize: number };
const paging = (f: Page) => ({ skip: (f.page - 1) * f.pageSize, take: f.pageSize });

// ── Organizers (families) ──────────────────────────────────────────────────

export async function listOrganizers(f: z.infer<typeof listOrganizersQuerySchema>) {
  const where: Prisma.OrganizerWhereInput = {
    ...(f.status ? { status: f.status } : {}),
    ...(f.q
      ? {
          OR: [
            { displayName: { contains: f.q, mode: "insensitive" } },
            { phoneNumber: { contains: f.q } },
            { email: { contains: f.q, mode: "insensitive" } },
          ],
        }
      : {}),
  };
  const [total, rows] = await Promise.all([
    prisma.organizer.count({ where }),
    prisma.organizer.findMany({
      where,
      include: { _count: { select: { eventGroups: true } } },
      orderBy: [{ createdAt: "desc" }, { id: "asc" }],
      ...paging(f),
    }),
  ]);
  // Last sign-in = newest refresh token, the closest thing to "last active" we record.
  const seen = await prisma.refreshToken.groupBy({
    by: ["userId"],
    where: { role: "organizer", userId: { in: rows.map((r) => r.id) } },
    _max: { createdAt: true },
  });
  const lastSeen = new Map(seen.map((s) => [s.userId, s._max.createdAt]));
  return {
    organizers: rows.map((o) => ({ ...o, lastSignInAt: lastSeen.get(o.id) ?? null })),
    total,
    page: f.page,
    pageSize: f.pageSize,
  };
}

export async function getOrganizer(id: string) {
  const organizer = await prisma.organizer.findUnique({
    where: { id },
    include: {
      eventGroups: {
        orderBy: { primaryDate: "desc" },
        include: { _count: { select: { tasks: true, guests: true } } },
      },
    },
  });
  if (!organizer) throw new AppError(404, "Organizer not found");
  const suspension = await prisma.adminAuditLog.findFirst({
    where: { entityType: "organizer", entityId: id, action: "organizer.suspended" },
    orderBy: { createdAt: "desc" },
    select: { metadata: true, createdAt: true, admin: { select: { name: true } } },
  });
  return { ...organizer, suspension: organizer.status === "suspended" ? suspension : null };
}

export async function setOrganizerStatus(adminId: string, id: string, to: "active" | "suspended", reason?: string) {
  return prisma.$transaction(async (tx) => {
    const from = to === "suspended" ? "active" : "suspended";
    const { count } = await tx.organizer.updateMany({ where: { id, status: from }, data: { status: to } });
    if (count === 0) {
      const exists = await tx.organizer.findUnique({ where: { id }, select: { id: true } });
      throw exists ? new AppError(409, `Organizer is already ${to === "suspended" ? "suspended" : "active"}`) : new AppError(404, "Organizer not found");
    }
    if (to === "suspended")
      await tx.refreshToken.updateMany({ where: { userId: id, role: "organizer", revokedAt: null }, data: { revokedAt: new Date() } });
    await audit(
      { adminId, action: `organizer.${to === "suspended" ? "suspended" : "unsuspended"}`, entityType: "organizer", entityId: id, ...(reason ? { metadata: { reason } } : {}) },
      tx
    );
    return tx.organizer.findUniqueOrThrow({ where: { id } });
  });
}

// ── Events ─────────────────────────────────────────────────────────────────

export async function listEvents(f: z.infer<typeof listEventsQuerySchema>) {
  const where: Prisma.EventGroupWhereInput = {
    ...(f.status ? { status: f.status } : {}),
    ...(f.eventType ? { eventType: f.eventType } : {}),
    ...(f.q
      ? {
          OR: [
            { name: { contains: f.q, mode: "insensitive" } },
            { region: { contains: f.q, mode: "insensitive" } },
            { organizer: { displayName: { contains: f.q, mode: "insensitive" } } },
            { organizer: { phoneNumber: { contains: f.q } } },
          ],
        }
      : {}),
  };
  const [total, events] = await Promise.all([
    prisma.eventGroup.count({ where }),
    prisma.eventGroup.findMany({
      where,
      include: {
        organizer: { select: { id: true, displayName: true, phoneNumber: true } },
        _count: { select: { tasks: true, guests: true } },
      },
      orderBy: [{ createdAt: "desc" }, { id: "asc" }],
      ...paging(f),
    }),
  ]);
  return { events, total, page: f.page, pageSize: f.pageSize };
}

export async function getEvent(id: string) {
  const event = await prisma.eventGroup.findUnique({
    where: { id },
    include: {
      organizer: { select: { id: true, displayName: true, phoneNumber: true, status: true } },
      subEvents: { orderBy: { date: "asc" } },
      tasks: {
        orderBy: [{ dueDate: "asc" }, { createdAt: "asc" }],
        include: {
          taskCategory: { select: { categoryKey: true, label: true } },
          linkedVendor: { select: { id: true, businessName: true } },
        },
      },
      budgetCategories: { include: { budgetLines: false } },
      roadmapGenerationLogs: {
        orderBy: { createdAt: "desc" },
        select: { id: true, status: true, createdAt: true, llmModelUsed: true, inputTokens: true, outputTokens: true },
      },
    },
  });
  if (!event) throw new AppError(404, "Event not found");

  const lines = await prisma.budgetLine.findMany({
    where: { budgetCategory: { eventGroupId: id } },
    include: { budgetCategory: { select: { categoryKey: true } }, linkedVendor: { select: { id: true, businessName: true } } },
    orderBy: { createdAt: "asc" },
  });
  return { ...event, budgetLines: lines };
}

// ── Roadmap generation review ──────────────────────────────────────────────

export async function listRoadmapLogs(f: z.infer<typeof listRoadmapLogsQuerySchema>) {
  const where: Prisma.RoadmapGenerationLogWhereInput = f.status ? { status: f.status } : {};
  const [total, logs] = await Promise.all([
    prisma.roadmapGenerationLog.count({ where }),
    prisma.roadmapGenerationLog.findMany({
      where,
      select: {
        id: true,
        status: true,
        error: true,
        createdAt: true,
        llmModelUsed: true,
        latencyMs: true,
        attempts: true,
        inputTokens: true,
        outputTokens: true,
        inputParams: true,
        templateIdsUsed: true,
        eventGroup: { select: { id: true, name: true } },
      },
      orderBy: [{ createdAt: "desc" }, { id: "asc" }],
      ...paging(f),
    }),
  ]);
  return { logs, total, page: f.page, pageSize: f.pageSize };
}

export async function getRoadmapLog(id: string) {
  const log = await prisma.roadmapGenerationLog.findUnique({
    where: { id },
    include: { eventGroup: { select: { id: true, name: true } } },
  });
  if (!log) throw new AppError(404, "Log not found");
  const templates = await prisma.taskTemplate.findMany({
    where: { id: { in: log.templateIdsUsed } },
    select: { id: true, taskKey: true, defaultNameEn: true },
  });
  return { ...log, templates };
}

/**
 * Which starter tasks people change most: input for improving the base templates.
 * Looks at the newest edits only, to keep the query bounded.
 */
export async function taskEditStats(days = 90) {
  const since = new Date(Date.now() - days * 24 * 60 * 60 * 1000);
  const logs = await prisma.taskEditLog.findMany({
    where: { changedAt: { gte: since }, task: { source: { not: "user_added" } } },
    select: { action: true, task: { select: { name: true, taskCategory: { select: { categoryKey: true } } } } },
    orderBy: { changedAt: "desc" },
    take: 20_000,
  });
  const byAction: Record<string, number> = {};
  const byTask = new Map<string, { name: string; category: string; edited: number; removed: number; statusChanged: number; total: number }>();
  for (const l of logs) {
    byAction[l.action] = (byAction[l.action] ?? 0) + 1;
    const key = `${l.task.taskCategory.categoryKey}::${l.task.name}`;
    const row = byTask.get(key) ?? { name: l.task.name, category: l.task.taskCategory.categoryKey, edited: 0, removed: 0, statusChanged: 0, total: 0 };
    if (l.action === "edited") row.edited++;
    else if (l.action === "deleted" || l.action === "marked_not_applicable") row.removed++;
    else if (l.action === "status_changed") row.statusChanged++;
    row.total++;
    byTask.set(key, row);
  }
  const topChanged = [...byTask.values()]
    .filter((r) => r.edited + r.removed > 0)
    .sort((a, b) => b.edited + b.removed - (a.edited + a.removed))
    .slice(0, 25);
  return { days, byAction, topChanged, truncated: logs.length === 20_000 };
}

// ── Audit log ──────────────────────────────────────────────────────────────

function auditWhere(f: z.infer<typeof auditQuerySchema>): Prisma.AdminAuditLogWhereInput {
  return {
    ...(f.adminId ? { adminId: f.adminId } : {}),
    ...(f.action ? { action: { contains: f.action } } : {}),
    ...(f.entityType ? { entityType: f.entityType } : {}),
    ...(f.from || f.to ? { createdAt: { ...(f.from ? { gte: f.from } : {}), ...(f.to ? { lte: f.to } : {}) } } : {}),
  };
}

export async function listAudit(f: z.infer<typeof auditQuerySchema>) {
  const where = auditWhere(f);
  const [total, entries] = await Promise.all([
    prisma.adminAuditLog.count({ where }),
    prisma.adminAuditLog.findMany({
      where,
      include: { admin: { select: { id: true, name: true } } },
      orderBy: [{ createdAt: "desc" }, { id: "asc" }],
      ...paging(f),
    }),
  ]);
  return { entries, total, page: f.page, pageSize: f.pageSize };
}

const csvCell = (v: unknown) => {
  let s = v == null ? "" : typeof v === "string" ? v : JSON.stringify(v);
  // Neutralise spreadsheet formula injection from admin-typed text such as rejection reasons.
  if (/^[=+\-@\t\r]/.test(s)) s = `'${s}`;
  return `"${s.replace(/"/g, '""')}"`;
};

export async function auditCsv(f: z.infer<typeof auditQuerySchema>) {
  const entries = await prisma.adminAuditLog.findMany({
    where: auditWhere(f),
    include: { admin: { select: { name: true, email: true } } },
    orderBy: { createdAt: "desc" },
    take: 10_000,
  });
  const header = ["time", "admin", "admin_email", "action", "entity_type", "entity_id", "ip", "details"];
  const rows = entries.map((e) =>
    [e.createdAt.toISOString(), e.admin?.name, e.admin?.email, e.action, e.entityType, e.entityId, e.ip, e.metadata].map(csvCell).join(",")
  );
  return [header.join(","), ...rows].join("\n");
}
