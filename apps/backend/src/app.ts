import express, { type Express } from "express";
import { router } from "./routes/index.js";
import { errorMiddleware } from "./middleware/error.middleware.js";

export function createApp(): Express {
  const app = express();
  app.use(express.json());
  app.use(router);
  app.use(errorMiddleware);
  return app;
}
