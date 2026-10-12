import { randomBytes } from "node:crypto";
import type { AdminRole, AdminStatus, Prisma } from "@prisma/client";
import { prisma } from "../lib/prisma.js";
import { AppError } from "../lib/errors.js";
import { hashPassword, hashRefreshToken, verifyPassword } from "../lib/hash.js";
import { refreshTokenExpiry, signAccessToken, signRefreshToken } from "../lib/jwt.js";
import { audit } from "../lib/audit.js";

type Tx = Prisma.TransactionClient;

const PUBLIC_FIELDS = {
  id: true,
  name: true,
  email: true,
  role: true,
  status: true,
  mustChangePassword: true,
  lastLoginAt: true,
  createdAt: true,
} satisfies Prisma.AdminSelect;

const tempPassword = () => randomBytes(12).toString("base64url");

function revokeSessions(tx: Tx, adminId: string) {
  return tx.refreshToken.updateMany({
    where: { userId: adminId, role: "admin", revokedAt: null },
    data: { revokedAt: new Date() },
  });
}

async function activeSuperAdminCount(tx: Tx) {
  return tx.admin.count({ where: { role: "super_admin", status: "active" } });
}

export async function listAdmins() {
  return { admins: await prisma.admin.findMany({ select: PUBLIC_FIELDS, orderBy: { createdAt: "asc" } }) };
}

export async function createAdmin(
  actorId: string,
  input: { name: string; email: string; role: AdminRole }
) {
  if (await prisma.admin.findUnique({ where: { email: input.email } }))
    throw new AppError(409, "An admin with this email already exists");

  const password = tempPassword();
  const admin = await prisma.$transaction(async (tx) => {
    const created = await tx.admin.create({
      data: { ...input, passwordHash: await hashPassword(password), mustChangePassword: true },
      select: PUBLIC_FIELDS,
    });
    await audit(
      { adminId: actorId, action: "admin.created", entityType: "admin", entityId: created.id, metadata: { role: input.role } },
      tx
    );
    return created;
  });
  // The temporary password is shown once; the new admin must change it at first sign-in.
  return { admin, temporaryPassword: password };
}

export async function updateAdmin(
  actorId: string,
  id: string,
  input: { role?: AdminRole | undefined; status?: AdminStatus | undefined }
) {
  return prisma.$transaction(async (tx) => {
    const target = await tx.admin.findUnique({ where: { id } });
    if (!target) throw new AppError(404, "Admin not found");

    const losesSuper =
      target.role === "super_admin" &&
      target.status === "active" &&
      ((input.role && input.role !== "super_admin") || input.status === "disabled");
    if (id === actorId && (input.status === "disabled" || (input.role && input.role !== target.role)))
      throw new AppError(409, "You cannot change your own role or disable yourself");
    if (losesSuper && (await activeSuperAdminCount(tx)) <= 1)
      throw new AppError(409, "There must be at least one active super admin");

    const updated = await tx.admin.update({
      where: { id },
      data: {
        ...(input.role ? { role: input.role } : {}),
        ...(input.status ? { status: input.status } : {}),
      },
      select: PUBLIC_FIELDS,
    });
    if (input.status === "disabled" || (input.role && input.role !== target.role))
      await revokeSessions(tx, id);
    await audit(
      { adminId: actorId, action: "admin.updated", entityType: "admin", entityId: id, metadata: { ...input } },
      tx
    );
    return updated;
  });
}

export async function resetAdminPassword(actorId: string, id: string) {
  const password = tempPassword();
  await prisma.$transaction(async (tx) => {
    const { count } = await tx.admin.updateMany({
      where: { id },
      data: {
        passwordHash: await hashPassword(password),
        mustChangePassword: true,
        failedLogins: 0,
        lockedUntil: null,
      },
    });
    if (count === 0) throw new AppError(404, "Admin not found");
    await revokeSessions(tx, id);
    await audit({ adminId: actorId, action: "admin.password_reset", entityType: "admin", entityId: id }, tx);
  });
  return { temporaryPassword: password };
}

/** Changes the caller's password, ends every session and signs them back in with fresh tokens. */
export async function changeOwnPassword(adminId: string, currentPassword: string, newPassword: string) {
  const admin = await prisma.admin.findUnique({ where: { id: adminId } });
  if (!admin) throw new AppError(401, "Admin not found");
  if (!(await verifyPassword(currentPassword, admin.passwordHash)))
    throw new AppError(400, "Current password is incorrect");
  if (currentPassword === newPassword)
    throw new AppError(400, "Choose a password different from the current one");

  const accessToken = signAccessToken({ sub: admin.id, role: "admin", adminRole: admin.role });
  const { token: refreshToken, jti } = signRefreshToken({ sub: admin.id, role: "admin" });
  const tokenHash = await hashRefreshToken(refreshToken);

  await prisma.$transaction(async (tx) => {
    await tx.admin.update({
      where: { id: adminId },
      data: { passwordHash: await hashPassword(newPassword), mustChangePassword: false },
    });
    await revokeSessions(tx, adminId);
    await tx.refreshToken.create({
      data: { id: jti, tokenHash, userId: adminId, role: "admin", expiresAt: refreshTokenExpiry(refreshToken) },
    });
    await audit({ adminId, action: "admin.password_changed", entityType: "admin", entityId: adminId }, tx);
  });
  return { accessToken, refreshToken };
}

export async function logoutEverywhere(adminId: string) {
  await prisma.$transaction(async (tx) => {
    await revokeSessions(tx, adminId);
    await audit({ adminId, action: "auth.logout_all" }, tx);
  });
}
