import bcrypt from "bcryptjs";
import { createHash } from "node:crypto";

const BCRYPT_ROUNDS = 10;

// Low-entropy secret (6-digit OTP) — bcrypt directly, like a password.
export async function hashOtp(otp: string): Promise<string> {
  return bcrypt.hash(otp, BCRYPT_ROUNDS);
}
export async function verifyOtpHash(otp: string, hash: string): Promise<boolean> {
  return bcrypt.compare(otp, hash);
}

// High-entropy secret (signed JWT refresh token, routinely 200+ bytes). bcrypt
// silently truncates input at 72 bytes, so hashing the raw JWT directly would
// only ever validate its first ~72 bytes. SHA-256 the token to a fixed 64-char
// digest first, then bcrypt that — still bcrypt end to end, no truncation.
export async function hashRefreshToken(token: string): Promise<string> {
  const digest = createHash("sha256").update(token).digest("hex");
  return bcrypt.hash(digest, BCRYPT_ROUNDS);
}
export async function verifyRefreshTokenHash(token: string, hash: string): Promise<boolean> {
  const digest = createHash("sha256").update(token).digest("hex");
  return bcrypt.compare(digest, hash);
}
