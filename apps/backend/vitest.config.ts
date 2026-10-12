import { defineConfig } from "vitest/config";

// Service tests that touch the database only run when TEST_DATABASE_URL points at a throwaway
// database (never the shared Neon one). Everything else needs no database.
const testDb = process.env["TEST_DATABASE_URL"];

export default defineConfig({
  test: {
    include: ["src/**/*.test.ts"],
    fileParallelism: false,
    env: {
      DATABASE_URL: testDb ?? "postgresql://unused:unused@localhost:1/unused",
      JWT_ACCESS_SECRET: "test-access-secret-test-access-secret",
      JWT_REFRESH_SECRET: "test-refresh-secret-test-refresh-secret",
      OTP_PROVIDER_API_KEY: "x",
      LLM_PROVIDER: "google",
      LLM_MODEL: "x",
      LLM_API_KEY: "x",
    },
  },
});
