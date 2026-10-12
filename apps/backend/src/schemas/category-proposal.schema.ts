import { z } from "zod";

export const proposeCategorySchema = z.object({
  label: z.string().trim().min(3).max(40),
  description: z.string().trim().max(300).optional(),
});
export type ProposeCategoryInput = z.infer<typeof proposeCategorySchema>;

export const proposalIdParamSchema = z.object({ id: z.string().uuid() });

export const listProposalsQuerySchema = z.object({
  status: z.enum(["pending", "approved", "rejected", "merged"]).optional(),
});

const eventTypeSchema = z.enum(["wedding"]);

const templateSchema = z.object({
  taskKey: z.string().trim().regex(/^[a-z0-9_]+$/).max(60),
  defaultNameEn: z.string().trim().min(1).max(120),
  defaultLeadTimeDays: z.number().int().min(0).max(730),
  defaultDependencyKeys: z.array(z.string()).default([]),
  typicalOwnerType: z.enum(["organizer", "vendor", "planner"]).default("organizer"),
});

export const approveProposalSchema = z.object({
  label: z.string().trim().min(3).max(40),
  applicableEventTypes: z.array(eventTypeSchema).min(1).default(["wedding"]),
  templates: z.array(templateSchema).min(1).max(10),
});
export type ApproveProposalInput = z.infer<typeof approveProposalSchema>;

export const rejectProposalSchema = z.object({ reason: z.string().trim().min(1).max(1000) });
export const mergeProposalSchema = z.object({ vendorCategoryId: z.string().uuid() });
