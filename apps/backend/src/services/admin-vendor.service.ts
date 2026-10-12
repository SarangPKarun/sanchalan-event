import type { Prisma, VendorReviewAction, VendorStatus } from "@prisma/client";
import type { ListVendorsQuery } from "../schemas/admin-list.schema.js";
import { prisma } from "../lib/prisma.js";
import { AppError } from "../lib/errors.js";
import { audit } from "../lib/audit.js";
import { VENDOR_WITH_PORTFOLIO_INCLUDE } from "./vendor-query.helpers.js";

export async function listVendors(f: ListVendorsQuery) {
  const where: Prisma.VendorWhereInput = {
    ...(f.status ? { status: f.status } : {}),
    ...(f.priceTier ? { priceTier: f.priceTier } : {}),
    ...(f.category
      ? { vendorVendorCategories: { some: { vendorCategory: { categoryKey: f.category } } } }
      : {}),
    ...(f.q
      ? {
          OR: [
            { businessName: { contains: f.q, mode: "insensitive" } },
            { contactPersonName: { contains: f.q, mode: "insensitive" } },
            { phoneNumber: { contains: f.q } },
            { serviceArea: { contains: f.q, mode: "insensitive" } },
          ],
        }
      : {}),
  };
  const sort = f.sort ?? (f.status === "pending_review" ? "oldest" : "newest");
  const orderBy: Prisma.VendorOrderByWithRelationInput[] =
    sort === "name"
      ? [{ businessName: { sort: "asc", nulls: "last" } }, { id: "asc" }]
      : sort === "oldest"
        ? [{ submittedAt: { sort: "asc", nulls: "last" } }, { createdAt: "asc" }, { id: "asc" }]
        : [{ submittedAt: { sort: "desc", nulls: "last" } }, { createdAt: "desc" }, { id: "asc" }];

  const [total, vendors] = await Promise.all([
    prisma.vendor.count({ where }),
    prisma.vendor.findMany({
      where,
      include: VENDOR_WITH_PORTFOLIO_INCLUDE,
      orderBy,
      skip: (f.page - 1) * f.pageSize,
      take: f.pageSize,
    }),
  ]);
  return { vendors, total, page: f.page, pageSize: f.pageSize };
}

export async function vendorStatusCounts(): Promise<Record<VendorStatus, number>> {
  const rows = await prisma.vendor.groupBy({ by: ["status"], _count: true });
  const counts = { draft: 0, pending_review: 0, published: 0, rejected: 0, suspended: 0 };
  for (const r of rows) counts[r.status] = r._count;
  return counts;
}

export interface BulkResult {
  id: string;
  ok: boolean;
  error?: string;
}

/** Applies one decision to many vendors; each succeeds or fails on its own. */
export async function bulkDecide(
  adminId: string,
  input: { action: "approve" | "reject"; ids: string[]; reason?: string }
): Promise<BulkResult[]> {
  const results: BulkResult[] = [];
  for (const id of input.ids) {
    try {
      if (input.action === "approve") await approveVendor(id, adminId);
      else await rejectVendor(id, adminId, input.reason!);
      results.push({ id, ok: true });
    } catch (err) {
      results.push({ id, ok: false, error: err instanceof AppError ? err.message : "Failed" });
    }
  }
  return results;
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
    await audit(
      {
        adminId,
        action: `vendor.${t.action}`,
        entityType: "vendor",
        entityId: vendorId,
        ...(t.reason ? { metadata: { reason: t.reason } } : {}),
      },
      tx
    );
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
