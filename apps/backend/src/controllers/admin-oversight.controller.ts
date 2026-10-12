import type { NextFunction, Request, Response } from "express";
import {
  auditQuerySchema,
  idParamSchema,
  listEventsQuerySchema,
  listOrganizersQuerySchema,
  listRoadmapLogsQuerySchema,
  suspendOrganizerSchema,
} from "../schemas/admin-list.schema.js";
import * as o from "../services/admin-oversight.service.js";

type Handler = (req: Request) => Promise<unknown>;

function handle(fn: Handler, status = 200) {
  return async (req: Request, res: Response, next: NextFunction) => {
    try {
      res.status(status).json(await fn(req));
    } catch (err) {
      next(err);
    }
  };
}

const id = (req: Request) => idParamSchema.parse(req.params).id;

export const listOrganizersHandler = handle((req) => o.listOrganizers(listOrganizersQuerySchema.parse(req.query)));
export const getOrganizerHandler = handle((req) => o.getOrganizer(id(req)));
export const suspendOrganizerHandler = handle((req) =>
  o.setOrganizerStatus(req.auth!.userId, id(req), "suspended", suspendOrganizerSchema.parse(req.body).reason)
);
export const unsuspendOrganizerHandler = handle((req) => o.setOrganizerStatus(req.auth!.userId, id(req), "active"));
export const listEventsHandler = handle((req) => o.listEvents(listEventsQuerySchema.parse(req.query)));
export const getEventHandler = handle((req) => o.getEvent(id(req)));
export const listRoadmapLogsHandler = handle((req) => o.listRoadmapLogs(listRoadmapLogsQuerySchema.parse(req.query)));
export const getRoadmapLogHandler = handle((req) => o.getRoadmapLog(id(req)));
export const taskEditStatsHandler = handle(() => o.taskEditStats());
export const listAuditHandler = handle((req) => o.listAudit(auditQuerySchema.parse(req.query)));

export async function auditCsvHandler(req: Request, res: Response, next: NextFunction) {
  try {
    const csv = await o.auditCsv(auditQuerySchema.parse(req.query));
    res.setHeader("content-type", "text/csv; charset=utf-8");
    res.setHeader("content-disposition", 'attachment; filename="audit-log.csv"');
    res.status(200).send(csv);
  } catch (err) {
    next(err);
  }
}
