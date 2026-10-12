import type { NextFunction, Request, Response } from "express";
import type { AdminRole, AuthRole } from "@sanchalan/shared-types";
import { verifyAccessToken } from "../lib/jwt.js";
import { prisma } from "../lib/prisma.js";

export function requireAuth(req: Request, res: Response, next: NextFunction): void {
  const header = req.headers.authorization;
  if (!header?.startsWith("Bearer ")) {
    res.status(401).json({ error: "Missing bearer token" });
    return;
  }
  try {
    const payload = verifyAccessToken(header.slice("Bearer ".length));
    req.auth = {
      userId: payload.sub,
      role: payload.role,
      ...(payload.adminRole ? { adminRole: payload.adminRole } : {}),
    };
    next();
  } catch {
    res.status(401).json({ error: "Invalid or expired token" });
  }
}

export function requireRole(...roles: AuthRole[]) {
  return (req: Request, res: Response, next: NextFunction): void => {
    if (!req.auth || !roles.includes(req.auth.role)) {
      res.status(403).json({ error: "Forbidden" });
      return;
    }
    next();
  };
}

export function requireAdminRole(...roles: AdminRole[]) {
  return (req: Request, res: Response, next: NextFunction): void => {
    if (!req.auth?.adminRole || !roles.includes(req.auth.adminRole)) {
      res.status(403).json({ error: "Forbidden" });
      return;
    }
    next();
  };
}

const PASSWORD_CHANGE_ALLOWED = new Set(["GET /me", "POST /me/password", "POST /me/logout-all"]);

/**
 * For admin routes: re-reads the admin so a disabled account or a changed role takes effect
 * immediately instead of when the 15-minute access token expires.
 */
export async function requireActiveAdmin(req: Request, res: Response, next: NextFunction) {
  try {
    const admin = await prisma.admin.findUnique({
      where: { id: req.auth!.userId },
      select: { role: true, status: true, mustChangePassword: true },
    });
    if (!admin || admin.status !== "active") {
      res.status(401).json({ error: "Invalid or expired token" });
      return;
    }
    req.auth!.adminRole = admin.role;
    // A temporary password must be replaced before anything else is allowed.
    if (admin.mustChangePassword && !PASSWORD_CHANGE_ALLOWED.has(`${req.method} ${req.path}`)) {
      res.status(403).json({ error: "Password change required", code: "password_change_required" });
      return;
    }
    next();
  } catch (err) {
    next(err);
  }
}

/** For organizer routes: a suspended organizer is blocked at once, not when the access token expires. */
export async function requireActiveOrganizer(req: Request, res: Response, next: NextFunction) {
  if (req.auth?.role !== "organizer") return next();
  try {
    const organizer = await prisma.organizer.findUnique({
      where: { id: req.auth.userId },
      select: { status: true },
    });
    if (organizer?.status === "suspended") {
      res.status(403).json({ error: "Your account is suspended. Contact support.", code: "account_suspended" });
      return;
    }
    next();
  } catch (err) {
    next(err);
  }
}
