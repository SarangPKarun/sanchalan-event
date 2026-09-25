import type { NextFunction, Request, Response } from "express";
import { adminLoginSchema } from "../schemas/admin-auth.schema.js";
import * as adminAuthService from "../services/admin-auth.service.js";

export async function adminLoginHandler(req: Request, res: Response, next: NextFunction) {
  try {
    const { email, password } = adminLoginSchema.parse(req.body);
    res.status(200).json(await adminAuthService.adminLogin(email, password));
  } catch (err) {
    next(err);
  }
}
