import type { Vendor, VendorCategory, VendorPortfolioItem, VendorVendorCategory } from "./models.js";

export interface VendorWithPortfolio extends Vendor {
  vendorVendorCategories: (VendorVendorCategory & { vendorCategory: VendorCategory })[];
  portfolioItems: VendorPortfolioItem[];
}

export interface ListVendorsResponse {
  vendors: VendorWithPortfolio[];
}
