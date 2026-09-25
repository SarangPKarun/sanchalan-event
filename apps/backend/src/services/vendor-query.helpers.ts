export const VENDOR_WITH_PORTFOLIO_INCLUDE = {
  vendorVendorCategories: { include: { vendorCategory: true } },
  portfolioItems: { orderBy: { displayOrder: "asc" } },
} as const;
