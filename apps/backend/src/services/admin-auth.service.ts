import { prisma } from "../lib/prisma.js";
import { verifyPassword } from "../lib/hash.js";
import { hashRefreshToken } from "../lib/hash.js";
import { AppError } from "../lib/errors.js";
import { signAccessToken, signRefreshToken } from "../lib/jwt.js";

export async function adminLogin(email: string, password: string) {
  const admin = await prisma.admin.findUnique({ where: { email } });
  if (!admin || !(await verifyPassword(password, admin.passwordHash))) {
    throw new AppError(401, "Invalid credentials");
  }

  const accessToken = signAccessToken({ sub: admin.id, role: "admin", adminRole: admin.role });
  const { token: refreshToken, jti } = signRefreshToken({ sub: admin.id, role: "admin" });
  const tokenHash = await hashRefreshToken(refreshToken);
  const refreshExpiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);

  await prisma.refreshToken.create({
    data: { id: jti, tokenHash, userId: admin.id, role: "admin", expiresAt: refreshExpiresAt },
  });

  return { accessToken, refreshToken, role: "admin" as const, userId: admin.id, adminRole: admin.role };
}
