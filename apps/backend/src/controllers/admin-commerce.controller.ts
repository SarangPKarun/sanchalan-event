import type { NextFunction, Request, Response } from "express";
import {
  idParamSchema,
  listBookingsQuerySchema,
  listPaymentsQuerySchema,
  listReviewsQuerySchema,
  moderateReviewSchema,
} from "../schemas/admin-list.schema.js";
import * as c from "../services/admin-commerce.service.js";

type Handler = (req: Request) => Promise<unknown>;

function handle(fn: Handler) {
  return async (req: Request, res: Response, next: NextFunction) => {
    try {
      res.status(200).json(await fn(req));
    } catch (err) {
      next(err);
    }
  };
}

const id = (req: Request) => idParamSchema.parse(req.params).id;

export const listBookingsHandler = handle((req) => c.listBookings(listBookingsQuerySchema.parse(req.query)));
export const getBookingHandler = handle((req) => c.getBooking(id(req)));
export const listPaymentsHandler = handle((req) => c.listPayments(listPaymentsQuerySchema.parse(req.query)));
export const listReviewsHandler = handle((req) => c.listReviews(listReviewsQuerySchema.parse(req.query)));
export const hideReviewHandler = handle((req) =>
  c.moderateReview(req.auth!.userId, id(req), "hide", moderateReviewSchema.parse(req.body).reason)
);
export const restoreReviewHandler = handle((req) => c.moderateReview(req.auth!.userId, id(req), "restore"));
