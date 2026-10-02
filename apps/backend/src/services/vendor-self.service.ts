import type {
  VendorCompleteness,
  VendorRequiredField,
} from "@sanchalan/shared-types";
import {
  VENDOR_DESCRIPTION_MIN,
  VENDOR_MAX_PAST_WORK,
  VENDOR_REVIEW_TRIGGER_FIELDS,
} from "@sanchalan/shared-types";
import type { Prisma, VendorReviewAction } from "@prisma/client";
import { prisma } from "../lib/prisma.js";
import { AppError } from "../lib/errors.js";
import { VENDOR_WITH_PORTFOLIO_INCLUDE } from "./vendor-query.helpers.js";
import type {
  PastWorkInput,
  SetVendorCategoriesInput,
  UpdatePastWorkInput,
  UpdateVendorProfileInput,
} from "../schemas/vendor-self.schema.js";

type Tx = Prisma.TransactionClient;

type VendorWithRelations = Prisma.VendorGetPayload<{
  include: typeof VENDOR_WITH_PORTFOLIO_INCLUDE;
}>;

function computeCompleteness(v: VendorWithRelations): VendorCompleteness {
  const missing: VendorRequiredField[] = [];
  if (!v.businessName?.trim()) missing.push("businessName");
  if (!v.contactPersonName?.trim()) missing.push("contactPersonName");
  if (!v.priceTier) missing.push("priceTier");
  if (!v.serviceArea?.trim()) missing.push("serviceArea");
  if ((v.description?.trim().length ?? 0) < VENDOR_DESCRIPTION_MIN) missing.push("description");
  if (v.vendorVendorCategories.length === 0) missing.push("categories");
  if (v.portfolioItems.length === 0) missing.push("pastWork");
  return { complete: missing.length === 0, missing };
}

async function loadVendor(vendorId: string, db: Tx | typeof prisma = prisma) {
  const vendor = await db.vendor.findUnique({
    where: { id: vendorId },
    include: VENDOR_WITH_PORTFOLIO_INCLUDE,
  });
  if (!vendor) throw new AppError(404, "Vendor not found");
  return vendor;
}

async function loadMe(vendorId: string, db: Tx | typeof prisma = prisma) {
  const vendor = await loadVendor(vendorId, db);
  return { ...vendor, completeness: computeCompleteness(vendor) };
}

function logAction(
  tx: Tx,
  vendorId: string,
  action: VendorReviewAction,
  reason?: string
) {
  return tx.vendorReviewLog.create({
    data: { vendorId, action, ...(reason ? { reason } : {}) },
  });
}

/** Throws unless the vendor may currently edit its profile; returns whether edits need re-review. */
function assertEditable(status: string): { published: boolean } {
  if (status === "suspended") throw new AppError(403, "Your account is suspended. Contact support.");
  if (status === "pending_review")
    throw new AppError(409, "Your profile is under review. Withdraw it to make changes.");
  return { published: status === "published" };
}

/**
 * Applies a key-field edit. For published vendors, moves them to pending_review
 * (hiding the listing) and writes a log entry. Returns whether that happened.
 */
async function markReverificationIfNeeded(
  tx: Tx,
  vendorId: string,
  published: boolean,
  keyFieldChanged: boolean
): Promise<boolean> {
  if (!published || !keyFieldChanged) return false;
  await tx.vendor.update({
    where: { id: vendorId },
    data: {
      status: "pending_review",
      submittedAt: new Date(),
      rejectionReason: null,
      reviewedAt: null,
      reviewedBy: null,
    },
  });
  await logAction(tx, vendorId, "reverification_required");
  return true;
}

export async function listVendorCategories() {
  const categories = await prisma.vendorCategory.findMany({
    orderBy: { categoryKey: "asc" },
    select: { id: true, categoryKey: true },
  });
  return { categories };
}

export function getMe(vendorId: string) {
  return loadMe(vendorId);
}

export async function updateProfile(vendorId: string, input: UpdateVendorProfileInput) {
  return prisma.$transaction(async (tx) => {
    const current = await loadVendor(vendorId, tx);
    const { published } = assertEditable(current.status);

    const changedKeyField = VENDOR_REVIEW_TRIGGER_FIELDS.some(
      (f) => input[f] !== undefined && input[f] !== current[f]
    );

    const data = Object.fromEntries(
      Object.entries(input).filter(([, v]) => v !== undefined)
    ) as Prisma.VendorUpdateInput;
    if (Object.keys(data).length > 0) await tx.vendor.update({ where: { id: vendorId }, data });

    const reverificationTriggered = await markReverificationIfNeeded(
      tx,
      vendorId,
      published,
      changedKeyField
    );
    return { vendor: await loadMe(vendorId, tx), reverificationTriggered };
  });
}

export async function setCategories(vendorId: string, input: SetVendorCategoriesInput) {
  return prisma.$transaction(async (tx) => {
    const current = await loadVendor(vendorId, tx);
    const { published } = assertEditable(current.status);

    const categories = await tx.vendorCategory.findMany({
      where: { categoryKey: { in: input.categoryKeys } },
    });
    if (categories.length !== input.categoryKeys.length)
      throw new AppError(400, "Unknown vendor category");

    const before = new Set(current.vendorVendorCategories.map((c) => c.vendorCategoryId));
    const after = new Set(categories.map((c) => c.id));
    const changed = before.size !== after.size || [...after].some((id) => !before.has(id));

    if (changed) {
      await tx.vendorVendorCategory.deleteMany({ where: { vendorId } });
      await tx.vendorVendorCategory.createMany({
        data: categories.map((c) => ({ vendorId, vendorCategoryId: c.id })),
      });
    }
    const reverificationTriggered = await markReverificationIfNeeded(
      tx,
      vendorId,
      published,
      changed
    );
    return { vendor: await loadMe(vendorId, tx), reverificationTriggered };
  });
}

export async function addPastWork(vendorId: string, input: PastWorkInput) {
  return prisma.$transaction(async (tx) => {
    const current = await loadVendor(vendorId, tx);
    const { published } = assertEditable(current.status);
    if (current.portfolioItems.length >= VENDOR_MAX_PAST_WORK)
      throw new AppError(400, `You can add up to ${VENDOR_MAX_PAST_WORK} past-work entries`);

    const nextOrder =
      current.portfolioItems.reduce((max, p) => Math.max(max, p.displayOrder), -1) + 1;
    await tx.vendorPortfolioItem.create({
      data: {
        vendorId,
        title: input.title,
        caption: input.caption ?? null,
        displayOrder: nextOrder,
      },
    });
    const reverificationTriggered = await markReverificationIfNeeded(tx, vendorId, published, true);
    return { vendor: await loadMe(vendorId, tx), reverificationTriggered };
  });
}

async function requireOwnedItem(tx: Tx, vendorId: string, itemId: string) {
  const item = await tx.vendorPortfolioItem.findFirst({ where: { id: itemId, vendorId } });
  if (!item) throw new AppError(404, "Past-work entry not found");
  return item;
}

export async function updatePastWork(
  vendorId: string,
  itemId: string,
  input: UpdatePastWorkInput
) {
  return prisma.$transaction(async (tx) => {
    const current = await loadVendor(vendorId, tx);
    const { published } = assertEditable(current.status);
    await requireOwnedItem(tx, vendorId, itemId);

    await tx.vendorPortfolioItem.update({
      where: { id: itemId },
      data: {
        ...(input.title !== undefined ? { title: input.title } : {}),
        ...(input.caption !== undefined ? { caption: input.caption } : {}),
      },
    });
    const reverificationTriggered = await markReverificationIfNeeded(tx, vendorId, published, true);
    return { vendor: await loadMe(vendorId, tx), reverificationTriggered };
  });
}

export async function deletePastWork(vendorId: string, itemId: string) {
  return prisma.$transaction(async (tx) => {
    const current = await loadVendor(vendorId, tx);
    const { published } = assertEditable(current.status);
    await requireOwnedItem(tx, vendorId, itemId);
    // A published vendor must keep at least one entry, otherwise it would fall out of completeness.
    if (published && current.portfolioItems.length <= 1)
      throw new AppError(400, "A published profile needs at least one past-work entry");

    await tx.vendorPortfolioItem.delete({ where: { id: itemId } });
    const reverificationTriggered = await markReverificationIfNeeded(tx, vendorId, published, true);
    return { vendor: await loadMe(vendorId, tx), reverificationTriggered };
  });
}

export async function reorderPastWork(vendorId: string, itemIds: string[]) {
  return prisma.$transaction(async (tx) => {
    const current = await loadVendor(vendorId, tx);
    assertEditable(current.status);

    const owned = new Set(current.portfolioItems.map((p) => p.id));
    if (itemIds.length !== owned.size || !itemIds.every((id) => owned.has(id)))
      throw new AppError(400, "itemIds must list every past-work entry exactly once");

    await Promise.all(
      itemIds.map((id, index) =>
        tx.vendorPortfolioItem.update({ where: { id }, data: { displayOrder: index } })
      )
    );
    // Ordering is cosmetic: it never triggers re-review.
    return { vendor: await loadMe(vendorId, tx), reverificationTriggered: false };
  });
}

export async function submitForReview(vendorId: string) {
  return prisma.$transaction(async (tx) => {
    const current = await loadVendor(vendorId, tx);
    if (current.status !== "draft" && current.status !== "rejected")
      throw new AppError(409, `Cannot submit a profile that is ${current.status.replace("_", " ")}`);

    const completeness = computeCompleteness(current);
    if (!completeness.complete)
      throw new AppError(400, "Profile is incomplete", { missing: completeness.missing });

    await tx.vendor.update({
      where: { id: vendorId },
      data: {
        status: "pending_review",
        submittedAt: new Date(),
        rejectionReason: null,
        reviewedAt: null,
        reviewedBy: null,
      },
    });
    await logAction(tx, vendorId, "submitted");
    return loadMe(vendorId, tx);
  });
}

export async function withdraw(vendorId: string) {
  return prisma.$transaction(async (tx) => {
    const current = await loadVendor(vendorId, tx);
    if (current.status !== "pending_review")
      throw new AppError(409, "Only a profile under review can be withdrawn");

    await tx.vendor.update({ where: { id: vendorId }, data: { status: "draft" } });
    await logAction(tx, vendorId, "withdrawn");
    return loadMe(vendorId, tx);
  });
}
