import type { EventGroup, Organizer, Prisma } from "@prisma/client";
import { prisma } from "../lib/prisma.js";
import { AppError } from "../lib/errors.js";
import { toNumber, toDateOnly } from "../lib/serialize.js";
import { getBudgetSplit, computeBudgetAllocations } from "../config/budget-splits.js";
import type {
  CreateEventGroupInput,
  UpdateEventGroupInput,
  UpdateBudgetCategoryInput,
  CreateBudgetCategoryInput,
} from "../schemas/event-group.schema.js";

export function assertProfileComplete(organizer: Organizer): void {
  const missingFields: string[] = [];
  if (!organizer.displayName) missingFields.push("displayName");
  if (!organizer.organizerType) missingFields.push("organizerType");
  if (missingFields.length > 0) {
    throw new AppError(400, "Complete your profile first", { missingFields });
  }
}

function assertOwnership<T extends { organizerId: string } | null>(
  eventGroup: T,
  organizerId: string
): asserts eventGroup is NonNullable<T> {
  if (!eventGroup) throw new AppError(404, "Event not found");
  if (eventGroup.organizerId !== organizerId) throw new AppError(403, "Forbidden");
}

export async function getOwnedEventGroupOrThrow(
  organizerId: string,
  eventGroupId: string
): Promise<EventGroup> {
  const eventGroup = await prisma.eventGroup.findUnique({ where: { id: eventGroupId } });
  assertOwnership(eventGroup, organizerId);
  return eventGroup;
}

function computeBudgetWarning(
  totalBudget: number,
  categories: { allocatedAmount: Prisma.Decimal | number }[]
): string | null {
  const allocated = categories.reduce((sum, c) => sum + toNumber(c.allocatedAmount), 0);
  if (allocated <= totalBudget) return null;
  return `Allocated budget (${allocated.toLocaleString()}) exceeds total budget (${totalBudget.toLocaleString()}) by ${(allocated - totalBudget).toLocaleString()}.`;
}

function serializeEventGroup(
  eg: Prisma.EventGroupGetPayload<{ include: { subEvents: true } }>
) {
  return {
    ...eg,
    totalBudget: toNumber(eg.totalBudget),
    primaryDate: toDateOnly(eg.primaryDate),
    subEvents: eg.subEvents.map((se) => ({ ...se, date: toDateOnly(se.date) })),
  };
}

function serializeEventGroupWithDetails(
  eg: Prisma.EventGroupGetPayload<{ include: { subEvents: true; budgetCategories: true } }>
) {
  return {
    ...serializeEventGroup(eg),
    budgetCategories: eg.budgetCategories.map((bc) => ({
      ...bc,
      allocatedAmount: toNumber(bc.allocatedAmount),
    })),
  };
}

function serializeEventGroupWithRoadmap(
  eg: Prisma.EventGroupGetPayload<{
    include: {
      subEvents: true;
      budgetCategories: true;
      tasks: { include: { taskCategory: true; dependentLinks: true } };
    };
  }>
) {
  return {
    ...serializeEventGroupWithDetails(eg),
    // task.dependentLinks (relation "TaskDependents", keyed by taskId) is
    // "rows where this task is the dependent one" — .dependsOnTaskId gives
    // what THIS task depends on, not the reverse.
    tasks: eg.tasks.map((task) => {
      const { taskCategory, dependentLinks, ...rest } = task;
      return {
        ...rest,
        dueDate: rest.dueDate ? toDateOnly(rest.dueDate) : null,
        categoryKey: taskCategory.categoryKey,
        dependsOnTaskIds: dependentLinks.map((d) => d.dependsOnTaskId),
      };
    }),
  };
}

export async function createEventGroup(organizerId: string, input: CreateEventGroupInput) {
  const organizer = await prisma.organizer.findUniqueOrThrow({ where: { id: organizerId } });
  assertProfileComplete(organizer);

  const split = getBudgetSplit(input.eventType, input.region);
  const allocations = computeBudgetAllocations(input.totalBudget, split);
  const primaryDate = new Date(input.primaryDate);

  const created = await prisma.$transaction(async (tx) => {
    const eventGroup = await tx.eventGroup.create({
      data: {
        organizerId,
        eventType: input.eventType,
        name: input.name,
        region: input.region,
        religionOrTradition: input.religionOrTradition ?? null,
        totalBudget: input.totalBudget,
        budgetTier: input.budgetTier,
        guestCountEstimate: input.guestCountEstimate,
        primaryDate,
        status: "planning",
      },
    });

    const subEvent = await tx.subEvent.create({
      data: {
        eventGroupId: eventGroup.id,
        name: input.name,
        date: primaryDate,
        expectedGuestCount: input.guestCountEstimate,
        status: "planned",
      },
    });

    const budgetCategories = await Promise.all(
      Object.entries(allocations).map(([categoryKey, allocatedAmount]) =>
        tx.budgetCategory.create({
          data: { eventGroupId: eventGroup.id, categoryKey, allocatedAmount },
        })
      )
    );

    return { eventGroup, subEvent, budgetCategories };
  });

  return serializeEventGroupWithDetails({
    ...created.eventGroup,
    subEvents: [created.subEvent],
    budgetCategories: created.budgetCategories,
  });
}

export async function listMyEventGroups(organizerId: string) {
  const rows = await prisma.eventGroup.findMany({
    where: { organizerId },
    include: { subEvents: true },
  });
  return rows.map(serializeEventGroup);
}

export async function getEventGroupById(organizerId: string, id: string) {
  const row = await prisma.eventGroup.findUnique({
    where: { id },
    include: {
      subEvents: true,
      budgetCategories: true,
      tasks: { include: { taskCategory: true, dependentLinks: true } },
    },
  });
  assertOwnership(row, organizerId);
  return serializeEventGroupWithRoadmap(row);
}

export async function updateBudgetCategory(
  organizerId: string,
  eventGroupId: string,
  categoryId: string,
  input: UpdateBudgetCategoryInput
) {
  const eventGroup = await getOwnedEventGroupOrThrow(organizerId, eventGroupId);

  const category = await prisma.budgetCategory.findUnique({ where: { id: categoryId } });
  // 404 even if categoryId exists but belongs to a different EventGroup (this
  // organizer's own other event, or someone else's) — not just an organizer check.
  if (!category || category.eventGroupId !== eventGroupId) {
    throw new AppError(404, "Budget category not found");
  }

  const data: Prisma.BudgetCategoryUpdateInput = {};
  if (input.categoryKey !== undefined && input.categoryKey !== category.categoryKey) {
    const clash = await prisma.budgetCategory.findFirst({
      where: { eventGroupId, categoryKey: input.categoryKey, id: { not: categoryId } },
    });
    if (clash) {
      throw new AppError(409, `A budget category "${input.categoryKey}" already exists for this event.`);
    }
    data.categoryKey = input.categoryKey;
  }
  if (input.allocatedAmount !== undefined) data.allocatedAmount = input.allocatedAmount;
  if (input.budgetTierOverride !== undefined) data.budgetTierOverride = input.budgetTierOverride;

  const updated = await prisma.budgetCategory.update({ where: { id: categoryId }, data });
  const allCategories = await prisma.budgetCategory.findMany({ where: { eventGroupId } });

  return {
    budgetCategory: { ...updated, allocatedAmount: toNumber(updated.allocatedAmount) },
    warning: computeBudgetWarning(toNumber(eventGroup.totalBudget), allCategories),
  };
}

export async function createBudgetCategory(
  organizerId: string,
  eventGroupId: string,
  input: CreateBudgetCategoryInput
) {
  const eventGroup = await getOwnedEventGroupOrThrow(organizerId, eventGroupId);

  const existing = await prisma.budgetCategory.findFirst({
    where: { eventGroupId, categoryKey: input.categoryKey },
  });
  if (existing) {
    throw new AppError(
      409,
      `A budget category "${input.categoryKey}" already exists for this event. Use PATCH to edit it.`
    );
  }

  const created = await prisma.budgetCategory.create({ data: { eventGroupId, ...input } });
  const allCategories = await prisma.budgetCategory.findMany({ where: { eventGroupId } });

  return {
    budgetCategory: { ...created, allocatedAmount: toNumber(created.allocatedAmount) },
    warning: computeBudgetWarning(toNumber(eventGroup.totalBudget), allCategories),
  };
}

export async function deleteBudgetCategory(
  organizerId: string,
  eventGroupId: string,
  categoryId: string
) {
  const eventGroup = await getOwnedEventGroupOrThrow(organizerId, eventGroupId);

  const category = await prisma.budgetCategory.findUnique({ where: { id: categoryId } });
  if (!category || category.eventGroupId !== eventGroupId) {
    throw new AppError(404, "Budget category not found");
  }

  const lineCount = await prisma.budgetLine.count({ where: { budgetCategoryId: categoryId } });
  if (lineCount > 0) {
    throw new AppError(
      409,
      `This category has ${lineCount} budget entr${lineCount === 1 ? "y" : "ies"}. Remove them before deleting the category.`
    );
  }

  await prisma.$transaction([
    prisma.task.updateMany({
      where: { linkedBudgetCategoryId: categoryId },
      data: { linkedBudgetCategoryId: null },
    }),
    prisma.budgetCategory.delete({ where: { id: categoryId } }),
  ]);

  const remaining = await prisma.budgetCategory.findMany({ where: { eventGroupId } });
  return {
    budgetCategories: remaining.map((bc) => ({ ...bc, allocatedAmount: toNumber(bc.allocatedAmount) })),
    warning: computeBudgetWarning(toNumber(eventGroup.totalBudget), remaining),
  };
}

export async function updateEventGroup(
  organizerId: string,
  eventGroupId: string,
  input: UpdateEventGroupInput
) {
  const current = await getOwnedEventGroupOrThrow(organizerId, eventGroupId);

  const data: Prisma.EventGroupUpdateInput = {};
  if (input.name !== undefined) data.name = input.name;
  if (input.totalBudget !== undefined) data.totalBudget = input.totalBudget;
  if (input.budgetTier !== undefined) data.budgetTier = input.budgetTier;
  if (input.guestCountEstimate !== undefined) data.guestCountEstimate = input.guestCountEstimate;
  if (input.primaryDate !== undefined) data.primaryDate = new Date(input.primaryDate);

  const oldTotal = toNumber(current.totalBudget);
  const rescale =
    input.budgetAdjustment === "rescale" &&
    input.totalBudget !== undefined &&
    input.totalBudget !== oldTotal;

  const result = await prisma.$transaction(async (tx) => {
    const eventGroup = await tx.eventGroup.update({ where: { id: eventGroupId }, data });

    // The single sub-event is created as a mirror of the event (same name/date/guests);
    // keep it in sync, but leave any sub-event the user customised alone.
    const subEventSync: Prisma.SubEventUpdateManyMutationInput = {};
    if (input.guestCountEstimate !== undefined) subEventSync.expectedGuestCount = input.guestCountEstimate;
    if (Object.keys(subEventSync).length > 0) {
      await tx.subEvent.updateMany({ where: { eventGroupId }, data: subEventSync });
    }
    if (input.name !== undefined && input.name !== current.name) {
      await tx.subEvent.updateMany({
        where: { eventGroupId, name: current.name },
        data: { name: input.name },
      });
    }
    if (input.primaryDate !== undefined) {
      await tx.subEvent.updateMany({
        where: { eventGroupId, date: current.primaryDate },
        data: { date: new Date(input.primaryDate) },
      });
    }

    if (rescale && oldTotal > 0) {
      const categories = await tx.budgetCategory.findMany({ where: { eventGroupId } });
      const ratio = input.totalBudget! / oldTotal;
      const scaled = categories.map((c) => ({
        id: c.id,
        amount: Math.round(toNumber(c.allocatedAmount) * ratio * 100) / 100,
      }));
      // Put the rounding remainder on the largest category so the sum matches the new total.
      const allocatedSum = scaled.reduce((sum, c) => sum + c.amount, 0);
      const remainder = Math.round((input.totalBudget! - allocatedSum) * 100) / 100;
      const largest = scaled.reduce((a, b) => (b.amount > a.amount ? b : a), scaled[0]!);
      if (scaled.length > 0 && remainder !== 0) largest.amount = Math.round((largest.amount + remainder) * 100) / 100;
      for (const c of scaled) {
        await tx.budgetCategory.update({ where: { id: c.id }, data: { allocatedAmount: c.amount } });
      }
    }

    const budgetCategories = await tx.budgetCategory.findMany({ where: { eventGroupId } });
    return { eventGroup, budgetCategories };
  });

  return {
    eventGroup: {
      ...result.eventGroup,
      totalBudget: toNumber(result.eventGroup.totalBudget),
      primaryDate: toDateOnly(result.eventGroup.primaryDate),
    },
    budgetCategories: result.budgetCategories.map((bc) => ({
      ...bc,
      allocatedAmount: toNumber(bc.allocatedAmount),
    })),
    warning: computeBudgetWarning(toNumber(result.eventGroup.totalBudget), result.budgetCategories),
  };
}
