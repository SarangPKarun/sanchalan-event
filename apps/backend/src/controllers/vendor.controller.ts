import type { NextFunction, Request, Response } from "express";
import { listVendorsQuerySchema, vendorIdParamSchema } from "../schemas/vendor.schema.js";
import * as vendorService from "../services/vendor.service.js";

export async function listVendorsHandler(req: Request, res: Response, next: NextFunction) {
  try {
    const filters = listVendorsQuerySchema.parse(req.query);
    res.status(200).json({ vendors: await vendorService.listPublishedVendors(filters) });
  } catch (err) {
    next(err);
  }
}

export async function getVendorHandler(req: Request, res: Response, next: NextFunction) {
  try {
    const { id } = vendorIdParamSchema.parse(req.params);
    res.status(200).json(await vendorService.getPublishedVendor(id));
  } catch (err) {
    next(err);
  }
}
