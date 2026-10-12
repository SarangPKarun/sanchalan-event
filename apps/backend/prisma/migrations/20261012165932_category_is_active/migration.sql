-- AlterTable
ALTER TABLE "task_categories" ADD COLUMN     "is_active" BOOLEAN NOT NULL DEFAULT true;

-- AlterTable
ALTER TABLE "vendor_categories" ADD COLUMN     "is_active" BOOLEAN NOT NULL DEFAULT true;
