import { Router, type Router as RouterType } from "express";
import { requireAuth, requireRole } from "../middleware/auth.middleware.js";
import { getVendorHandler, listVendorsHandler } from "../controllers/vendor.controller.js";

export const vendorRouter: RouterType = Router();
vendorRouter.use(requireAuth, requireRole("organizer"));

vendorRouter.get("/", listVendorsHandler);
vendorRouter.get("/:id", getVendorHandler);
