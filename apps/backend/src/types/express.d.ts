import type { AdminRole, AuthRole } from "@sanchalan/shared-types";

declare global {
  namespace Express {
    interface Request {
      auth?: { userId: string; role: AuthRole; adminRole?: AdminRole };
    }
  }
}

export {};
