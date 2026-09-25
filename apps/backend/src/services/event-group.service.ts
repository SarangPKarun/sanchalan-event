import type { Organizer, Prisma } from "@prisma/client";
import { prisma } from "../lib/prisma.js";
import { AppError } from "../lib/errors.js";
import { toNumber, toDateOnly } from "../lib/serialize.js";
import { getBudgetSplit, computeBudgetAllocations } from "../config/budget-splits.js";
import type { CreateEventGroupInput } from "../schemas/event-group.schema.js";

export function assertProfileComplete(organizer: Organizer): void {
  const missingFields: string[] = [];
  if (!organizer.displayName) missingFields.push("displayName");
  if (!organizer.organizerType) missingFields.push("organizerType");
  if (missingFields.length > 0) {
    throw new AppError(400, "Complete your profile first", { missingFields });
  }
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
  if (!row) throw new AppError(404, "Event not found");
  if (row.organizerId !== organizerId) throw new AppError(403, "Forbidden");
  return serializeEventGroupWithRoadmap(row);
}
