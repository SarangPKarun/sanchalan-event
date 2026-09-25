import { env } from "./env.js";

export async function sendOtpSms(phoneNumber: string, otp: string): Promise<void> {
  const url = new URL(env.OTP_PROVIDER_BASE_URL);
  url.searchParams.set("mobile", phoneNumber.replace(/^\+/, ""));
  url.searchParams.set("otp", otp);

  const res = await fetch(url, {
    method: "POST",
    headers: { authkey: env.OTP_PROVIDER_API_KEY },
  });

  if (!res.ok) {
    throw new Error(`MSG91 send OTP failed: ${res.status} ${await res.text()}`);
  }
}
