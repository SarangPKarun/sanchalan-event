// Auth API contract (phone + OTP for organizers/vendors, email + password
// for admins). Deliberately NOT a mirror of the otp_requests/refresh_tokens
// tables — those hold server secrets (otp_hash, token_hash) that must never
// be serialized to a client.

import type { AdminRole } from "./enums.js";

export type AuthRole = "organizer" | "vendor" | "admin";

export interface OtpRequestBody {
  phoneNumber: string;
  role: AuthRole;
}

export interface OtpRequestResponseBody {
  expiresInSeconds: number;
}

export interface OtpVerifyBody {
  phoneNumber: string;
  otp: string;
  role: AuthRole;
}

export interface AuthTokens {
  accessToken: string;
  refreshToken: string;
  role: AuthRole;
  userId: string;
  adminRole?: AdminRole;
}

export interface AdminLoginBody {
  email: string;
  password: string;
}

export interface RefreshRequestBody {
  refreshToken: string;
}

export interface RefreshResponseBody {
  accessToken: string;
}

export interface LogoutRequestBody {
  refreshToken: string;
}
