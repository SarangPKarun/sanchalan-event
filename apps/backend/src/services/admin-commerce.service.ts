import type { Prisma } from "@prisma/client";
import type { z } from "zod";
import { prisma } from "../lib/prisma.js";
import { AppError } from "../lib/errors.js";
import { audit } from "../lib/audit.js";
import type {
  listBookingsQuerySchema,
  listPaymentsQuerySchema,
  listReviewsQuerySchema,
} from "../schemas/admin-list.schema.js";

const paging = (f: { page: number; pageSize: number }) => ({ skip: (f.page - 1) * f.pageSize, take: f.pageSize });
const today = () => new Date(new Date().toISOString().slice(0, 10));

/** A payment is overdue if it is unpaid past its due date, even when nothing has updated its status yet. */
const isOverdue = (p: { status: string; dueDate: Date }) => p.status !== "paid" && p.dueDate < today();

const BOOKING_INCLUDE = {
  vendor: { select: { id: true, businessName: true } },
  eventGroup: { select: { id: true, name: true, organizer: { select: { id: true, displayName: true } } } },
  payments: { select: { id: true, amount: true, status: true, dueDate: true, paidAt: true, milestoneType: true } },
} satisfies Prisma.BookingInclude;

type BookingWithPayments = Prisma.BookingGetPayload<{ include: typeof BOOKING_INCLUDE }>;

function summarise(b: BookingWithPayments) {
  const paid = b.payments.filter((p) => p.status === "paid").reduce((s, p) => s + Number(p.amount), 0);
  return {
    ...b,
    paymentSummary: {
      count: b.payments.length,
      paidAmount: paid,
      agreedPrice: Number(b.agreedPrice),
      overdueCount: b.payments.filter(isOverdue).length,
    },
  };
}

// ── Bookings ───────────────────────────────────────────────────────────────

export async function listBookings(f: z.infer<typeof listBookingsQuerySchema>) {
  const where: Prisma.BookingWhereInput = {
    ...(f.status ? { status: f.status } : {}),
    ...(f.q
      ? {
          OR: [
            { vendor: { businessName: { contains: f.q, mode: "insensitive" } } },
            { eventGroup: { name: { contains: f.q, mode: "insensitive" } } },
          ],
        }
      : {}),
  };
  const [total, rows] = await Promise.all([
    prisma.booking.count({ where }),
    prisma.booking.findMany({ where, include: BOOKING_INCLUDE, orderBy: [{ createdAt: "desc" }, { id: "asc" }], ...paging(f) }),
  ]);
  return { bookings: rows.map(summarise), total, page: f.page, pageSize: f.pageSize };
}

export async function getBooking(id: string) {
  const booking = await prisma.booking.findUnique({ where: { id }, include: BOOKING_INCLUDE });
  if (!booking) throw new AppError(404, "Booking not found");
  return summarise(booking);
}

// ── Payments ───────────────────────────────────────────────────────────────

export async function listPayments(f: z.infer<typeof listPaymentsQuerySchema>) {
  // "overdue" is derived (unpaid and past due), so it is queried by date, not by the stored status.
  const where: Prisma.PaymentWhereInput =
    f.status === "overdue"
      ? { status: { not: "paid" }, dueDate: { lt: today() } }
      : f.status === "pending"
        ? { status: "pending", dueDate: { gte: today() } }
        : f.status
          ? { status: f.status }
          : {};
  const [total, rows] = await Promise.all([
    prisma.payment.count({ where }),
    prisma.payment.findMany({
      where,
      include: {
        booking: {
          select: {
            id: true,
            vendor: { select: { id: true, businessName: true } },
            eventGroup: { select: { id: true, name: true } },
          },
        },
      },
      orderBy: [{ dueDate: "asc" }, { id: "asc" }],
      ...paging(f),
    }),
  ]);
  return { payments: rows.map((p) => ({ ...p, overdue: isOverdue(p) })), total, page: f.page, pageSize: f.pageSize };
}

// ── Reviews (moderation) ───────────────────────────────────────────────────

export async function listReviews(f: z.infer<typeof listReviewsQuerySchema>) {
  const where: Prisma.ReviewWhereInput = {
    ...(f.status ? { status: f.status } : {}),
    ...(f.rating ? { rating: f.rating } : {}),
    ...(f.q
      ? {
          OR: [
            { comment: { contains: f.q, mode: "insensitive" } },
            { vendor: { businessName: { contains: f.q, mode: "insensitive" } } },
          ],
        }
      : {}),
  };
  const [total, reviews] = await Promise.all([
    prisma.review.count({ where }),
    prisma.review.findMany({
      where,
      include: {
        vendor: { select: { id: true, businessName: true } },
        eventGroup: { select: { id: true, name: true } },
        moderator: { select: { id: true, name: true } },
      },
      orderBy: [{ createdAt: "desc" }, { id: "asc" }],
      ...paging(f),
    }),
  ]);
  return { reviews, total, page: f.page, pageSize: f.pageSize };
}

/** hide: visible or flagged -> hidden. restore: hidden -> visible. The status check runs inside the update. */
export async function moderateReview(adminId: string, id: string, action: "hide" | "restore", reason?: string) {
  return prisma.$transaction(async (tx) => {
    const { count } = await tx.review.updateMany({
      where: { id, status: action === "hide" ? { in: ["visible", "flagged"] } : "hidden" },
      data:
        action === "hide"
          ? { status: "hidden", moderationReason: reason ?? null, moderatedAt: new Date(), moderatedBy: adminId }
          : { status: "visible", moderationReason: null, moderatedAt: new Date(), moderatedBy: adminId },
    });
    if (count === 0) {
      const exists = await tx.review.findUnique({ where: { id }, select: { id: true } });
      throw exists
        ? new AppError(409, action === "hide" ? "Review is already hidden" : "Review is not hidden")
        : new AppError(404, "Review not found");
    }
    await audit(
      { adminId, action: `review.${action === "hide" ? "hidden" : "restored"}`, entityType: "review", entityId: id, ...(reason ? { metadata: { reason } } : {}) },
      tx
    );
    return tx.review.findUniqueOrThrow({ where: { id } });
  });
}

export async function commerceCounts() {
  const [bookings, overduePayments, flaggedReviews] = await Promise.all([
    prisma.booking.count(),
    prisma.payment.count({ where: { status: { not: "paid" }, dueDate: { lt: today() } } }),
    prisma.review.count({ where: { status: "flagged" } }),
  ]);
  return { bookings, overduePayments, flaggedReviews };
}
