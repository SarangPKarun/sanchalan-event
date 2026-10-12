import type { NextFunction, Request, Response } from "express";
import {
  adminIdParamSchema,
  changePasswordSchema,
  createAdminSchema,
  updateAdminSchema,
} from "../schemas/admin-team.schema.js";
import * as team from "../services/admin-team.service.js";

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

export const listAdminsHandler = handle(() => team.listAdmins());
export const createAdminHandler = handle((req) => team.createAdmin(actor(req), createAdminSchema.parse(req.body)), 201);
export const updateAdminHandler = handle((req) =>
  team.updateAdmin(actor(req), adminIdParamSchema.parse(req.params).id, updateAdminSchema.parse(req.body))
);
export const resetPasswordHandler = handle((req) =>
  team.resetAdminPassword(actor(req), adminIdParamSchema.parse(req.params).id)
);
export const changePasswordHandler = handle((req) => {
  const { currentPassword, newPassword } = changePasswordSchema.parse(req.body);
  return team.changeOwnPassword(actor(req), currentPassword, newPassword);
});
export const logoutAllHandler = handle(async (req) => {
  await team.logoutEverywhere(actor(req));
  return undefined;
});
