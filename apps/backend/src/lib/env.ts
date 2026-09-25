import { z } from "zod";

const envSchema = z.object({
  DATABASE_URL: z.string().min(1),
  PORT: z.coerce.number().default(3000),
  NODE_ENV: z.enum(["development", "test", "production"]).default("development"),

  JWT_ACCESS_SECRET: z.string().min(32),
  JWT_REFRESH_SECRET: z.string().min(32),
  JWT_ACCESS_EXPIRES_IN: z.string().default("15m"),
  JWT_REFRESH_EXPIRES_IN: z.string().default("30d"),

  OTP_PROVIDER_API_KEY: z.string().min(1),
  OTP_PROVIDER_BASE_URL: z.string().default("https://api.msg91.com/api/v5/otp"),

  OTP_EXPIRES_IN_MINUTES: z.coerce.number().default(5),
  OTP_MAX_REQUESTS_PER_WINDOW: z.coerce.number().default(3),
  OTP_REQUEST_WINDOW_MINUTES: z.coerce.number().default(10),
  OTP_MAX_VERIFY_ATTEMPTS: z.coerce.number().default(5),

  LLM_PROVIDER: z.enum(["anthropic", "openai", "google"]),
  LLM_MODEL: z.string().min(1),
  LLM_API_KEY: z.string().min(1),
});

export const env = envSchema.parse(process.env);
