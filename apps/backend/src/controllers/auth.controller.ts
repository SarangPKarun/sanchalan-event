import type { NextFunction, Request, Response } from "express";
import {
  otpRequestSchema,
  otpVerifySchema,
  refreshSchema,
  logoutSchema,
} from "../schemas/auth.schema.js";
import * as authService from "../services/auth.service.js";

export async function requestOtpHandler(req: Request, res: Response, next: NextFunction) {
  try {
    const { phoneNumber, role } = otpRequestSchema.parse(req.body);
    res.status(200).json(await authService.requestOtp(phoneNumber, role));
  } catch (err) {
    next(err);
  }
}

export async function verifyOtpHandler(req: Request, res: Response, next: NextFunction) {
  try {
    const { phoneNumber, otp, role } = otpVerifySchema.parse(req.body);
    res.status(200).json(await authService.verifyOtp(phoneNumber, otp, role));
  } catch (err) {
    next(err);
  }
}

export async function refreshHandler(req: Request, res: Response, next: NextFunction) {
  try {
    const { refreshToken } = refreshSchema.parse(req.body);
    res.status(200).json(await authService.refreshAccessToken(refreshToken));
  } catch (err) {
    next(err);
  }
}

export async function logoutHandler(req: Request, res: Response, next: NextFunction) {
  try {
    const { refreshToken } = logoutSchema.parse(req.body);
    await authService.logout(refreshToken);
    res.status(204).send();
  } catch (err) {
    next(err);
  }
}
