// Runtime copy of the vendor-profile limits in packages/shared-types/src/vendor-self.ts.
// The backend can only import *types* from @sanchalan/shared-types: that package ships
// TypeScript source, which Node can't run in production (type imports are erased at build).
// Keep these values in sync with the shared-types constants by hand.
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
