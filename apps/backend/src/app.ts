import cors from "cors";
import helmet from "helmet";
import express, { type Express } from "express";
import { env } from "./lib/env.js";
import { router } from "./routes/index.js";
import { errorMiddleware } from "./middleware/error.middleware.js";

export function createApp(): Express {
  const app = express();
  app.disable("x-powered-by");
  app.set("trust proxy", 1); // behind Render's proxy: req.ip is the real client
  app.use(helmet());
  app.use(cors({ origin: env.ADMIN_APP_ORIGIN }));
  app.use(express.json({ limit: "100kb" }));
  app.get("/health", (_req, res) => {
    res.status(200).json({ status: "ok" });
  });
  app.use(router);
  app.use(errorMiddleware);
  return app;
}
