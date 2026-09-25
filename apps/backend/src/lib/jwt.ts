import jwt from "jsonwebtoken";
import { randomUUID } from "node:crypto";
import type { AuthRole } from "@sanchalan/shared-types";
import { env } from "./env.js";

export interface AccessTokenPayload {
  sub: string;
  role: AuthRole;
}
export interface RefreshTokenPayload {
  sub: string;
  role: AuthRole;
  jti: string;
}

export function signAccessToken(payload: AccessTokenPayload): string {
  return jwt.sign(payload, env.JWT_ACCESS_SECRET, {
    expiresIn: env.JWT_ACCESS_EXPIRES_IN,
  } as jwt.SignOptions);
}

export function signRefreshToken(payload: { sub: string; role: AuthRole }): {
  token: string;
  jti: string;
} {
  const jti = randomUUID();
  const token = jwt.sign({ ...payload, jti }, env.JWT_REFRESH_SECRET, {
    expiresIn: env.JWT_REFRESH_EXPIRES_IN,
  } as jwt.SignOptions);
  return { token, jti };
}

export function verifyAccessToken(token: string): AccessTokenPayload {
  return jwt.verify(token, env.JWT_ACCESS_SECRET) as unknown as AccessTokenPayload;
}

export function verifyRefreshToken(token: string): RefreshTokenPayload {
  return jwt.verify(token, env.JWT_REFRESH_SECRET) as unknown as RefreshTokenPayload;
}

/** For logout: validate signature but tolerate an already-expired token —
 * revoking an expired session is harmless and should still succeed. */
export function decodeRefreshTokenForRevocation(token: string): RefreshTokenPayload {
  return jwt.verify(token, env.JWT_REFRESH_SECRET, {
    ignoreExpiration: true,
  }) as unknown as RefreshTokenPayload;
}
