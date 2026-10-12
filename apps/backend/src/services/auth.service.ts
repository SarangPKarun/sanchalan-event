import type { AdminRole, AuthRole } from "@sanchalan/shared-types";
import { env } from "../lib/env.js";
import { prisma } from "../lib/prisma.js";
import { generateOtp } from "../lib/otp.js";
import { hashOtp, verifyOtpHash, hashRefreshToken, verifyRefreshTokenHash } from "../lib/hash.js";
import { sendOtpSms } from "../lib/msg91.js";
import { AppError } from "../lib/errors.js";
import {
  signAccessToken,
  signRefreshToken,
  refreshTokenExpiry,
  verifyRefreshToken,
  decodeRefreshTokenForRevocation,
} from "../lib/jwt.js";

export async function requestOtp(phoneNumber: string, role: AuthRole) {
  const windowStart = new Date(Date.now() - env.OTP_REQUEST_WINDOW_MINUTES * 60_000);
  const recentCount = await prisma.otpRequest.count({
    where: { phoneNumber, createdAt: { gte: windowStart } },
  });
  if (recentCount >= env.OTP_MAX_REQUESTS_PER_WINDOW) {
    throw new AppError(429, "Too many OTP requests. Please try again later.");
  }

  const existing =
    role === "organizer"
      ? await prisma.organizer.findUnique({ where: { phoneNumber } })
      : await prisma.vendor.findUnique({ where: { phoneNumber } });
  const purpose = existing ? "login" : role === "organizer" ? "organizer_signup" : "vendor_signup";

  const otp = generateOtp();
  const otpHash = await hashOtp(otp);
  const expiresAt = new Date(Date.now() + env.OTP_EXPIRES_IN_MINUTES * 60_000);

  await prisma.otpRequest.create({ data: { phoneNumber, role, otpHash, purpose, expiresAt } });

  if (env.NODE_ENV === "production") {
    await sendOtpSms(phoneNumber, otp);
  } else {
    // Dev/local convenience — skip the real MSG91 call so the endpoint is
    // testable without spending SMS credits or needing a live provider key.
    console.log(`[dev] OTP for ${phoneNumber} (${role}): ${otp}`);
  }

  return { expiresInSeconds: env.OTP_EXPIRES_IN_MINUTES * 60 };
}

export async function verifyOtp(phoneNumber: string, otp: string, role: AuthRole) {
  const otpRow = await prisma.otpRequest.findFirst({
    where: { phoneNumber, role },
    orderBy: { createdAt: "desc" },
  });

  if (!otpRow) throw new AppError(400, "No OTP request found for this phone number");
  if (otpRow.consumedAt) throw new AppError(400, "OTP already used. Please request a new one.");
  if (otpRow.attemptCount >= env.OTP_MAX_VERIFY_ATTEMPTS) {
    throw new AppError(400, "Too many incorrect attempts. Please request a new OTP.");
  }
  if (otpRow.expiresAt < new Date()) {
    throw new AppError(400, "OTP expired. Please request a new one.");
  }

  const isValid = await verifyOtpHash(otp, otpRow.otpHash);
  if (!isValid) {
    await prisma.otpRequest.update({
      where: { id: otpRow.id },
      data: { attemptCount: { increment: 1 } },
    });
    throw new AppError(400, "Invalid OTP");
  }

  await prisma.otpRequest.update({ where: { id: otpRow.id }, data: { consumedAt: new Date() } });

  const userId = await findOrCreateUser(phoneNumber, role);
  if (role === "organizer") await assertOrganizerActive(userId);

  const accessToken = signAccessToken({ sub: userId, role });
  const { token: refreshToken, jti } = signRefreshToken({ sub: userId, role });
  const tokenHash = await hashRefreshToken(refreshToken);
  const refreshExpiresAt = refreshTokenExpiry(refreshToken);

  await prisma.refreshToken.create({
    data: { id: jti, tokenHash, userId, role, expiresAt: refreshExpiresAt },
  });

  return { accessToken, refreshToken, role, userId };
}

async function assertOrganizerActive(organizerId: string) {
  const o = await prisma.organizer.findUnique({ where: { id: organizerId }, select: { status: true } });
  if (o?.status === "suspended") throw new AppError(403, "Your account is suspended. Contact support.");
}

async function findOrCreateUser(phoneNumber: string, role: AuthRole): Promise<string> {
  if (role === "organizer") {
    const organizer = await prisma.organizer.upsert({
      where: { phoneNumber },
      update: {},
      create: { phoneNumber, status: "active" },
    });
    return organizer.id;
  }
  const vendor = await prisma.vendor.upsert({
    where: { phoneNumber },
    update: {},
    create: { phoneNumber, status: "draft" },
  });
  return vendor.id;
}

export async function refreshAccessToken(refreshToken: string) {
  let payload;
  try {
    payload = verifyRefreshToken(refreshToken);
  } catch {
    throw new AppError(401, "Invalid or expired refresh token");
  }

  const row = await prisma.refreshToken.findUnique({ where: { id: payload.jti } });
  if (!row || row.revokedAt || row.expiresAt < new Date()) {
    throw new AppError(401, "Refresh token revoked or expired");
  }

  const matches = await verifyRefreshTokenHash(refreshToken, row.tokenHash);
  if (!matches) throw new AppError(401, "Invalid refresh token");

  const role = row.role as AuthRole;
  if (role === "organizer") {
    const o = await prisma.organizer.findUnique({ where: { id: row.userId }, select: { status: true } });
    if (!o || o.status === "suspended") throw new AppError(401, "Refresh token revoked or expired");
  }
  let adminRole: AdminRole | undefined;
  if (role === "admin") {
    const admin = await prisma.admin.findUnique({ where: { id: row.userId } });
    if (!admin || admin.status !== "active") throw new AppError(401, "Refresh token revoked or expired");
    adminRole = admin.role;
  }

  return {
    accessToken: signAccessToken({
      sub: row.userId,
      role,
      ...(adminRole ? { adminRole } : {}),
    }),
  };
}

export async function logout(refreshToken: string): Promise<void> {
  let payload;
  try {
    payload = decodeRefreshTokenForRevocation(refreshToken);
  } catch {
    throw new AppError(401, "Invalid refresh token");
  }
  await prisma.refreshToken.updateMany({
    where: { id: payload.jti, revokedAt: null },
    data: { revokedAt: new Date() },
  });
}
