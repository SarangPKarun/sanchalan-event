import type { NextFunction, Request, Response } from "express";
import { updateProfileSchema } from "../schemas/organizer.schema.js";
import * as organizerService from "../services/organizer.service.js";

export async function getMeHandler(req: Request, res: Response, next: NextFunction) {
  try {
    res.status(200).json(await organizerService.getMe(req.auth!.userId));
  } catch (err) {
    next(err);
  }
}

export async function updateProfileHandler(req: Request, res: Response, next: NextFunction) {
  try {
    const input = updateProfileSchema.parse(req.body);
    res.status(200).json(await organizerService.updateProfile(req.auth!.userId, input));
  } catch (err) {
    next(err);
  }
}
