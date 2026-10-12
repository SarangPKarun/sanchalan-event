-- CreateEnum
CREATE TYPE "CategoryProposalStatus" AS ENUM ('pending', 'approved', 'rejected', 'merged');

-- AlterTable
ALTER TABLE "task_categories" ADD COLUMN     "label" TEXT;

-- AlterTable
ALTER TABLE "vendor_categories" ADD COLUMN     "label" TEXT;

-- CreateTable
CREATE TABLE "category_proposals" (
    "id" UUID NOT NULL,
    "label" TEXT NOT NULL,
    "category_key" TEXT NOT NULL,
    "description" TEXT,
    "status" "CategoryProposalStatus" NOT NULL DEFAULT 'pending',
    "rejection_reason" TEXT,
    "submitted_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "reviewed_at" TIMESTAMP(3),
    "reviewed_by" UUID,
    "resolved_vendor_category_id" UUID,

    CONSTRAINT "category_proposals_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "category_proposal_vendors" (
    "proposal_id" UUID NOT NULL,
    "vendor_id" UUID NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "category_proposal_vendors_pkey" PRIMARY KEY ("proposal_id","vendor_id")
);

-- CreateIndex
CREATE INDEX "category_proposals_status_submitted_at_idx" ON "category_proposals"("status", "submitted_at");

-- CreateIndex
CREATE INDEX "category_proposals_category_key_idx" ON "category_proposals"("category_key");

-- AddForeignKey
ALTER TABLE "category_proposals" ADD CONSTRAINT "category_proposals_reviewed_by_fkey" FOREIGN KEY ("reviewed_by") REFERENCES "admins"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "category_proposals" ADD CONSTRAINT "category_proposals_resolved_vendor_category_id_fkey" FOREIGN KEY ("resolved_vendor_category_id") REFERENCES "vendor_categories"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "category_proposal_vendors" ADD CONSTRAINT "category_proposal_vendors_proposal_id_fkey" FOREIGN KEY ("proposal_id") REFERENCES "category_proposals"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "category_proposal_vendors" ADD CONSTRAINT "category_proposal_vendors_vendor_id_fkey" FOREIGN KEY ("vendor_id") REFERENCES "vendors"("id") ON DELETE CASCADE ON UPDATE CASCADE;
