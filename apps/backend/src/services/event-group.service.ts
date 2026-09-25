import type { EventGroup, Organizer, Prisma } from "@prisma/client";
import { prisma } from "../lib/prisma.js";
import { AppError } from "../lib/errors.js";
import { toNumber, toDateOnly } from "../lib/serialize.js";
import { getBudgetSplit, computeBudgetAllocations } from "../config/budget-splits.js";
import type {
  CreateEventGroupInput,
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
