import { Router, type Router as RouterType } from "express";
import { requireAuth, requireRole } from "../middleware/auth.middleware.js";
import { updateTaskHandler, deleteTaskHandler } from "../controllers/task.controller.js";

export const taskRouter: RouterType = Router();
taskRouter.use(requireAuth, requireRole("organizer"));

taskRouter.patch("/:id", updateTaskHandler);
taskRouter.delete("/:id", deleteTaskHandler);
