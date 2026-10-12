import { prisma } from "../lib/prisma.js";
import { hashPassword, hashRefreshToken, verifyPassword } from "../lib/hash.js";
import { AppError } from "../lib/errors.js";
import { refreshTokenExpiry, signAccessToken, signRefreshToken } from "../lib/jwt.js";
import { permissionsFor } from "../lib/admin-permissions.js";
import { audit } from "../lib/audit.js";
import { RateLimiter } from "../lib/rate-limit.js";

export const MAX_FAILED_LOGINS = 5;
export const LOCKOUT_MINUTES = 15;

// Per-IP guard on top of the per-account lockout, so one address cannot spray many emails.
const ipLimiter = new RateLimiter(20, 15 * 60_000);

// Compared against when the email is unknown, so response time does not reveal which emails exist.
const DUMMY_HASH_PROMISE = hashPassword("not-a-real-password");

function tooMany(seconds: number): never {
  throw new AppError(429, `Too many attempts. Try again in ${Math.ceil(seconds / 60)} minute(s).`, {
    retryAfterSeconds: Math.ceil(seconds),
  });
}

export async function adminLogin(email: string, password: string, ip?: string) {
  const wait = ipLimiter.take(ip ?? "unknown");
  if (wait > 0) tooMany(wait);

  const admin = await prisma.admin.findUnique({ where: { email } });

  if (admin?.lockedUntil && admin.lockedUntil > new Date()) {
    tooMany((admin.lockedUntil.getTime() - Date.now()) / 1000);
  }

  const hash = admin?.passwordHash ?? (await DUMMY_HASH_PROMISE);
  const passwordOk = await verifyPassword(password, hash);

  if (!admin || !passwordOk || admin.status !== "active") {
    if (admin && admin.status === "active") {
      const failed = admin.failedLogins + 1;
      const lock = failed >= MAX_FAILED_LOGINS;
      await prisma.admin.update({
        where: { id: admin.id },
        data: {
          failedLogins: lock ? 0 : failed,
          ...(lock ? { lockedUntil: new Date(Date.now() + LOCKOUT_MINUTES * 60_000) } : {}),
        },
      });
      await audit({ adminId: admin.id, action: lock ? "auth.locked" : "auth.login_failed", ip });
    }
    throw new AppError(401, "Invalid credentials");
  }

  await prisma.admin.update({
    where: { id: admin.id },
    data: { failedLogins: 0, lockedUntil: null, lastLoginAt: new Date() },
  });
  // Drop this admin's expired sessions so the table does not grow without bound.
  await prisma.refreshToken.deleteMany({
    where: { userId: admin.id, role: "admin", expiresAt: { lt: new Date() } },
  });

  const accessToken = signAccessToken({ sub: admin.id, role: "admin", adminRole: admin.role });
  const { token: refreshToken, jti } = signRefreshToken({ sub: admin.id, role: "admin" });
  await prisma.refreshToken.create({
    data: {
      id: jti,
      tokenHash: await hashRefreshToken(refreshToken),
      userId: admin.id,
      role: "admin",
      expiresAt: refreshTokenExpiry(refreshToken),
    },
  });
  await audit({ adminId: admin.id, action: "auth.login", ip });

  return {
    accessToken,
    refreshToken,
    role: "admin" as const,
    userId: admin.id,
    adminRole: admin.role,
    mustChangePassword: admin.mustChangePassword,
  };
}

export async function getAdminMe(adminId: string) {
  const admin = await prisma.admin.findUnique({ where: { id: adminId } });
  if (!admin) throw new AppError(401, "Admin not found");
  return {
    id: admin.id,
    name: admin.name,
    email: admin.email,
    role: admin.role,
    mustChangePassword: admin.mustChangePassword,
    permissions: permissionsFor(admin.role),
  };
}
