import { Router, type Router as RouterType } from "express";
import {
  requestOtpHandler,
  verifyOtpHandler,
  refreshHandler,
  logoutHandler,
} from "../controllers/auth.controller.js";

export const authRouter: RouterType = Router();
authRouter.post("/otp/request", requestOtpHandler);
authRouter.post("/otp/verify", verifyOtpHandler);
authRouter.post("/refresh", refreshHandler);
authRouter.post("/logout", logoutHandler);
