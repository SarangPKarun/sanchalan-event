/*
  Warnings:

  - Existing portfolio rows get title 'Past work' (backfilled; default dropped afterwards).

*/
-- CreateEnum
CREATE TYPE "VendorReviewAction" AS ENUM ('submitted', 'withdrawn', 'approved', 'rejected', 'suspended', 'unsuspended', 'reverification_required');

-- DropForeignKey
ALTER TABLE "vendor_portfolio_items" DROP CONSTRAINT "vendor_portfolio_items_vendor_id_fkey";

-- DropForeignKey
ALTER TABLE "vendor_vendor_categories" DROP CONSTRAINT "vendor_vendor_categories_vendor_id_fkey";

-- AlterTable
ALTER TABLE "vendor_portfolio_items" ADD COLUMN     "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
ADD COLUMN     "title" TEXT NOT NULL DEFAULT 'Past work',
ALTER COLUMN "media_url" DROP NOT NULL,
ALTER COLUMN "display_order" SET DEFAULT 0;

-- AlterTable
ALTER TABLE "vendors" ADD COLUMN     "description" TEXT,
ADD COLUMN     "instagram_url" TEXT,
ADD COLUMN     "starting_price" INTEGER,
ADD COLUMN     "website_url" TEXT,
ADD COLUMN     "whatsapp_number" TEXT,
ADD COLUMN     "years_of_experience" INTEGER;

ALTER TABLE "vendor_portfolio_items" ALTER COLUMN "title" DROP DEFAULT;

-- CreateTable
CREATE TABLE "vendor_review_logs" (
    "id" UUID NOT NULL,
    "vendor_id" UUID NOT NULL,
    "admin_id" UUID,
    "action" "VendorReviewAction" NOT NULL,
    "reason" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "vendor_review_logs_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "vendor_review_logs_vendor_id_created_at_idx" ON "vendor_review_logs"("vendor_id", "created_at");

-- AddForeignKey
ALTER TABLE "vendor_vendor_categories" ADD CONSTRAINT "vendor_vendor_categories_vendor_id_fkey" FOREIGN KEY ("vendor_id") REFERENCES "vendors"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "vendor_portfolio_items" ADD CONSTRAINT "vendor_portfolio_items_vendor_id_fkey" FOREIGN KEY ("vendor_id") REFERENCES "vendors"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "vendor_review_logs" ADD CONSTRAINT "vendor_review_logs_vendor_id_fkey" FOREIGN KEY ("vendor_id") REFERENCES "vendors"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "vendor_review_logs" ADD CONSTRAINT "vendor_review_logs_admin_id_fkey" FOREIGN KEY ("admin_id") REFERENCES "admins"("id") ON DELETE SET NULL ON UPDATE CASCADE;
