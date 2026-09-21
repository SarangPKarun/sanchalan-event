-- CreateEnum
CREATE TYPE "OrganizerType" AS ENUM ('individual', 'family', 'company', 'committee');

-- CreateEnum
CREATE TYPE "OrganizerStatus" AS ENUM ('active', 'suspended');

-- CreateEnum
CREATE TYPE "VendorPriceTier" AS ENUM ('essential', 'standard', 'premium', 'luxury');

-- CreateEnum
CREATE TYPE "VendorStatus" AS ENUM ('draft', 'pending_review', 'published', 'rejected', 'suspended');

-- CreateEnum
CREATE TYPE "AdminRole" AS ENUM ('super_admin', 'vendor_reviewer', 'support');

-- CreateEnum
CREATE TYPE "EventGroupRole" AS ENUM ('owner', 'editor', 'viewer', 'approver');

-- CreateEnum
CREATE TYPE "EventType" AS ENUM ('wedding', 'birthday', 'corporate', 'religious', 'engagement_only', 'custom');

-- CreateEnum
CREATE TYPE "BudgetTier" AS ENUM ('essential', 'standard', 'premium', 'luxury');

-- CreateEnum
CREATE TYPE "EventGroupStatus" AS ENUM ('planning', 'active', 'completed', 'archived');

-- CreateEnum
CREATE TYPE "SubEventStatus" AS ENUM ('planned', 'in_progress', 'completed', 'cancelled');

-- CreateEnum
CREATE TYPE "RsvpStatus" AS ENUM ('pending', 'confirmed', 'declined', 'no_response');

-- CreateEnum
CREATE TYPE "TaskOwnerType" AS ENUM ('organizer', 'vendor', 'planner');

-- CreateEnum
CREATE TYPE "TaskStatus" AS ENUM ('not_started', 'in_progress', 'done', 'overdue', 'not_applicable');

-- CreateEnum
CREATE TYPE "TaskSource" AS ENUM ('ai_generated', 'template_default', 'user_added');

-- CreateEnum
CREATE TYPE "TaskEditAction" AS ENUM ('created', 'edited', 'status_changed', 'deleted', 'reordered', 'marked_not_applicable');

-- CreateEnum
CREATE TYPE "BudgetEntryType" AS ENUM ('planned', 'actual');

-- CreateEnum
CREATE TYPE "BookingStatus" AS ENUM ('requested', 'confirmed', 'cancelled', 'completed');

-- CreateEnum
CREATE TYPE "PaymentMilestoneType" AS ENUM ('advance', 'midpoint', 'final');

-- CreateEnum
CREATE TYPE "PaymentStatus" AS ENUM ('pending', 'paid', 'overdue');

-- CreateEnum
CREATE TYPE "VendorAvailabilityStatus" AS ENUM ('available', 'booked', 'blocked');

-- CreateEnum
CREATE TYPE "DocumentType" AS ENUM ('id_proof', 'vendor_contract', 'payment_receipt', 'marriage_registration_doc', 'other');

-- CreateEnum
CREATE TYPE "ThankYouStatus" AS ENUM ('pending', 'sent');

-- CreateEnum
CREATE TYPE "NotificationRecipientType" AS ENUM ('organizer', 'vendor', 'guest');

-- CreateEnum
CREATE TYPE "NotificationChannel" AS ENUM ('whatsapp', 'push', 'sms');

-- CreateEnum
CREATE TYPE "NotificationStatus" AS ENUM ('sent', 'delivered', 'failed');

-- CreateEnum
CREATE TYPE "ProductionPipelineStatus" AS ENUM ('pending', 'assigned', 'in_production', 'delivered', 'cancelled');

-- CreateTable
CREATE TABLE "organizers" (
    "id" UUID NOT NULL,
    "phone_number" TEXT NOT NULL,
    "email" TEXT,
    "display_name" TEXT NOT NULL,
    "organizer_type" "OrganizerType" NOT NULL,
    "preferred_language" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "status" "OrganizerStatus" NOT NULL,

    CONSTRAINT "organizers_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "vendors" (
    "id" UUID NOT NULL,
    "business_name" TEXT NOT NULL,
    "contact_person_name" TEXT NOT NULL,
    "phone_number" TEXT NOT NULL,
    "email" TEXT,
    "price_tier" "VendorPriceTier" NOT NULL,
    "service_area" TEXT NOT NULL,
    "status" "VendorStatus" NOT NULL,
    "rejection_reason" TEXT,
    "submitted_at" TIMESTAMP(3),
    "reviewed_at" TIMESTAMP(3),
    "reviewed_by" UUID,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "vendors_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "vendor_categories" (
    "id" UUID NOT NULL,
    "category_key" TEXT NOT NULL,
    "applicable_event_types" "EventType"[],

    CONSTRAINT "vendor_categories_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "vendor_vendor_categories" (
    "vendor_id" UUID NOT NULL,
    "vendor_category_id" UUID NOT NULL,

    CONSTRAINT "vendor_vendor_categories_pkey" PRIMARY KEY ("vendor_id","vendor_category_id")
);

-- CreateTable
CREATE TABLE "vendor_portfolio_items" (
    "id" UUID NOT NULL,
    "vendor_id" UUID NOT NULL,
    "media_url" TEXT NOT NULL,
    "caption" TEXT,
    "display_order" INTEGER NOT NULL,

    CONSTRAINT "vendor_portfolio_items_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "admins" (
    "id" UUID NOT NULL,
    "name" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "password_hash" TEXT NOT NULL,
    "role" "AdminRole" NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "admins_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "role_permissions" (
    "id" UUID NOT NULL,
    "event_group_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "role" "EventGroupRole" NOT NULL,
    "invited_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "role_permissions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "event_groups" (
    "id" UUID NOT NULL,
    "organizer_id" UUID NOT NULL,
    "event_type" "EventType" NOT NULL,
    "name" TEXT NOT NULL,
    "region" TEXT NOT NULL,
    "religion_or_tradition" TEXT,
    "total_budget" DECIMAL(12,2) NOT NULL,
    "budget_tier" "BudgetTier" NOT NULL,
    "guest_count_estimate" INTEGER NOT NULL,
    "primary_date" DATE NOT NULL,
    "status" "EventGroupStatus" NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "event_groups_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "sub_events" (
    "id" UUID NOT NULL,
    "event_group_id" UUID NOT NULL,
    "name" TEXT NOT NULL,
    "sub_event_type" TEXT,
    "date" DATE NOT NULL,
    "start_time" TIME,
    "end_time" TIME,
    "venue_name" TEXT,
    "venue_address" TEXT,
    "expected_guest_count" INTEGER,
    "status" "SubEventStatus" NOT NULL,

    CONSTRAINT "sub_events_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "guest_groups" (
    "id" UUID NOT NULL,
    "event_group_id" UUID NOT NULL,
    "label" TEXT NOT NULL,

    CONSTRAINT "guest_groups_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "guests" (
    "id" UUID NOT NULL,
    "event_group_id" UUID NOT NULL,
    "guest_group_id" UUID,
    "name" TEXT NOT NULL,
    "phone_number" TEXT NOT NULL,
    "relationship" TEXT,
    "plus_ones_allowed" INTEGER NOT NULL DEFAULT 0,
    "plus_ones_confirmed" INTEGER NOT NULL DEFAULT 0,
    "travel_needed" BOOLEAN NOT NULL,
    "accommodation_needed" BOOLEAN NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "guests_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "guest_sub_event_invites" (
    "id" UUID NOT NULL,
    "guest_id" UUID NOT NULL,
    "sub_event_id" UUID NOT NULL,
    "rsvp_status" "RsvpStatus" NOT NULL,
    "responded_at" TIMESTAMP(3),

    CONSTRAINT "guest_sub_event_invites_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "guest_seating_assignments" (
    "id" UUID NOT NULL,
    "guest_id" UUID NOT NULL,
    "sub_event_id" UUID NOT NULL,
    "table_number" TEXT,

    CONSTRAINT "guest_seating_assignments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "task_categories" (
    "id" UUID NOT NULL,
    "category_key" TEXT NOT NULL,
    "applicable_event_types" "EventType"[],

    CONSTRAINT "task_categories_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "task_templates" (
    "id" UUID NOT NULL,
    "event_type" "EventType" NOT NULL,
    "region" TEXT,
    "religion_or_tradition" TEXT,
    "task_category_id" UUID NOT NULL,
    "task_key" TEXT NOT NULL,
    "default_name_en" TEXT NOT NULL,
    "default_lead_time_days" INTEGER NOT NULL,
    "default_dependency_keys" TEXT[],
    "typical_owner_type" "TaskOwnerType" NOT NULL,
    "version" INTEGER NOT NULL,

    CONSTRAINT "task_templates_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "tasks" (
    "id" UUID NOT NULL,
    "event_group_id" UUID NOT NULL,
    "sub_event_id" UUID,
    "task_category_id" UUID NOT NULL,
    "name" TEXT NOT NULL,
    "description" TEXT,
    "status" "TaskStatus" NOT NULL,
    "due_date" DATE,
    "source" "TaskSource" NOT NULL,
    "owner_type" "TaskOwnerType" NOT NULL,
    "owner_user_id" UUID,
    "linked_vendor_id" UUID,
    "linked_budget_category_id" UUID,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "tasks_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "task_dependencies" (
    "task_id" UUID NOT NULL,
    "depends_on_task_id" UUID NOT NULL,

    CONSTRAINT "task_dependencies_pkey" PRIMARY KEY ("task_id","depends_on_task_id")
);

-- CreateTable
CREATE TABLE "task_edit_logs" (
    "id" UUID NOT NULL,
    "task_id" UUID NOT NULL,
    "event_group_id" UUID NOT NULL,
    "action" "TaskEditAction" NOT NULL,
    "previous_value" JSONB,
    "new_value" JSONB,
    "changed_by" UUID NOT NULL,
    "changed_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "task_edit_logs_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "roadmap_generation_logs" (
    "id" UUID NOT NULL,
    "event_group_id" UUID NOT NULL,
    "input_params" JSONB NOT NULL,
    "template_ids_used" TEXT[],
    "llm_model_used" TEXT NOT NULL,
    "raw_output" JSONB NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "roadmap_generation_logs_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "budget_categories" (
    "id" UUID NOT NULL,
    "event_group_id" UUID NOT NULL,
    "category_key" TEXT NOT NULL,
    "allocated_amount" DECIMAL(12,2) NOT NULL,
    "budget_tier_override" "BudgetTier",

    CONSTRAINT "budget_categories_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "budget_lines" (
    "id" UUID NOT NULL,
    "budget_category_id" UUID NOT NULL,
    "description" TEXT NOT NULL,
    "amount" DECIMAL(12,2) NOT NULL,
    "entry_type" "BudgetEntryType" NOT NULL,
    "linked_vendor_id" UUID,
    "linked_task_id" UUID,
    "payer_label" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "budget_lines_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "bookings" (
    "id" UUID NOT NULL,
    "event_group_id" UUID NOT NULL,
    "vendor_id" UUID NOT NULL,
    "task_id" UUID,
    "status" "BookingStatus" NOT NULL,
    "agreed_price" DECIMAL(12,2) NOT NULL,
    "contract_document_id" UUID,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "bookings_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "payments" (
    "id" UUID NOT NULL,
    "booking_id" UUID NOT NULL,
    "milestone_type" "PaymentMilestoneType" NOT NULL,
    "amount" DECIMAL(12,2) NOT NULL,
    "due_date" DATE NOT NULL,
    "paid_at" TIMESTAMP(3),
    "status" "PaymentStatus" NOT NULL,

    CONSTRAINT "payments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "vendor_availability" (
    "id" UUID NOT NULL,
    "vendor_id" UUID NOT NULL,
    "date" DATE NOT NULL,
    "status" "VendorAvailabilityStatus" NOT NULL,

    CONSTRAINT "vendor_availability_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "reviews" (
    "id" UUID NOT NULL,
    "vendor_id" UUID NOT NULL,
    "event_group_id" UUID NOT NULL,
    "rating" INTEGER NOT NULL,
    "comment" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "reviews_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "documents" (
    "id" UUID NOT NULL,
    "event_group_id" UUID NOT NULL,
    "document_type" "DocumentType" NOT NULL,
    "file_url" TEXT NOT NULL,
    "uploaded_by" UUID NOT NULL,
    "uploaded_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "documents_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "legal_checklist_items" (
    "id" UUID NOT NULL,
    "region" TEXT,
    "religion_or_tradition" TEXT,
    "requirement_key" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "description" TEXT,
    "is_mandatory" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "legal_checklist_items_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "event_media" (
    "id" UUID NOT NULL,
    "event_group_id" UUID NOT NULL,
    "media_url" TEXT NOT NULL,
    "uploaded_by_vendor_id" UUID,
    "uploaded_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "event_media_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "thank_you_notes" (
    "id" UUID NOT NULL,
    "event_group_id" UUID NOT NULL,
    "guest_id" UUID NOT NULL,
    "status" "ThankYouStatus" NOT NULL,

    CONSTRAINT "thank_you_notes_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "notification_logs" (
    "id" UUID NOT NULL,
    "recipient_type" "NotificationRecipientType" NOT NULL,
    "recipient_id" UUID NOT NULL,
    "channel" "NotificationChannel" NOT NULL,
    "message_key" TEXT NOT NULL,
    "status" "NotificationStatus" NOT NULL,
    "scheduled_at" TIMESTAMP(3) NOT NULL,
    "sent_at" TIMESTAMP(3),

    CONSTRAINT "notification_logs_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "translation_strings" (
    "id" UUID NOT NULL,
    "string_key" TEXT NOT NULL,
    "language_code" TEXT NOT NULL,
    "text" TEXT NOT NULL,

    CONSTRAINT "translation_strings_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "production_pipeline_items" (
    "id" UUID NOT NULL,
    "task_id" UUID NOT NULL,
    "vendor_id" UUID,
    "status" "ProductionPipelineStatus" NOT NULL,
    "notes" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "production_pipeline_items_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "organizers_phone_number_key" ON "organizers"("phone_number");

-- CreateIndex
CREATE UNIQUE INDEX "vendors_phone_number_key" ON "vendors"("phone_number");

-- CreateIndex
CREATE UNIQUE INDEX "vendor_categories_category_key_key" ON "vendor_categories"("category_key");

-- CreateIndex
CREATE UNIQUE INDEX "admins_email_key" ON "admins"("email");

-- CreateIndex
CREATE UNIQUE INDEX "task_categories_category_key_key" ON "task_categories"("category_key");

-- AddForeignKey
ALTER TABLE "vendors" ADD CONSTRAINT "vendors_reviewed_by_fkey" FOREIGN KEY ("reviewed_by") REFERENCES "admins"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "vendor_vendor_categories" ADD CONSTRAINT "vendor_vendor_categories_vendor_id_fkey" FOREIGN KEY ("vendor_id") REFERENCES "vendors"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "vendor_vendor_categories" ADD CONSTRAINT "vendor_vendor_categories_vendor_category_id_fkey" FOREIGN KEY ("vendor_category_id") REFERENCES "vendor_categories"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "vendor_portfolio_items" ADD CONSTRAINT "vendor_portfolio_items_vendor_id_fkey" FOREIGN KEY ("vendor_id") REFERENCES "vendors"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "role_permissions" ADD CONSTRAINT "role_permissions_event_group_id_fkey" FOREIGN KEY ("event_group_id") REFERENCES "event_groups"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "role_permissions" ADD CONSTRAINT "role_permissions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "organizers"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "event_groups" ADD CONSTRAINT "event_groups_organizer_id_fkey" FOREIGN KEY ("organizer_id") REFERENCES "organizers"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "sub_events" ADD CONSTRAINT "sub_events_event_group_id_fkey" FOREIGN KEY ("event_group_id") REFERENCES "event_groups"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "guest_groups" ADD CONSTRAINT "guest_groups_event_group_id_fkey" FOREIGN KEY ("event_group_id") REFERENCES "event_groups"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "guests" ADD CONSTRAINT "guests_event_group_id_fkey" FOREIGN KEY ("event_group_id") REFERENCES "event_groups"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "guests" ADD CONSTRAINT "guests_guest_group_id_fkey" FOREIGN KEY ("guest_group_id") REFERENCES "guest_groups"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "guest_sub_event_invites" ADD CONSTRAINT "guest_sub_event_invites_guest_id_fkey" FOREIGN KEY ("guest_id") REFERENCES "guests"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "guest_sub_event_invites" ADD CONSTRAINT "guest_sub_event_invites_sub_event_id_fkey" FOREIGN KEY ("sub_event_id") REFERENCES "sub_events"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "guest_seating_assignments" ADD CONSTRAINT "guest_seating_assignments_guest_id_fkey" FOREIGN KEY ("guest_id") REFERENCES "guests"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "guest_seating_assignments" ADD CONSTRAINT "guest_seating_assignments_sub_event_id_fkey" FOREIGN KEY ("sub_event_id") REFERENCES "sub_events"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "task_templates" ADD CONSTRAINT "task_templates_task_category_id_fkey" FOREIGN KEY ("task_category_id") REFERENCES "task_categories"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "tasks" ADD CONSTRAINT "tasks_event_group_id_fkey" FOREIGN KEY ("event_group_id") REFERENCES "event_groups"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "tasks" ADD CONSTRAINT "tasks_sub_event_id_fkey" FOREIGN KEY ("sub_event_id") REFERENCES "sub_events"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "tasks" ADD CONSTRAINT "tasks_task_category_id_fkey" FOREIGN KEY ("task_category_id") REFERENCES "task_categories"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "tasks" ADD CONSTRAINT "tasks_linked_vendor_id_fkey" FOREIGN KEY ("linked_vendor_id") REFERENCES "vendors"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "tasks" ADD CONSTRAINT "tasks_linked_budget_category_id_fkey" FOREIGN KEY ("linked_budget_category_id") REFERENCES "budget_categories"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "task_dependencies" ADD CONSTRAINT "task_dependencies_task_id_fkey" FOREIGN KEY ("task_id") REFERENCES "tasks"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "task_dependencies" ADD CONSTRAINT "task_dependencies_depends_on_task_id_fkey" FOREIGN KEY ("depends_on_task_id") REFERENCES "tasks"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "task_edit_logs" ADD CONSTRAINT "task_edit_logs_task_id_fkey" FOREIGN KEY ("task_id") REFERENCES "tasks"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "task_edit_logs" ADD CONSTRAINT "task_edit_logs_event_group_id_fkey" FOREIGN KEY ("event_group_id") REFERENCES "event_groups"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "roadmap_generation_logs" ADD CONSTRAINT "roadmap_generation_logs_event_group_id_fkey" FOREIGN KEY ("event_group_id") REFERENCES "event_groups"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "budget_categories" ADD CONSTRAINT "budget_categories_event_group_id_fkey" FOREIGN KEY ("event_group_id") REFERENCES "event_groups"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "budget_lines" ADD CONSTRAINT "budget_lines_budget_category_id_fkey" FOREIGN KEY ("budget_category_id") REFERENCES "budget_categories"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "budget_lines" ADD CONSTRAINT "budget_lines_linked_vendor_id_fkey" FOREIGN KEY ("linked_vendor_id") REFERENCES "vendors"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "budget_lines" ADD CONSTRAINT "budget_lines_linked_task_id_fkey" FOREIGN KEY ("linked_task_id") REFERENCES "tasks"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "bookings" ADD CONSTRAINT "bookings_event_group_id_fkey" FOREIGN KEY ("event_group_id") REFERENCES "event_groups"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "bookings" ADD CONSTRAINT "bookings_vendor_id_fkey" FOREIGN KEY ("vendor_id") REFERENCES "vendors"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "bookings" ADD CONSTRAINT "bookings_task_id_fkey" FOREIGN KEY ("task_id") REFERENCES "tasks"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "bookings" ADD CONSTRAINT "bookings_contract_document_id_fkey" FOREIGN KEY ("contract_document_id") REFERENCES "documents"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "payments" ADD CONSTRAINT "payments_booking_id_fkey" FOREIGN KEY ("booking_id") REFERENCES "bookings"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "vendor_availability" ADD CONSTRAINT "vendor_availability_vendor_id_fkey" FOREIGN KEY ("vendor_id") REFERENCES "vendors"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "reviews" ADD CONSTRAINT "reviews_vendor_id_fkey" FOREIGN KEY ("vendor_id") REFERENCES "vendors"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "reviews" ADD CONSTRAINT "reviews_event_group_id_fkey" FOREIGN KEY ("event_group_id") REFERENCES "event_groups"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "documents" ADD CONSTRAINT "documents_event_group_id_fkey" FOREIGN KEY ("event_group_id") REFERENCES "event_groups"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "event_media" ADD CONSTRAINT "event_media_event_group_id_fkey" FOREIGN KEY ("event_group_id") REFERENCES "event_groups"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "event_media" ADD CONSTRAINT "event_media_uploaded_by_vendor_id_fkey" FOREIGN KEY ("uploaded_by_vendor_id") REFERENCES "vendors"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "thank_you_notes" ADD CONSTRAINT "thank_you_notes_event_group_id_fkey" FOREIGN KEY ("event_group_id") REFERENCES "event_groups"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "thank_you_notes" ADD CONSTRAINT "thank_you_notes_guest_id_fkey" FOREIGN KEY ("guest_id") REFERENCES "guests"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "production_pipeline_items" ADD CONSTRAINT "production_pipeline_items_task_id_fkey" FOREIGN KEY ("task_id") REFERENCES "tasks"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "production_pipeline_items" ADD CONSTRAINT "production_pipeline_items_vendor_id_fkey" FOREIGN KEY ("vendor_id") REFERENCES "vendors"("id") ON DELETE SET NULL ON UPDATE CASCADE;
