import type { AdminRole } from "@sanchalan/shared-types";

/** Every admin write is one of these. Reads are open to all admin roles unless noted. */
export type AdminAction =
  | "vendor.review"
  | "category.review"
  | "category.manage"
  | "organizer.manage"
  | "review.moderate"
  | "team.manage"
  | "audit.read";

const MATRIX: Record<AdminRole, readonly AdminAction[]> = {
  super_admin: [
    "vendor.review",
    "category.review",
    "category.manage",
    "organizer.manage",
    "review.moderate",
    "team.manage",
    "audit.read",
  ],
  vendor_reviewer: ["vendor.review", "category.review", "category.manage", "review.moderate"],
  support: [],
};

export function permissionsFor(role: AdminRole): readonly AdminAction[] {
  return MATRIX[role];
}

export function can(role: AdminRole, action: AdminAction): boolean {
  return MATRIX[role].includes(action);
}
