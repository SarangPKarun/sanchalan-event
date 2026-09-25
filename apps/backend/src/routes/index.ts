import { Router, type Router as RouterType } from "express";
import { authRouter } from "./auth.routes.js";
import { organizerRouter } from "./organizer.routes.js";
import { eventGroupRouter } from "./event-group.routes.js";

export const router: RouterType = Router();
router.use("/auth", authRouter);
router.use("/organizers", organizerRouter);
router.use("/event-groups", eventGroupRouter);
