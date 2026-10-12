import { Router, type Router as RouterType } from "express";
import { requireActiveOrganizer, requireAuth, requireRole } from "../middleware/auth.middleware.js";
import {
  updateTaskHandler,
  deleteTaskHandler,
  listTaskCategoriesHandler,
} from "../controllers/task.controller.js";

export const taskRouter: RouterType = Router();
taskRouter.use(requireAuth, requireRole("organizer"), requireActiveOrganizer);

taskRouter.patch("/:id", updateTaskHandler);
taskRouter.delete("/:id", deleteTaskHandler);

export const taskCategoryRouter: RouterType = Router();
taskCategoryRouter.use(requireAuth, requireRole("organizer"), requireActiveOrganizer);
taskCategoryRouter.get("/", listTaskCategoriesHandler);
