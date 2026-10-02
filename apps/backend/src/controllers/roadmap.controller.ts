import type { NextFunction, Request, Response } from "express";
import { idParamSchema } from "../schemas/event-group.schema.js";
import { generateRoadmapBodySchema } from "../schemas/roadmap.schema.js";
import * as roadmapService from "../services/roadmap.service.js";

export async function generateRoadmapHandler(req: Request, res: Response, next: NextFunction) {
  try {
    const { id } = idParamSchema.parse(req.params);
    const { mode } = generateRoadmapBodySchema.parse(req.body);
    const { tasks, removedTaskCount } = await roadmapService.generateRoadmap(
      req.auth!.userId,
      id,
      mode
    );
    res.status(201).json({ tasks, removedTaskCount });
  } catch (err) {
    next(err);
  }
}
