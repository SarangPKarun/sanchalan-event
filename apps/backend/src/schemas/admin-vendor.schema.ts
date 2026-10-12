import { z } from "zod";

export const vendorIdParamSchema = z.object({
  id: z.string().uuid(),
});
export type VendorIdParamInput = z.infer<typeof vendorIdParamSchema>;

export const rejectVendorSchema = z.object({
  reason: z.string().trim().min(1).max(1000),
});
export type RejectVendorInput = z.infer<typeof rejectVendorSchema>;

export const suspendVendorSchema = rejectVendorSchema;
