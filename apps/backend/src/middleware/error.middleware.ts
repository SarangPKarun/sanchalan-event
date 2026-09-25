import type { NextFunction, Request, Response } from "express";
import { ZodError } from "zod";
import { AppError } from "../lib/errors.js";

export function errorMiddleware(
  err: unknown,
  _req: Request,
  res: Response,
  _next: NextFunction
): void {
  if (err instanceof ZodError) {
    res.status(400).json({ error: "Validation failed", details: err.issues });
    return;
  }
  if (err instanceof AppError) {
    res.status(err.status).json({
      error: err.message,
      ...(err.details !== undefined ? { details: err.details } : {}),
    });
    return;
  }
  console.error(err);
  res.status(500).json({ error: "Internal server error" });
}
