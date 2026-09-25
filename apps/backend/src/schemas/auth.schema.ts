import { z } from "zod";

export const authRoleSchema = z.enum(["organizer", "vendor"]);

const phoneNumberSchema = z
  .string()
  .regex(/^\+[1-9]\d{7,14}$/, "phoneNumber must be E.164, e.g. +919876543210");

export const otpRequestSchema = z.object({
  phoneNumber: phoneNumberSchema,
  role: authRoleSchema,
});
export type OtpRequestInput = z.infer<typeof otpRequestSchema>;

export const otpVerifySchema = z.object({
  phoneNumber: phoneNumberSchema,
  otp: z.string().regex(/^\d{6}$/, "otp must be a 6-digit code"),
  role: authRoleSchema,
});
export type OtpVerifyInput = z.infer<typeof otpVerifySchema>;

export const refreshSchema = z.object({ refreshToken: z.string().min(1) });
export type RefreshInput = z.infer<typeof refreshSchema>;

export const logoutSchema = z.object({ refreshToken: z.string().min(1) });
export type LogoutInput = z.infer<typeof logoutSchema>;
