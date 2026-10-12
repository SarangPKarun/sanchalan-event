-- CreateEnum
CREATE TYPE "RoadmapGenerationStatus" AS ENUM ('success', 'failed');

-- AlterTable
ALTER TABLE "roadmap_generation_logs" ADD COLUMN     "attempts" INTEGER,
ADD COLUMN     "error" TEXT,
ADD COLUMN     "input_tokens" INTEGER,
ADD COLUMN     "latency_ms" INTEGER,
ADD COLUMN     "output_tokens" INTEGER,
ADD COLUMN     "status" "RoadmapGenerationStatus" NOT NULL DEFAULT 'success',
ALTER COLUMN "raw_output" DROP NOT NULL;

-- CreateIndex
CREATE INDEX "roadmap_generation_logs_created_at_idx" ON "roadmap_generation_logs"("created_at");

-- CreateIndex
CREATE INDEX "roadmap_generation_logs_status_created_at_idx" ON "roadmap_generation_logs"("status", "created_at");
