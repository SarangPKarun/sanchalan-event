import { z } from "zod";
import { dateOnlySchema } from "./event-group.schema.js";

export const taskIdParamSchema = z.object({ id: z.string().uuid() });
export type TaskIdParamInput = z.infer<typeof taskIdParamSchema>;

export const updateTaskSchema = z
  .object({
    status: z.enum(["not_started", "in_progress", "done"]).optional(),
    dueDate: dateOnlySchema.nullable().optional(),
    name: z.string().min(1).optional(),
    description: z
      .string()
      .nullable()
      .optional()
      .transform((v) => (v === "" ? null : v)),
  })
  .refine(
    (b) =>
      b.status !== undefined ||
      b.dueDate !== undefined ||
      b.name !== undefined ||
      b.description !== undefined,
    { message: "Provide at least one field to update." }
  );
export type UpdateTaskInput = z.infer<typeof updateTaskSchema>;

export const createTaskSchema = z.object({
  name: z.string().min(1),
  category: z.string().min(1), // taskCategoryId (uuid) OR categoryKey — resolved in the service
  dueDate: dateOnlySchema,
  dependencyTaskIds: z.array(z.string().uuid()).optional(),
});
export type CreateTaskInput = z.infer<typeof createTaskSchema>;
