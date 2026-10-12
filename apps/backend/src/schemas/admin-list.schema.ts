import { z } from "zod";

export const pageQuery = {
  page: z.coerce.number().int().min(1).default(1),
  pageSize: z.coerce.number().int().min(1).max(100).default(20),
  q: z.string().trim().max(100).optional(),
};

export const listVendorsQuerySchema = z.object({
  status: z.enum(["draft", "pending_review", "published", "rejected", "suspended"]).optional(),
  category: z.string().max(60).optional(),
  priceTier: z.enum(["essential", "standard", "premium", "luxury"]).optional(),
  sort: z.enum(["oldest", "newest", "name"]).optional(),
  ...pageQuery,
});
export type ListVendorsQuery = z.infer<typeof listVendorsQuerySchema>;

export const listProposalsQuerySchema = z.object({
  status: z.enum(["pending", "approved", "rejected", "merged"]).optional(),
  ...pageQuery,
});
export type ListProposalsQuery = z.infer<typeof listProposalsQuerySchema>;

export const bulkVendorSchema = z.discriminatedUnion("action", [
  z.object({ action: z.literal("approve"), ids: z.array(z.string().uuid()).min(1).max(50) }),
  z.object({
    action: z.literal("reject"),
    ids: z.array(z.string().uuid()).min(1).max(50),
    reason: z.string().trim().min(1).max(1000),
  }),
]);

const eventType = z.enum(["wedding", "birthday", "corporate", "religious", "engagement_only", "custom"]);

export const updateCategorySchema = z
  .object({
    label: z.string().trim().min(2).max(40).optional(),
    applicableEventTypes: z.array(eventType).min(1).optional(),
    isActive: z.boolean().optional(),
  })
  .refine((v) => Object.keys(v).length > 0, "Nothing to update");

export const templateBodySchema = z.object({
  eventType,
  taskKey: z.string().trim().regex(/^[a-z0-9_]+$/, "Use lowercase letters, numbers and underscores").max(60),
  defaultNameEn: z.string().trim().min(1).max(120),
  defaultLeadTimeDays: z.number().int().min(0).max(730),
  defaultDependencyKeys: z.array(z.string()).max(20).default([]),
  typicalOwnerType: z.enum(["organizer", "vendor", "planner"]).default("organizer"),
});
export const createTemplateSchema = templateBodySchema.extend({ categoryKey: z.string().min(1).max(60) });
export const updateTemplateSchema = templateBodySchema.omit({ eventType: true }).partial();

export const keyParamSchema = z.object({ key: z.string().min(1).max(60) });
export const idParamSchema = z.object({ id: z.string().uuid() });
export const templatesQuerySchema = z.object({ category: z.string().max(60).optional() });

export const listOrganizersQuerySchema = z.object({
  status: z.enum(["active", "suspended"]).optional(),
  ...pageQuery,
});
export const listEventsQuerySchema = z.object({
  status: z.enum(["planning", "active", "completed", "archived"]).optional(),
  eventType: eventType.optional(),
  ...pageQuery,
});
export const listRoadmapLogsQuerySchema = z.object({
  status: z.enum(["success", "failed"]).optional(),
  page: pageQuery.page,
  pageSize: pageQuery.pageSize,
});
export const auditQuerySchema = z.object({
  adminId: z.string().uuid().optional(),
  action: z.string().max(80).optional(),
  entityType: z.string().max(60).optional(),
  from: z.coerce.date().optional(),
  to: z.coerce.date().optional(),
  page: pageQuery.page,
  pageSize: pageQuery.pageSize,
});
export const suspendOrganizerSchema = z.object({ reason: z.string().trim().min(1).max(1000) });
