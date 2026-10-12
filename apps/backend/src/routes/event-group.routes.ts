import { Router, type Router as RouterType } from "express";
import { requireActiveOrganizer, requireAuth, requireRole } from "../middleware/auth.middleware.js";
import {
  createEventGroupHandler,
  listMyEventGroupsHandler,
  getEventGroupHandler,
  updateEventGroupHandler,
  deleteEventGroupHandler,
  deleteBudgetCategoryHandler,
  updateBudgetCategoryHandler,
  createBudgetCategoryHandler,
} from "../controllers/event-group.controller.js";
import { generateRoadmapHandler } from "../controllers/roadmap.controller.js";
import { createTaskHandler, listEventGroupTasksHandler } from "../controllers/task.controller.js";

export const eventGroupRouter: RouterType = Router();
eventGroupRouter.use(requireAuth, requireRole("organizer"), requireActiveOrganizer);

eventGroupRouter.post("/", createEventGroupHandler);
eventGroupRouter.get("/me", listMyEventGroupsHandler); // MUST precede /:id
eventGroupRouter.get("/:id", getEventGroupHandler);
eventGroupRouter.patch("/:id", updateEventGroupHandler);
eventGroupRouter.delete("/:id", deleteEventGroupHandler);
eventGroupRouter.post("/:id/generate-roadmap", generateRoadmapHandler);
eventGroupRouter.get("/:id/tasks", listEventGroupTasksHandler);
eventGroupRouter.post("/:id/tasks", createTaskHandler);
eventGroupRouter.patch("/:id/budget-categories/:categoryId", updateBudgetCategoryHandler);
eventGroupRouter.post("/:id/budget-categories", createBudgetCategoryHandler);
eventGroupRouter.delete("/:id/budget-categories/:categoryId", deleteBudgetCategoryHandler);
