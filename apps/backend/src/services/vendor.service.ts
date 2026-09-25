import type { VendorPriceTier } from "@sanchalan/shared-types";
import { prisma } from "../lib/prisma.js";
import { AppError } from "../lib/errors.js";
import { VENDOR_WITH_PORTFOLIO_INCLUDE } from "./vendor-query.helpers.js";

export interface ListPublishedVendorsFilters {
  category?: string | undefined;
  priceTier?: VendorPriceTier | undefined;
  region?: string | undefined;
}

export async function listPublishedVendors(filters: ListPublishedVendorsFilters) {
  return prisma.vendor.findMany({
    where: {
      // Hardcoded, never derived from input — this is what makes the
      // published-only filter airtight regardless of which other filters
      // are combined.
      status: "published",
      ...(filters.priceTier ? { priceTier: filters.priceTier } : {}),
      ...(filters.region
        ? { serviceArea: { contains: filters.region, mode: "insensitive" as const } }
        : {}),
      ...(filters.category
        ? { vendorVendorCategories: { some: { vendorCategory: { categoryKey: filters.category } } } }
        : {}),
    },
    include: VENDOR_WITH_PORTFOLIO_INCLUDE,
    orderBy: [{ businessName: { sort: "asc", nulls: "last" } }, { id: "asc" }],
  });
}

export async function getPublishedVendor(id: string) {
  const vendor = await prisma.vendor.findFirst({
    where: { id, status: "published" },
    include: VENDOR_WITH_PORTFOLIO_INCLUDE,
  });
  if (!vendor) throw new AppError(404, "Vendor not found");
  return vendor;
}
