import { Router, type Router as RouterType } from "express";
import { requireAuth, requireRole } from "../middleware/auth.middleware.js";
import {
  createEventGroupHandler,
  listMyEventGroupsHandler,
  getEventGroupHandler,
} from "../controllers/event-group.controller.js";

export const eventGroupRouter: RouterType = Router();
eventGroupRouter.use(requireAuth, requireRole("organizer"));

eventGroupRouter.post("/", createEventGroupHandler);
eventGroupRouter.get("/me", listMyEventGroupsHandler); // MUST precede /:id
eventGroupRouter.get("/:id", getEventGroupHandler);
