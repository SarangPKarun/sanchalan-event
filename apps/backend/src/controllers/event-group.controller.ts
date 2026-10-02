import type { NextFunction, Request, Response } from "express";
import {
  createEventGroupSchema,
  updateEventGroupSchema,
  idParamSchema,
  categoryIdParamSchema,
  updateBudgetCategorySchema,
  createBudgetCategorySchema,
} from "../schemas/event-group.schema.js";
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

export async function updateBudgetCategoryHandler(req: Request, res: Response, next: NextFunction) {
  try {
    const { id, categoryId } = categoryIdParamSchema.parse(req.params);
    const input = updateBudgetCategorySchema.parse(req.body);
    res
      .status(200)
      .json(await eventGroupService.updateBudgetCategory(req.auth!.userId, id, categoryId, input));
  } catch (err) {
    next(err);
  }
}

export async function createBudgetCategoryHandler(req: Request, res: Response, next: NextFunction) {
  try {
    const { id } = idParamSchema.parse(req.params);
    const input = createBudgetCategorySchema.parse(req.body);
    res.status(201).json(await eventGroupService.createBudgetCategory(req.auth!.userId, id, input));
  } catch (err) {
    next(err);
  }
}

export async function updateEventGroupHandler(req: Request, res: Response, next: NextFunction) {
  try {
    const { id } = idParamSchema.parse(req.params);
    const input = updateEventGroupSchema.parse(req.body);
    res.status(200).json(await eventGroupService.updateEventGroup(req.auth!.userId, id, input));
  } catch (err) {
    next(err);
  }
}

export async function deleteBudgetCategoryHandler(req: Request, res: Response, next: NextFunction) {
  try {
    const { id, categoryId } = categoryIdParamSchema.parse(req.params);
    res
      .status(200)
      .json(await eventGroupService.deleteBudgetCategory(req.auth!.userId, id, categoryId));
  } catch (err) {
    next(err);
  }
}
