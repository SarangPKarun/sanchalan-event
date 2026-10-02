import type { NextFunction, Request, Response } from "express";
import {
  pastWorkIdParamSchema,
  pastWorkSchema,
  reorderPastWorkSchema,
  setVendorCategoriesSchema,
  updatePastWorkSchema,
  updateVendorProfileSchema,
} from "../schemas/vendor-self.schema.js";
import * as vendorSelfService from "../services/vendor-self.service.js";

type Handler = (req: Request, res: Response) => Promise<unknown>;

function handle(fn: Handler, successStatus = 200) {
  return async (req: Request, res: Response, next: NextFunction) => {
    try {
      res.status(successStatus).json(await fn(req, res));
    } catch (err) {
      next(err);
    }
  };
}

export const listVendorCategoriesHandler = handle(() =>
  vendorSelfService.listVendorCategories()
);

export const getMeHandler = handle((req) => vendorSelfService.getMe(req.auth!.userId));

export const updateProfileHandler = handle((req) =>
  vendorSelfService.updateProfile(req.auth!.userId, updateVendorProfileSchema.parse(req.body))
);

export const setCategoriesHandler = handle((req) =>
  vendorSelfService.setCategories(req.auth!.userId, setVendorCategoriesSchema.parse(req.body))
);

export const addPastWorkHandler = handle(
  (req) => vendorSelfService.addPastWork(req.auth!.userId, pastWorkSchema.parse(req.body)),
  201
);

export const updatePastWorkHandler = handle((req) =>
  vendorSelfService.updatePastWork(
    req.auth!.userId,
    pastWorkIdParamSchema.parse(req.params).itemId,
    updatePastWorkSchema.parse(req.body)
  )
);

export const deletePastWorkHandler = handle((req) =>
  vendorSelfService.deletePastWork(
    req.auth!.userId,
    pastWorkIdParamSchema.parse(req.params).itemId
  )
);

export const reorderPastWorkHandler = handle((req) =>
  vendorSelfService.reorderPastWork(
    req.auth!.userId,
    reorderPastWorkSchema.parse(req.body).itemIds
  )
);

export const submitHandler = handle((req) => vendorSelfService.submitForReview(req.auth!.userId));

export const withdrawHandler = handle((req) => vendorSelfService.withdraw(req.auth!.userId));
