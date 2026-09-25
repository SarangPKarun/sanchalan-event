import { z } from "zod";

export { vendorIdParamSchema } from "./admin-vendor.schema.js";

const vendorPriceTierSchema = z.enum(["essential", "standard", "premium", "luxury"]);

export const listVendorsQuerySchema = z.object({
  category: z.string().min(1).optional(),
  priceTier: vendorPriceTierSchema.optional(),
  region: z.string().min(1).optional(),
});
export type ListVendorsQueryInput = z.infer<typeof listVendorsQuerySchema>;
