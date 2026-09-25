import { z } from "zod";

const dateOnlySchema = z.string().regex(/^\d{4}-\d{2}-\d{2}$/, "primaryDate must be YYYY-MM-DD");

export const createEventGroupSchema = z.object({
  eventType: z.enum(["wedding", "birthday", "corporate", "religious", "engagement_only", "custom"]),
  name: z.string().min(1),
  region: z.string().min(1),
  religionOrTradition: z.string().min(1).optional(),
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

export const updateBudgetCategorySchema = z
  .object({
    allocatedAmount: z.number().positive().optional(),
    budgetTierOverride: z.enum(["essential", "standard", "premium", "luxury"]).optional(),
  })
  .refine((b) => b.allocatedAmount !== undefined || b.budgetTierOverride !== undefined, {
    message: "Provide at least one of allocatedAmount or budgetTierOverride.",
  });
export type UpdateBudgetCategoryInput = z.infer<typeof updateBudgetCategorySchema>;

export const createBudgetCategorySchema = z.object({
  categoryKey: z.string().min(1),
  allocatedAmount: z.number().positive(),
});
export type CreateBudgetCategoryInput = z.infer<typeof createBudgetCategorySchema>;
