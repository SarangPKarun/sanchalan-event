import type { NextFunction, Request, Response } from "express";
import {
  taskIdParamSchema,
  updateTaskSchema,
  createTaskSchema,
  listTasksQuerySchema,
} from "../schemas/task.schema.js";
import { idParamSchema } from "../schemas/event-group.schema.js";
import * as taskService from "../services/task.service.js";

export async function updateTaskHandler(req: Request, res: Response, next: NextFunction) {
  try {
    const { id } = taskIdParamSchema.parse(req.params);
    const input = updateTaskSchema.parse(req.body);
    res.status(200).json(await taskService.updateTask(req.auth!.userId, id, input));
  } catch (err) {
    next(err);
  }
}

export async function deleteTaskHandler(req: Request, res: Response, next: NextFunction) {
  try {
    const { id } = taskIdParamSchema.parse(req.params);
    res.status(200).json(await taskService.deleteTask(req.auth!.userId, id));
  } catch (err) {
    next(err);
  }
}

export async function createTaskHandler(req: Request, res: Response, next: NextFunction) {
  try {
    const { id } = idParamSchema.parse(req.params);
    const input = createTaskSchema.parse(req.body);
    res.status(201).json(await taskService.createTask(req.auth!.userId, id, input));
  } catch (err) {
    next(err);
  }
}

export async function listEventGroupTasksHandler(req: Request, res: Response, next: NextFunction) {
  try {
    const { id } = idParamSchema.parse(req.params);
    const { includeNotApplicable } = listTasksQuerySchema.parse(req.query);
    res.status(200).json({
      tasks: await taskService.listEventGroupTasks(req.auth!.userId, id, includeNotApplicable),
    });
  } catch (err) {
    next(err);
  }
}

export async function listTaskCategoriesHandler(_req: Request, res: Response, next: NextFunction) {
  try {
    res.status(200).json({ categories: await taskService.listTaskCategories() });
  } catch (err) {
    next(err);
  }
}
