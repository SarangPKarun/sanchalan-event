import type { AuthRole } from "@sanchalan/shared-types";

declare global {
  namespace Express {
    interface Request {
      auth?: { userId: string; role: AuthRole };
    }
  }
}

export {};
