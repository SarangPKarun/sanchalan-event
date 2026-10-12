import { Router, type Router as RouterType } from "express";
import { requireActiveAdmin, requireAdminRole, requireAuth, requireRole } from "../middleware/auth.middleware.js";
import { listVendorCategoriesHandler } from "../controllers/vendor-self.controller.js";
import { adminLoginHandler, adminMeHandler } from "../controllers/admin-auth.controller.js";
import {
  approveVendorHandler,
  getVendorHandler,
  listVendorsHandler,
  rejectVendorHandler,
  suspendVendorHandler,
  unsuspendVendorHandler,
} from "../controllers/admin-vendor.controller.js";
import {
  approveProposalHandler,
  getProposalHandler,
  listProposalsHandler,
  mergeProposalHandler,
  rejectProposalHandler,
} from "../controllers/category-proposal.controller.js";

export const adminRouter: RouterType = Router();

adminRouter.post("/auth/login", adminLoginHandler);

adminRouter.use(requireAuth, requireRole("admin"), requireActiveAdmin);
adminRouter.get("/me", adminMeHandler);
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

adminRouter.get("/vendor-categories", listVendorCategoriesHandler);
adminRouter.get("/category-proposals", listProposalsHandler);
adminRouter.get("/category-proposals/:id", getProposalHandler);
adminRouter.post(
  "/category-proposals/:id/approve",
  requireAdminRole("super_admin", "vendor_reviewer"),
  approveProposalHandler
);
adminRouter.post(
  "/category-proposals/:id/reject",
  requireAdminRole("super_admin", "vendor_reviewer"),
  rejectProposalHandler
);
adminRouter.post(
  "/category-proposals/:id/merge",
  requireAdminRole("super_admin", "vendor_reviewer"),
  mergeProposalHandler
);
