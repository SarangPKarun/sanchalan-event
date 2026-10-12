import { Router, type Router as RouterType } from "express";
import { requireActiveAdmin, requireAdminRole, requireAuth, requireRole } from "../middleware/auth.middleware.js";
import { listVendorCategoriesHandler } from "../controllers/vendor-self.controller.js";
import { adminLoginHandler, adminMeHandler } from "../controllers/admin-auth.controller.js";
import {
  approveVendorHandler,
  bulkVendorsHandler,
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
import {
  changePasswordHandler,
  createAdminHandler,
  listAdminsHandler,
  logoutAllHandler,
  resetPasswordHandler,
  updateAdminHandler,
} from "../controllers/admin-team.controller.js";
import {
  createTemplateHandler,
  deleteTemplateHandler,
  draftTemplatesHandler,
  listCategoriesHandler,
  listTemplatesHandler,
  statsHandler,
  updateCategoryHandler,
  updateTemplateHandler,
} from "../controllers/admin-catalog.controller.js";
import {
  auditCsvHandler,
  getEventHandler,
  getOrganizerHandler,
  getRoadmapLogHandler,
  listAuditHandler,
  listEventsHandler,
  listOrganizersHandler,
  listRoadmapLogsHandler,
  suspendOrganizerHandler,
  taskEditStatsHandler,
  unsuspendOrganizerHandler,
} from "../controllers/admin-oversight.controller.js";

export const adminRouter: RouterType = Router();

adminRouter.post("/auth/login", adminLoginHandler);

adminRouter.use(requireAuth, requireRole("admin"), requireActiveAdmin);
adminRouter.get("/me", adminMeHandler);
adminRouter.post("/me/password", changePasswordHandler);
adminRouter.post("/me/logout-all", logoutAllHandler);

adminRouter.get("/admins", requireAdminRole("super_admin"), listAdminsHandler);
adminRouter.post("/admins", requireAdminRole("super_admin"), createAdminHandler);
adminRouter.patch("/admins/:id", requireAdminRole("super_admin"), updateAdminHandler);
adminRouter.post("/admins/:id/reset-password", requireAdminRole("super_admin"), resetPasswordHandler);
adminRouter.get("/stats", statsHandler);
adminRouter.get("/vendors", listVendorsHandler);
adminRouter.post("/vendors/bulk", requireAdminRole("super_admin", "vendor_reviewer"), bulkVendorsHandler);
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

const catalogEditors = requireAdminRole("super_admin", "vendor_reviewer");
adminRouter.get("/categories", listCategoriesHandler);
adminRouter.patch("/categories/:key", catalogEditors, updateCategoryHandler);
adminRouter.get("/task-templates", listTemplatesHandler);
adminRouter.post("/task-templates", catalogEditors, createTemplateHandler);
adminRouter.patch("/task-templates/:id", catalogEditors, updateTemplateHandler);
adminRouter.delete("/task-templates/:id", catalogEditors, deleteTemplateHandler);
adminRouter.post("/category-proposals/:id/draft-templates", catalogEditors, draftTemplatesHandler);

// Oversight: read-only for every admin role; suspending an organizer and the audit log are super-admin only.
adminRouter.get("/organizers", listOrganizersHandler);
adminRouter.get("/organizers/:id", getOrganizerHandler);
adminRouter.post("/organizers/:id/suspend", requireAdminRole("super_admin"), suspendOrganizerHandler);
adminRouter.post("/organizers/:id/unsuspend", requireAdminRole("super_admin"), unsuspendOrganizerHandler);
adminRouter.get("/events", listEventsHandler);
adminRouter.get("/events/:id", getEventHandler);
adminRouter.get("/roadmap-logs", listRoadmapLogsHandler);
adminRouter.get("/roadmap-logs/:id", getRoadmapLogHandler);
adminRouter.get("/task-edit-stats", taskEditStatsHandler);
adminRouter.get("/audit-logs", requireAdminRole("super_admin"), listAuditHandler);
adminRouter.get("/audit-logs.csv", requireAdminRole("super_admin"), auditCsvHandler);
