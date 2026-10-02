import { Router, type Router as RouterType } from "express";
import { requireAuth, requireRole } from "../middleware/auth.middleware.js";
import {
  addPastWorkHandler,
  deletePastWorkHandler,
  getMeHandler,
  listVendorCategoriesHandler,
  reorderPastWorkHandler,
  setCategoriesHandler,
  submitHandler,
  updatePastWorkHandler,
  updateProfileHandler,
  withdrawHandler,
} from "../controllers/vendor-self.controller.js";

export const vendorSelfRouter: RouterType = Router();
vendorSelfRouter.use(requireAuth, requireRole("vendor"));

vendorSelfRouter.get("/", getMeHandler);
vendorSelfRouter.patch("/", updateProfileHandler);
vendorSelfRouter.put("/categories", setCategoriesHandler);
vendorSelfRouter.post("/past-work", addPastWorkHandler);
vendorSelfRouter.put("/past-work/order", reorderPastWorkHandler);
vendorSelfRouter.patch("/past-work/:itemId", updatePastWorkHandler);
vendorSelfRouter.delete("/past-work/:itemId", deletePastWorkHandler);
vendorSelfRouter.post("/submit", submitHandler);
vendorSelfRouter.post("/withdraw", withdrawHandler);

export const vendorCategoryRouter: RouterType = Router();
vendorCategoryRouter.use(requireAuth, requireRole("organizer", "vendor"));
vendorCategoryRouter.get("/", listVendorCategoriesHandler);
