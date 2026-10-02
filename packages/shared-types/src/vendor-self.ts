import type { VendorPriceTier } from "./enums.js";
import type { VendorWithPortfolio } from "./vendor.js";

/** Display labels for vendor category keys (VendorCategory has no label column). */
export const VENDOR_CATEGORY_LABELS: Record<string, string> = {
  venue: "Venue",
  catering: "Catering",
  decor: "Décor",
  photography: "Photography",
  attire: "Attire",
  invitations: "Invitations",
  music_entertainment: "Music & Entertainment",
  priest_officiant: "Priest / Officiant",
  transport: "Transport",
  misc: "Other",
};

export function vendorCategoryLabel(categoryKey: string): string {
  return (
    VENDOR_CATEGORY_LABELS[categoryKey] ??
    categoryKey.replace(/_/g, " ").replace(/^\w/, (c) => c.toUpperCase())
  );
}

export const VENDOR_PRICE_TIER_LABELS: Record<VendorPriceTier, string> = {
  essential: "Essential",
  standard: "Standard",
  premium: "Premium",
  luxury: "Luxury",
};

export const VENDOR_MAX_CATEGORIES = 5;
export const VENDOR_MAX_PAST_WORK = 10;
export const VENDOR_DESCRIPTION_MIN = 30;
export const VENDOR_DESCRIPTION_MAX = 1000;

/** Fields whose change on a published vendor sends the profile back to review. */
export const VENDOR_REVIEW_TRIGGER_FIELDS = [
  "businessName",
  "serviceArea",
  "priceTier",
  "description",
] as const;

export type VendorRequiredField =
  | "businessName"
  | "contactPersonName"
  | "priceTier"
  | "serviceArea"
  | "description"
  | "categories"
  | "pastWork";

export interface VendorCompleteness {
  complete: boolean;
  missing: VendorRequiredField[];
}

export interface VendorMeResponse extends VendorWithPortfolio {
  completeness: VendorCompleteness;
}

export interface UpdateVendorProfileBody {
  businessName?: string;
  contactPersonName?: string;
  email?: string | null;
  priceTier?: VendorPriceTier;
  serviceArea?: string;
  description?: string;
  yearsOfExperience?: number | null;
  startingPrice?: number | null;
  instagramUrl?: string | null;
  websiteUrl?: string | null;
  whatsappNumber?: string | null;
}

export interface UpdateVendorProfileResponse {
  vendor: VendorMeResponse;
  /** True when this edit moved a published vendor back to pending_review. */
  reverificationTriggered: boolean;
}

export interface SetVendorCategoriesBody {
  categoryKeys: string[];
}

export interface PastWorkBody {
  title: string;
  caption?: string | null;
}

export interface ReorderPastWorkBody {
  itemIds: string[];
}

export interface VendorCategoryListItem {
  id: string;
  categoryKey: string;
}

export interface ListVendorCategoriesResponse {
  categories: VendorCategoryListItem[];
}
