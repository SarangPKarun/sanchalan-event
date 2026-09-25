import { randomInt } from "node:crypto";

/** Uniform 6-digit code, including leading zeros (e.g. "003482"). CSPRNG, not Math.random. */
export function generateOtp(): string {
  return randomInt(0, 1_000_000).toString().padStart(6, "0");
}
