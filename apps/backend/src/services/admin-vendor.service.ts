import type { VendorReviewAction, VendorStatus } from "@prisma/client";
import { prisma } from "../lib/prisma.js";
import { AppError } from "../lib/errors.js";
import { VENDOR_WITH_PORTFOLIO_INCLUDE } from "./vendor-query.helpers.js";

export async function listVendors(status?: VendorStatus) {
  return prisma.vendor.findMany({
    where: status ? { status } : {},
    include: VENDOR_WITH_PORTFOLIO_INCLUDE,
    orderBy:
      status === "pending_review"
        ? [{ submittedAt: "asc" }, { createdAt: "asc" }]
        : [{ submittedAt: { sort: "desc", nulls: "last" } }, { createdAt: "desc" }],
  });
}

export async function getVendor(vendorId: string) {
  const vendor = await prisma.vendor.findUnique({
    where: { id: vendorId },
    include: {
      ...VENDOR_WITH_PORTFOLIO_INCLUDE,
      reviewLogs: {
        orderBy: { createdAt: "desc" },
        include: { admin: { select: { id: true, name: true } } },
      },
    },
  });
  if (!vendor) throw new AppError(404, "Vendor not found");
  return vendor;
}

interface Transition {
  from: VendorStatus;
  to: VendorStatus;
  action: VendorReviewAction;
  verb: string;
  reason?: string;
}

/** Applies a status transition atomically; the `from` check runs inside the update so races return 409. */
async function transition(vendorId: string, adminId: string, t: Transition) {
  const existing = await prisma.vendor.findUnique({ where: { id: vendorId }, select: { id: true } });
  if (!existing) throw new AppError(404, "Vendor not found");

  return prisma.$transaction(async (tx) => {
    const { count } = await tx.vendor.updateMany({
      where: { id: vendorId, status: t.from },
      data: {
        status: t.to,
        reviewedAt: new Date(),
        reviewedBy: adminId,
        // Approve/unsuspend clear any stale rejection; reject sets it; suspend leaves it untouched.
        ...(t.action === "rejected"
          ? { rejectionReason: t.reason ?? null }
          : t.action === "approved" || t.action === "unsuspended"
            ? { rejectionReason: null }
            : {}),
      },
    });
    if (count === 0)
      throw new AppError(409, `Vendor must be ${t.from.replace("_", " ")} to ${t.verb}`);

    await tx.vendorReviewLog.create({
      data: { vendorId, adminId, action: t.action, ...(t.reason ? { reason: t.reason } : {}) },
    });
    return tx.vendor.findUniqueOrThrow({ where: { id: vendorId } });
  });
}

export function approveVendor(vendorId: string, adminId: string) {
  return transition(vendorId, adminId, { from: "pending_review", to: "published", action: "approved", verb: "approve" });
}

export function rejectVendor(vendorId: string, adminId: string, reason: string) {
  return transition(vendorId, adminId, {
    from: "pending_review",
    to: "rejected",
    action: "rejected",
    verb: "reject",
    reason,
  });
}

export function suspendVendor(vendorId: string, adminId: string, reason: string) {
  return transition(vendorId, adminId, {
    from: "published",
    to: "suspended",
    action: "suspended",
    verb: "suspend",
    reason,
  });
}

export function unsuspendVendor(vendorId: string, adminId: string) {
  return transition(vendorId, adminId, {
    from: "suspended",
    to: "published",
    action: "unsuspended",
    verb: "unsuspend",
  });
}
