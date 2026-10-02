import { Router, type Router as RouterType } from "express";
import { requireAdminRole, requireAuth, requireRole } from "../middleware/auth.middleware.js";
import { adminLoginHandler } from "../controllers/admin-auth.controller.js";
import {
  approveVendorHandler,
  getVendorHandler,
  listVendorsHandler,
  rejectVendorHandler,
  suspendVendorHandler,
  unsuspendVendorHandler,
} from "../controllers/admin-vendor.controller.js";

export const adminRouter: RouterType = Router();

adminRouter.post("/auth/login", adminLoginHandler);

adminRouter.use(requireAuth, requireRole("admin"));
adminRouter.get("/vendors", listVendorsHandler);
adminRouter.get("/vendors/:id", getVendorHandler);
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
adminRouter.post(
  "/vendors/:id/suspend",
  requireAdminRole("super_admin", "vendor_reviewer"),
  suspendVendorHandler
);
adminRouter.post(
  "/vendors/:id/unsuspend",
  requireAdminRole("super_admin", "vendor_reviewer"),
  unsuspendVendorHandler
);
