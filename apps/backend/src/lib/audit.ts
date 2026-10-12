import type { Prisma } from "@prisma/client";
import { prisma } from "./prisma.js";

export interface AuditEntry {
  adminId: string | null;
  action: string;
  entityType?: string;
  entityId?: string;
  metadata?: Prisma.InputJsonValue;
  ip?: string | undefined;
}

/** Records an admin action. Pass `tx` to make it part of the same transaction as the change. */
export function audit(entry: AuditEntry, tx: Prisma.TransactionClient | typeof prisma = prisma) {
  return tx.adminAuditLog.create({
    data: {
      adminId: entry.adminId,
      action: entry.action,
      ...(entry.entityType ? { entityType: entry.entityType } : {}),
      ...(entry.entityId ? { entityId: entry.entityId } : {}),
      ...(entry.metadata !== undefined ? { metadata: entry.metadata } : {}),
      ...(entry.ip ? { ip: entry.ip } : {}),
    },
  });
}
