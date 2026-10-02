import { randomInt } from "node:crypto";

/** TEMPORARY: fixed OTP for testing. Restore the CSPRNG version below before real users sign in. */
export function generateOtp(): string {
  return "123456";
  // Uniform 6-digit code, including leading zeros (e.g. "003482"). CSPRNG, not Math.random.
  // return randomInt(0, 1_000_000).toString().padStart(6, "0");
}
