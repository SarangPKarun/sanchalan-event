import { z } from "zod";
import { VENDOR_DESCRIPTION_MAX, VENDOR_MAX_CATEGORIES } from "../lib/vendor-limits.js";

const trimmed = (max: number) => z.string().trim().min(1).max(max);
const optionalUrl = z
  .string()
  .trim()
  .max(300)
  .url()
  .refine((u) => /^https?:\/\//i.test(u), "Must be an http(s) URL")
  .nullable();

export const updateVendorProfileSchema = z
  .object({
    businessName: trimmed(120),
    contactPersonName: trimmed(120),
    email: z.string().trim().email().max(200).nullable(),
    priceTier: z.enum(["essential", "standard", "premium", "luxury"]),
    serviceArea: trimmed(200),
    description: z.string().trim().min(1).max(VENDOR_DESCRIPTION_MAX),
    yearsOfExperience: z.number().int().min(0).max(80).nullable(),
    startingPrice: z.number().int().min(0).max(100_000_000).nullable(),
    instagramUrl: optionalUrl,
    websiteUrl: optionalUrl,
    whatsappNumber: z
      .string()
      .trim()
      .regex(/^\+[1-9]\d{7,14}$/, "Must be E.164, e.g. +919876543210")
      .nullable(),
  })
  .partial()
  .strict();
export type UpdateVendorProfileInput = z.infer<typeof updateVendorProfileSchema>;

export const setVendorCategoriesSchema = z.object({
  categoryKeys: z
    .array(z.string().min(1))
    .min(1)
    .max(VENDOR_MAX_CATEGORIES)
    .refine((keys) => new Set(keys).size === keys.length, "Duplicate categories"),
});
export type SetVendorCategoriesInput = z.infer<typeof setVendorCategoriesSchema>;

export const pastWorkSchema = z.object({
  title: trimmed(150),
  caption: z.string().trim().max(500).nullable().optional(),
});
export type PastWorkInput = z.infer<typeof pastWorkSchema>;

export const updatePastWorkSchema = pastWorkSchema.partial().strict();
export type UpdatePastWorkInput = z.infer<typeof updatePastWorkSchema>;

export const reorderPastWorkSchema = z.object({
  itemIds: z.array(z.string().uuid()).min(1),
});
export type ReorderPastWorkInput = z.infer<typeof reorderPastWorkSchema>;

export const pastWorkIdParamSchema = z.object({ itemId: z.string().uuid() });
