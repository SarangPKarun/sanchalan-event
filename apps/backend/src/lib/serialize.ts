import type { Prisma } from "@prisma/client";

export function toNumber(d: Prisma.Decimal | number): number {
  return typeof d === "number" ? d : d.toNumber();
}

/** Normalizes a Prisma `@db.Date` value back to a bare YYYY-MM-DD string,
 * matching the format the client sends on write (Date's default toJSON()
 * would otherwise emit a full UTC-midnight timestamp). */
export function toDateOnly(d: Date): string {
  return d.toISOString().slice(0, 10);
}
