import type { NextFunction, Request, Response } from "express";
import { idParamSchema } from "../schemas/event-group.schema.js";
import * as roadmapService from "../services/roadmap.service.js";

export async function generateRoadmapHandler(req: Request, res: Response, next: NextFunction) {
  try {
    const { id } = idParamSchema.parse(req.params);
    const tasks = await roadmapService.generateRoadmap(req.auth!.userId, id);
    res.status(201).json({ tasks });
  } catch (err) {
    next(err);
  }
}
