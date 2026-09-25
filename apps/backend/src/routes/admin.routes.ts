import { Router, type Router as RouterType } from "express";
import { requireAdminRole, requireAuth, requireRole } from "../middleware/auth.middleware.js";
import { adminLoginHandler } from "../controllers/admin-auth.controller.js";
import {
  approveVendorHandler,
  listVendorsHandler,
  rejectVendorHandler,
} from "../controllers/admin-vendor.controller.js";

export const adminRouter: RouterType = Router();

adminRouter.post("/auth/login", adminLoginHandler);

adminRouter.use(requireAuth, requireRole("admin"));
adminRouter.get("/vendors", listVendorsHandler);
adminRouter.post(
  "/vendors/:id/approve",
  requireAdminRole("super_admin", "vendor_reviewer"),
  approveVendorHandler
);
adminRouter.post(
  "/vendors/:id/reject",
  requireAdminRole("super_admin", "vendor_reviewer"),
  rejectVendorHandler
);
