import { randomUUID } from "node:crypto";
import type { Prisma, Task } from "@prisma/client";
import { prisma } from "../lib/prisma.js";
import { AppError } from "../lib/errors.js";
import { toDateOnly } from "../lib/serialize.js";
import { getOwnedEventGroupOrThrow } from "./event-group.service.js";
import type { UpdateTaskInput, CreateTaskInput } from "../schemas/task.schema.js";

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function serializeTask(t: Task) {
  return { ...t, dueDate: t.dueDate ? toDateOnly(t.dueDate) : null };
}

export async function getOwnedTaskOrThrow(organizerId: string, taskId: string): Promise<Task> {
  const task = await prisma.task.findUnique({ where: { id: taskId } });
  if (!task) throw new AppError(404, "Task not found");
  // Reuses the existing ownership check rather than re-implementing it —
  // throws 404/403 exactly as getOwnedEventGroupOrThrow already does.
  await getOwnedEventGroupOrThrow(organizerId, task.eventGroupId);
  return task;
}

export async function updateTask(organizerId: string, taskId: string, input: UpdateTaskInput) {
  const current = await getOwnedTaskOrThrow(organizerId, taskId);

  // Only fields actually present in the parsed body are considered — Zod's
  // .parse() output omits keys the client didn't send, so `key in input` is
  // exactly "the fields the client touched." This distinguishes "omitted"
  // (leave alone) from "explicitly null" (clear it, e.g. dueDate).
  const previousValue: Record<string, unknown> = {};
  const newValue: Record<string, unknown> = {};
  const data: Prisma.TaskUpdateInput = {};

  if ("status" in input && input.status !== undefined && input.status !== current.status) {
    previousValue.status = current.status;
    newValue.status = input.status;
    data.status = input.status;
  }
  if ("dueDate" in input) {
    const currentStr = current.dueDate ? toDateOnly(current.dueDate) : null;
    if (input.dueDate !== currentStr) {
      previousValue.dueDate = currentStr;
      newValue.dueDate = input.dueDate;
      data.dueDate = input.dueDate ? new Date(input.dueDate) : null;
    }
  }
  if ("name" in input && input.name !== undefined && input.name !== current.name) {
    previousValue.name = current.name;
    newValue.name = input.name;
    data.name = input.name;
  }
  if (
    "description" in input &&
    input.description !== undefined &&
    input.description !== current.description
  ) {
    previousValue.description = current.description;
    newValue.description = input.description;
    data.description = input.description;
  }

  if (Object.keys(data).length === 0) {
    return serializeTask(current); // no-op save, no TaskEditLog row
  }

  const action = "status" in newValue ? "status_changed" : "edited";

  const updated = await prisma.$transaction(async (tx) => {
    const row = await tx.task.update({ where: { id: taskId }, data });
    await tx.taskEditLog.create({
      data: {
        taskId,
        eventGroupId: current.eventGroupId,
        action,
        previousValue: previousValue as Prisma.InputJsonValue,
        newValue: newValue as Prisma.InputJsonValue,
        changedBy: organizerId,
        changedAt: new Date(),
      },
    });
    return row;
  });

  return serializeTask(updated);
}

export async function deleteTask(organizerId: string, taskId: string) {
  const current = await getOwnedTaskOrThrow(organizerId, taskId);
  if (current.status === "not_applicable") {
    return serializeTask(current); // idempotent — no duplicate log row
  }

  const updated = await prisma.$transaction(async (tx) => {
    const row = await tx.task.update({
      where: { id: taskId },
      data: { status: "not_applicable" },
    });
    await tx.taskEditLog.create({
      data: {
        taskId,
        eventGroupId: current.eventGroupId,
        action: "marked_not_applicable",
        previousValue: { status: current.status } as Prisma.InputJsonValue,
        newValue: { status: "not_applicable" } as Prisma.InputJsonValue,
        changedBy: organizerId,
        changedAt: new Date(),
      },
    });
    return row;
  });

  return serializeTask(updated);
}

export async function createTask(
  organizerId: string,
  eventGroupId: string,
  input: CreateTaskInput
) {
  await getOwnedEventGroupOrThrow(organizerId, eventGroupId);

  const category = UUID_RE.test(input.category)
    ? await prisma.taskCategory.findUnique({ where: { id: input.category } })
    : await prisma.taskCategory.findUnique({ where: { categoryKey: input.category } });
  if (!category) throw new AppError(400, `Unknown task category "${input.category}"`);

  const dependencyTaskIds = input.dependencyTaskIds ?? [];
  if (dependencyTaskIds.length > 0) {
    const deps = await prisma.task.findMany({
      where: { id: { in: dependencyTaskIds } },
      select: { id: true, eventGroupId: true },
    });
    const foundIds = new Set(deps.map((d) => d.id));
    const missing = dependencyTaskIds.filter((id) => !foundIds.has(id));
    if (missing.length > 0) {
      throw new AppError(400, "One or more dependencyTaskIds do not exist", { missing });
    }
    const crossEvent = deps.filter((d) => d.eventGroupId !== eventGroupId);
    if (crossEvent.length > 0) {
      throw new AppError(400, "dependencyTaskIds must belong to the same event", {
        crossEvent: crossEvent.map((d) => d.id),
      });
    }
  }

  const taskId = randomUUID();
  const created = await prisma.$transaction(async (tx) => {
    const row = await tx.task.create({
      data: {
        id: taskId,
        eventGroupId,
        taskCategoryId: category.id,
        name: input.name,
        description: null,
        status: "not_started",
        dueDate: new Date(input.dueDate),
        source: "user_added",
        ownerType: "organizer",
      },
    });
    if (dependencyTaskIds.length > 0) {
      await tx.taskDependency.createMany({
        data: dependencyTaskIds.map((dependsOnTaskId) => ({ taskId, dependsOnTaskId })),
      });
    }
    await tx.taskEditLog.create({
      data: {
        taskId,
        eventGroupId,
        action: "created",
        newValue: {
          name: input.name,
          taskCategoryId: category.id,
          dueDate: input.dueDate,
          status: "not_started",
          source: "user_added",
          ownerType: "organizer",
          dependencyTaskIds,
        } as Prisma.InputJsonValue,
        changedBy: organizerId,
        changedAt: new Date(),
      },
    });
    return row;
  });

  return {
    ...serializeTask(created),
    categoryKey: category.categoryKey,
    dependsOnTaskIds: dependencyTaskIds,
    dependentTaskIds: [] as string[],
  };
}

export async function listEventGroupTasks(organizerId: string, eventGroupId: string) {
  await getOwnedEventGroupOrThrow(organizerId, eventGroupId);

  const rows = await prisma.task.findMany({
    where: { eventGroupId, status: { not: "not_applicable" } },
    include: { taskCategory: true, dependentLinks: true, dependencyLinks: true },
    // dueDate ASC puts NULLs last on Postgres — undated tasks sort to the
    // end of their category rather than jumping to the top.
    orderBy: [{ taskCategory: { categoryKey: "asc" } }, { dueDate: "asc" }],
  });

  return rows.map((t) => {
    const { taskCategory, dependentLinks, dependencyLinks, ...rest } = t;
    return {
      ...serializeTask(rest),
      categoryKey: taskCategory.categoryKey,
      // dependentLinks: rows where I am `taskId` -> .dependsOnTaskId = what I depend on.
      dependsOnTaskIds: dependentLinks.map((d) => d.dependsOnTaskId),
      // dependencyLinks: rows where I am `dependsOnTaskId` -> .taskId = what depends on me.
      dependentTaskIds: dependencyLinks.map((d) => d.taskId),
    };
  });
}
