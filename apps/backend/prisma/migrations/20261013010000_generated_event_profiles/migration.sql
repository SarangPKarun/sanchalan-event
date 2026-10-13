-- CreateEnum
CREATE TYPE "GeneratedProfileStatus" AS ENUM ('draft', 'approved', 'rejected');

-- CreateTable
CREATE TABLE "generated_event_profiles" (
    "id" UUID NOT NULL,
    "organizer_id" UUID NOT NULL,
    "description" TEXT NOT NULL,
    "profile" JSONB NOT NULL,
    "status" "GeneratedProfileStatus" NOT NULL DEFAULT 'draft',
    "llm_model_used" TEXT NOT NULL,
    "input_tokens" INTEGER NOT NULL DEFAULT 0,
    "output_tokens" INTEGER NOT NULL DEFAULT 0,
    "latency_ms" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "generated_event_profiles_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "generated_event_profiles_organizer_id_idx" ON "generated_event_profiles"("organizer_id");

-- CreateIndex
CREATE INDEX "generated_event_profiles_status_created_at_idx" ON "generated_event_profiles"("status", "created_at");

-- AddForeignKey
ALTER TABLE "generated_event_profiles" ADD CONSTRAINT "generated_event_profiles_organizer_id_fkey" FOREIGN KEY ("organizer_id") REFERENCES "organizers"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

