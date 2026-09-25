import { Router, type Router as RouterType } from "express";
import { requireAuth, requireRole } from "../middleware/auth.middleware.js";
import { getMeHandler, updateProfileHandler } from "../controllers/organizer.controller.js";

export const organizerRouter: RouterType = Router();
organizerRouter.use(requireAuth, requireRole("organizer"));

organizerRouter.get("/me", getMeHandler);
organizerRouter.post("/me/profile", updateProfileHandler);
