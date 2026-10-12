import type { Prisma } from "@prisma/client";
import { prisma } from "../lib/prisma.js";
import { AppError } from "../lib/errors.js";
import { audit } from "../lib/audit.js";
import { VENDOR_MAX_CATEGORIES } from "../lib/vendor-limits.js";
import type {
  ApproveProposalInput,
  ProposeCategoryInput,
} from "../schemas/category-proposal.schema.js";

const MAX_PENDING_PER_VENDOR = 3;

type Tx = Prisma.TransactionClient;

export function normalizeCategoryKey(label: string): string {
  return label
    .toLowerCase()
    .normalize("NFKD")
    .replace(/[̀-ͯ]/g, "")
    .replace(/&/g, " and ")
    .replace(/[^a-z0-9]+/g, "_")
    .replace(/^_+|_+$/g, "");
}

// ── Vendor side ────────────────────────────────────────────────────────────

export async function proposeCategory(vendorId: string, input: ProposeCategoryInput) {
  const categoryKey = normalizeCategoryKey(input.label);
  if (categoryKey.length < 3) throw new AppError(400, "Category name is too short");

  return prisma.$transaction(async (tx) => {
    const existing = await tx.vendorCategory.findUnique({ where: { categoryKey } });
    if (existing)
      throw new AppError(409, "This category already exists. Pick it from the list.", {
        categoryKey: existing.categoryKey,
      });

    const mine = await tx.categoryProposalVendor.count({
      where: { vendorId, proposal: { status: "pending" } },
    });
    if (mine >= MAX_PENDING_PER_VENDOR)
      throw new AppError(409, `You can have at most ${MAX_PENDING_PER_VENDOR} pending proposals`);

    const pending = await tx.categoryProposal.findFirst({
      where: { categoryKey, status: "pending" },
    });
    // Same name already waiting for review: attach this vendor instead of creating a duplicate.
    const proposal =
      pending ??
      (await tx.categoryProposal.create({
        data: {
          label: input.label,
          categoryKey,
          ...(input.description ? { description: input.description } : {}),
        },
      }));
    await tx.categoryProposalVendor.upsert({
      where: { proposalId_vendorId: { proposalId: proposal.id, vendorId } },
      create: { proposalId: proposal.id, vendorId },
      update: {},
    });
    return proposal;
  });
}

export async function listMyProposals(vendorId: string) {
  const proposals = await prisma.categoryProposal.findMany({
    where: { vendors: { some: { vendorId } } },
    orderBy: { submittedAt: "desc" },
    select: {
      id: true,
      label: true,
      categoryKey: true,
      description: true,
      status: true,
      rejectionReason: true,
      submittedAt: true,
      reviewedAt: true,
    },
  });
  return { proposals };
}

// ── Admin side ─────────────────────────────────────────────────────────────

const ADMIN_INCLUDE = {
  vendors: {
    select: {
      vendor: { select: { id: true, businessName: true, phoneNumber: true } },
    },
  },
  reviewer: { select: { id: true, name: true } },
  resolvedCategory: { select: { id: true, categoryKey: true, label: true } },
} satisfies Prisma.CategoryProposalInclude;

export async function listProposals(status?: Prisma.CategoryProposalWhereInput["status"]) {
  const proposals = await prisma.categoryProposal.findMany({
    where: status ? { status } : {},
    include: ADMIN_INCLUDE,
    orderBy: { submittedAt: status === "pending" ? "asc" : "desc" },
  });
  return { proposals };
}

export async function getProposal(id: string) {
  const proposal = await prisma.categoryProposal.findUnique({
    where: { id },
    include: ADMIN_INCLUDE,
  });
  if (!proposal) throw new AppError(404, "Proposal not found");
  return proposal;
}

/** Claims a pending proposal atomically so a concurrent decision returns 409. */
async function claimPending(
  tx: Tx,
  id: string,
  adminId: string,
  data: Prisma.CategoryProposalUncheckedUpdateManyInput
) {
  const { count } = await tx.categoryProposal.updateMany({
    where: { id, status: "pending" },
    data: { reviewedAt: new Date(), reviewedBy: adminId, ...data },
  });
  if (count === 0) {
    const exists = await tx.categoryProposal.findUnique({ where: { id }, select: { id: true } });
    throw exists
      ? new AppError(409, "Proposal has already been decided")
      : new AppError(404, "Proposal not found");
  }
}

/** Assigns the category to proposing vendors, skipping any already at the category cap. */
async function assignVendors(tx: Tx, proposalId: string, vendorCategoryId: string) {
  const links = await tx.categoryProposalVendor.findMany({
    where: { proposalId },
    select: { vendorId: true },
  });
  const counts = await tx.vendorVendorCategory.groupBy({
    by: ["vendorId"],
    where: { vendorId: { in: links.map((l) => l.vendorId) } },
    _count: true,
  });
  const full = new Set(counts.filter((c) => c._count >= VENDOR_MAX_CATEGORIES).map((c) => c.vendorId));
  await tx.vendorVendorCategory.createMany({
    data: links.filter((l) => !full.has(l.vendorId)).map((l) => ({ vendorId: l.vendorId, vendorCategoryId })),
    skipDuplicates: true,
  });
}

export async function approveProposal(id: string, adminId: string, input: ApproveProposalInput) {
  const proposal = await getProposal(id);
  const key = proposal.categoryKey;

  await prisma.$transaction(async (tx) => {
    if (await tx.vendorCategory.findUnique({ where: { categoryKey: key } }))
      throw new AppError(409, "A category with this key already exists. Merge instead.");

    const keys = input.templates.map((t) => t.taskKey);
    const clash = await tx.taskTemplate.findFirst({ where: { taskKey: { in: keys } } });
    if (clash || new Set(keys).size !== keys.length)
      throw new AppError(400, "Template task keys must be unique across all templates");

    await claimPending(tx, id, adminId, { status: "approved", rejectionReason: null });

    const vendorCategory = await tx.vendorCategory.create({
      data: { categoryKey: key, label: input.label, applicableEventTypes: input.applicableEventTypes },
    });
    // Roadmap generation reads TaskCategory + TaskTemplate, so approval creates both.
    const taskCategory = await tx.taskCategory.upsert({
      where: { categoryKey: key },
      create: { categoryKey: key, label: input.label, applicableEventTypes: input.applicableEventTypes },
      update: { label: input.label },
    });
    await tx.taskTemplate.createMany({
      data: input.applicableEventTypes.flatMap((eventType) =>
        input.templates.map((t) => ({
          eventType,
          taskCategoryId: taskCategory.id,
          taskKey: t.taskKey,
          defaultNameEn: t.defaultNameEn,
          defaultLeadTimeDays: t.defaultLeadTimeDays,
          defaultDependencyKeys: t.defaultDependencyKeys,
          typicalOwnerType: t.typicalOwnerType,
          version: 1,
        }))
      ),
    });
    await tx.categoryProposal.update({
      where: { id },
      data: { label: input.label, resolvedVendorCategoryId: vendorCategory.id },
    });
    await assignVendors(tx, id, vendorCategory.id);
    await audit(
      { adminId, action: "category_proposal.approved", entityType: "category_proposal", entityId: id, metadata: { categoryKey: key } },
      tx
    );
  }, { timeout: 20_000 });
  return getProposal(id);
}

export async function rejectProposal(id: string, adminId: string, reason: string) {
  await prisma.$transaction(async (tx) => {
    await claimPending(tx, id, adminId, { status: "rejected", rejectionReason: reason });
    await audit({ adminId, action: "category_proposal.rejected", entityType: "category_proposal", entityId: id, metadata: { reason } }, tx);
  });
  return getProposal(id);
}

export async function mergeProposal(id: string, adminId: string, vendorCategoryId: string) {
  await prisma.$transaction(async (tx) => {
    const target = await tx.vendorCategory.findUnique({ where: { id: vendorCategoryId } });
    if (!target) throw new AppError(404, "Target category not found");
    await claimPending(tx, id, adminId, {
      status: "merged",
      rejectionReason: null,
      resolvedVendorCategoryId: vendorCategoryId,
    });
    await assignVendors(tx, id, vendorCategoryId);
    await audit({ adminId, action: "category_proposal.merged", entityType: "category_proposal", entityId: id, metadata: { vendorCategoryId } }, tx);
  });
  return getProposal(id);
}
