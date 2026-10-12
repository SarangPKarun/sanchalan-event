-- CreateEnum
CREATE TYPE "ReviewStatus" AS ENUM ('visible', 'flagged', 'hidden');

-- AlterTable
ALTER TABLE "reviews" ADD COLUMN     "moderated_at" TIMESTAMP(3),
ADD COLUMN     "moderated_by" UUID,
ADD COLUMN     "moderation_reason" TEXT,
ADD COLUMN     "status" "ReviewStatus" NOT NULL DEFAULT 'visible';

-- CreateIndex
CREATE INDEX "reviews_status_created_at_idx" ON "reviews"("status", "created_at");

-- AddForeignKey
ALTER TABLE "reviews" ADD CONSTRAINT "reviews_moderated_by_fkey" FOREIGN KEY ("moderated_by") REFERENCES "admins"("id") ON DELETE SET NULL ON UPDATE CASCADE;
