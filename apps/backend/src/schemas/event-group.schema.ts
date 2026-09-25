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
