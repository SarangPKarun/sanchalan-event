import type { VendorStatus } from "@sanchalan/shared-types";
import { prisma } from "../lib/prisma.js";
import { AppError } from "../lib/errors.js";

export async function listVendors(status?: VendorStatus) {
  return prisma.vendor.findMany({
    where: status ? { status } : {},
    include: {
      vendorVendorCategories: { include: { vendorCategory: true } },
      portfolioItems: { orderBy: { displayOrder: "asc" } },
    },
    orderBy: [{ submittedAt: "desc" }, { createdAt: "desc" }],
  });
}

async function requireVendor(vendorId: string) {
  const vendor = await prisma.vendor.findUnique({ where: { id: vendorId } });
  if (!vendor) throw new AppError(404, "Vendor not found");
  return vendor;
}

export async function approveVendor(vendorId: string, adminId: string) {
  await requireVendor(vendorId);
  return prisma.vendor.update({
    where: { id: vendorId },
    data: { status: "published", reviewedAt: new Date(), reviewedBy: adminId },
  });
}

export async function rejectVendor(vendorId: string, adminId: string, reason: string) {
  await requireVendor(vendorId);
  return prisma.vendor.update({
    where: { id: vendorId },
    data: {
      status: "rejected",
      rejectionReason: reason,
      reviewedAt: new Date(),
      reviewedBy: adminId,
    },
  });
}
