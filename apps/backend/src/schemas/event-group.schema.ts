import { z } from "zod";

export const dateOnlySchema = z.string().regex(/^\d{4}-\d{2}-\d{2}$/, "must be YYYY-MM-DD");

export const createEventGroupSchema = z.object({
  eventType: z.enum(["wedding", "birthday", "corporate", "religious", "engagement_only", "custom"]),
  name: z.string().min(1),
  region: z.string().min(1),
  religionOrTradition: z.string().min(1).optional(),
  // Type-specific wizard answers; checked against the event type's profile in the service.
  details: z.record(z.string(), z.unknown()).optional(),
  // Set when a `custom` event was created from an LLM-written question set.
  generatedProfileId: z.string().uuid().optional(),
  totalBudget: z.number().positive(),
  budgetTier: z.enum(["essential", "standard", "premium", "luxury"]),
  guestCountEstimate: z.number().int().positive(),
  primaryDate: dateOnlySchema,
});
export type CreateEventGroupInput = z.infer<typeof createEventGroupSchema>;

export const idParamSchema = z.object({ id: z.string().uuid() });
export type IdParamInput = z.infer<typeof idParamSchema>;

export const categoryIdParamSchema = z.object({
  id: z.string().uuid(),
  categoryId: z.string().uuid(),
});
export type CategoryIdParamInput = z.infer<typeof categoryIdParamSchema>;

export const updateEventGroupSchema = z
  .object({
    name: z.string().min(1).optional(),
    totalBudget: z.number().positive().optional(),
    budgetTier: z.enum(["essential", "standard", "premium", "luxury"]).optional(),
    guestCountEstimate: z.number().int().positive().optional(),
    primaryDate: dateOnlySchema.optional(),
    // Only used when totalBudget changes: scale every category by the same ratio, or leave them.
    budgetAdjustment: z.enum(["rescale", "keep"]).optional(),
  })
  .refine(
    (b) =>
      b.name !== undefined ||
      b.totalBudget !== undefined ||
      b.budgetTier !== undefined ||
      b.guestCountEstimate !== undefined ||
      b.primaryDate !== undefined,
    { message: "Provide at least one field to update." }
  );
export type UpdateEventGroupInput = z.infer<typeof updateEventGroupSchema>;

export const updateBudgetCategorySchema = z
  .object({
    allocatedAmount: z.number().positive().optional(),
    budgetTierOverride: z.enum(["essential", "standard", "premium", "luxury"]).optional(),
    categoryKey: z.string().min(1).optional(),
  })
  .refine(
    (b) =>
      b.allocatedAmount !== undefined ||
      b.budgetTierOverride !== undefined ||
      b.categoryKey !== undefined,
    { message: "Provide at least one of allocatedAmount, budgetTierOverride or categoryKey." }
  );
export type UpdateBudgetCategoryInput = z.infer<typeof updateBudgetCategorySchema>;

export const createBudgetCategorySchema = z.object({
  categoryKey: z.string().min(1),
  allocatedAmount: z.number().positive(),
});
export type CreateBudgetCategoryInput = z.infer<typeof createBudgetCategorySchema>;
