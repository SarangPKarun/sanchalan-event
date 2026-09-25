import type { NextFunction, Request, Response } from "express";
import { createEventGroupSchema, idParamSchema } from "../schemas/event-group.schema.js";
import * as eventGroupService from "../services/event-group.service.js";

export async function createEventGroupHandler(req: Request, res: Response, next: NextFunction) {
  try {
    const input = createEventGroupSchema.parse(req.body);
    res.status(201).json(await eventGroupService.createEventGroup(req.auth!.userId, input));
  } catch (err) {
    next(err);
  }
}

export async function listMyEventGroupsHandler(req: Request, res: Response, next: NextFunction) {
  try {
    res.status(200).json(await eventGroupService.listMyEventGroups(req.auth!.userId));
  } catch (err) {
    next(err);
  }
}

export async function getEventGroupHandler(req: Request, res: Response, next: NextFunction) {
  try {
    const { id } = idParamSchema.parse(req.params);
    res.status(200).json(await eventGroupService.getEventGroupById(req.auth!.userId, id));
  } catch (err) {
    next(err);
  }
}
