import type { NextFunction, Request, Response } from "express";
import {
  listVendorsQuerySchema,
  rejectVendorSchema,
  vendorIdParamSchema,
} from "../schemas/admin-vendor.schema.js";
import * as adminVendorService from "../services/admin-vendor.service.js";

export async function listVendorsHandler(req: Request, res: Response, next: NextFunction) {
  try {
    const { status } = listVendorsQuerySchema.parse(req.query);
    res.status(200).json({ vendors: await adminVendorService.listVendors(status) });
  } catch (err) {
    next(err);
  }
}

export async function approveVendorHandler(req: Request, res: Response, next: NextFunction) {
  try {
    const { id } = vendorIdParamSchema.parse(req.params);
    res.status(200).json(await adminVendorService.approveVendor(id, req.auth!.userId));
  } catch (err) {
    next(err);
  }
}

export async function rejectVendorHandler(req: Request, res: Response, next: NextFunction) {
  try {
    const { id } = vendorIdParamSchema.parse(req.params);
    const { reason } = rejectVendorSchema.parse(req.body);
    res.status(200).json(await adminVendorService.rejectVendor(id, req.auth!.userId, reason));
  } catch (err) {
    next(err);
  }
}
