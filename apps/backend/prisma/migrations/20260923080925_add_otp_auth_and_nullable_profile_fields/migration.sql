-- CreateEnum
CREATE TYPE "AuthRole" AS ENUM ('organizer', 'vendor');

-- CreateEnum
CREATE TYPE "OtpPurpose" AS ENUM ('organizer_signup', 'vendor_signup', 'login');

-- AlterTable
ALTER TABLE "organizers" ALTER COLUMN "display_name" DROP NOT NULL,
ALTER COLUMN "organizer_type" DROP NOT NULL;

-- AlterTable
ALTER TABLE "vendors" ALTER COLUMN "business_name" DROP NOT NULL,
ALTER COLUMN "contact_person_name" DROP NOT NULL,
ALTER COLUMN "price_tier" DROP NOT NULL,
ALTER COLUMN "service_area" DROP NOT NULL;

-- CreateTable
CREATE TABLE "otp_requests" (
    "id" UUID NOT NULL,
    "phone_number" TEXT NOT NULL,
    "role" "AuthRole" NOT NULL,
    "otp_hash" TEXT NOT NULL,
    "purpose" "OtpPurpose" NOT NULL,
    "expires_at" TIMESTAMP(3) NOT NULL,
    "attempt_count" INTEGER NOT NULL DEFAULT 0,
    "consumed_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "otp_requests_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "refresh_tokens" (
    "id" UUID NOT NULL,
    "token_hash" TEXT NOT NULL,
    "user_id" UUID NOT NULL,
    "role" "AuthRole" NOT NULL,
    "expires_at" TIMESTAMP(3) NOT NULL,
    "revoked_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "refresh_tokens_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "otp_requests_phone_number_created_at_idx" ON "otp_requests"("phone_number", "created_at");

-- CreateIndex
CREATE INDEX "otp_requests_phone_number_role_created_at_idx" ON "otp_requests"("phone_number", "role", "created_at");
