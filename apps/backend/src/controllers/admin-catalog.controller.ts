import type { NextFunction, Request, Response } from "express";
import {
  createTemplateSchema,
  idParamSchema,
  keyParamSchema,
  templatesQuerySchema,
  updateCategorySchema,
  updateTemplateSchema,
} from "../schemas/admin-list.schema.js";
import * as catalog from "../services/admin-catalog.service.js";

type Handler = (req: Request) => Promise<unknown>;

function handle(fn: Handler, status = 200) {
  return async (req: Request, res: Response, next: NextFunction) => {
    try {
      const body = await fn(req);
      if (body === undefined) res.status(204).end();
      else res.status(status).json(body);
    } catch (err) {
      next(err);
    }
  };
}

const actor = (req: Request) => req.auth!.userId;

export const statsHandler = handle(() => catalog.stats());
export const listCategoriesHandler = handle(() => catalog.listCategories());
export const updateCategoryHandler = handle((req) =>
  catalog.updateCategory(actor(req), keyParamSchema.parse(req.params).key, updateCategorySchema.parse(req.body))
);
export const listTemplatesHandler = handle((req) => catalog.listTemplates(templatesQuerySchema.parse(req.query).category));
export const createTemplateHandler = handle((req) => catalog.createTemplate(actor(req), createTemplateSchema.parse(req.body)), 201);
export const updateTemplateHandler = handle((req) =>
  catalog.updateTemplate(actor(req), idParamSchema.parse(req.params).id, updateTemplateSchema.parse(req.body))
);
export const deleteTemplateHandler = handle(async (req) => {
  await catalog.deleteTemplate(actor(req), idParamSchema.parse(req.params).id);
  return undefined;
});
export const draftTemplatesHandler = handle((req) => catalog.draftTemplates(idParamSchema.parse(req.params).id));
