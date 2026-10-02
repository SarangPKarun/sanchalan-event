import { Router, type Router as RouterType } from "express";
import { authRouter } from "./auth.routes.js";
import { organizerRouter } from "./organizer.routes.js";
import { eventGroupRouter } from "./event-group.routes.js";
import { taskRouter, taskCategoryRouter } from "./task.routes.js";
import { adminRouter } from "./admin.routes.js";
import { vendorRouter } from "./vendor.routes.js";

export const router: RouterType = Router();
router.use("/auth", authRouter);
router.use("/organizers", organizerRouter);
router.use("/event-groups", eventGroupRouter);
router.use("/tasks", taskRouter);
router.use("/task-categories", taskCategoryRouter);
router.use("/admin", adminRouter);
router.use("/vendors", vendorRouter);
