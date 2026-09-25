import cors from "cors";
import express, { type Express } from "express";
import { env } from "./lib/env.js";
import { router } from "./routes/index.js";
import { errorMiddleware } from "./middleware/error.middleware.js";

export function createApp(): Express {
  const app = express();
  app.use(cors({ origin: env.ADMIN_APP_ORIGIN }));
  app.use(express.json());
  app.use(router);
  app.use(errorMiddleware);
  return app;
}
