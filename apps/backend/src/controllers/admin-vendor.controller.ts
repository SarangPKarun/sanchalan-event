import type { NextFunction, Request, Response } from "express";
import { bulkVendorSchema, listVendorsQuerySchema } from "../schemas/admin-list.schema.js";
import {
  rejectVendorSchema,
  suspendVendorSchema,
  vendorIdParamSchema,
} from "../schemas/admin-vendor.schema.js";
import * as adminVendorService from "../services/admin-vendor.service.js";

export async function listVendorsHandler(req: Request, res: Response, next: NextFunction) {
  try {
    res.status(200).json(await adminVendorService.listVendors(listVendorsQuerySchema.parse(req.query)));
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

export async function getVendorHandler(req: Request, res: Response, next: NextFunction) {
  try {
    const { id } = vendorIdParamSchema.parse(req.params);
    res.status(200).json(await adminVendorService.getVendor(id));
  } catch (err) {
    next(err);
  }
}

export async function suspendVendorHandler(req: Request, res: Response, next: NextFunction) {
  try {
    const { id } = vendorIdParamSchema.parse(req.params);
    const { reason } = suspendVendorSchema.parse(req.body);
    res.status(200).json(await adminVendorService.suspendVendor(id, req.auth!.userId, reason));
  } catch (err) {
    next(err);
  }
}

export async function unsuspendVendorHandler(req: Request, res: Response, next: NextFunction) {
  try {
    const { id } = vendorIdParamSchema.parse(req.params);
    res.status(200).json(await adminVendorService.unsuspendVendor(id, req.auth!.userId));
  } catch (err) {
    next(err);
  }
}

export async function bulkVendorsHandler(req: Request, res: Response, next: NextFunction) {
  try {
    res.status(200).json({ results: await adminVendorService.bulkDecide(req.auth!.userId, bulkVendorSchema.parse(req.body)) });
  } catch (err) {
    next(err);
  }
}
