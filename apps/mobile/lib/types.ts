// TODO: replace with imports from '@sanchalan/shared-types' (its auth.ts now
// exports these same shapes) — kept as a local shim only where a direct swap
// wasn't done yet.
export type Role = "organizer" | "vendor";

export type OtpRequestBody = { phoneNumber: string; role: Role };
export type OtpVerifyBody = { phoneNumber: string; otp: string; role: Role };
export type AuthTokens = { accessToken: string; refreshToken: string };
export type OtpVerifyResponse = AuthTokens & { role: Role; userId: string };
