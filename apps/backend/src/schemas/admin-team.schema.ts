import { z } from "zod";

const roleSchema = z.enum(["super_admin", "vendor_reviewer", "support"]);

export const createAdminSchema = z.object({
  name: z.string().trim().min(1).max(100),
  email: z.string().trim().toLowerCase().email(),
  role: roleSchema,
});

export const updateAdminSchema = z
  .object({ role: roleSchema.optional(), status: z.enum(["active", "disabled"]).optional() })
  .refine((v) => v.role !== undefined || v.status !== undefined, "Nothing to update");

export const adminIdParamSchema = z.object({ id: z.string().uuid() });

export const PASSWORD_MIN = 12;
export const changePasswordSchema = z.object({
  currentPassword: z.string().min(1).max(200),
  newPassword: z.string().min(PASSWORD_MIN).max(72),
});
