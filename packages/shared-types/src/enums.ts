// String-literal union types mirroring every enum in apps/backend/prisma/schema.prisma.
// Keep these in sync with the Prisma schema by hand — this package has no
// dependency on @prisma/client so it stays usable from React Native.

export type OrganizerType = "individual" | "family" | "company" | "committee";

export type OrganizerStatus = "active" | "suspended";

export type VendorPriceTier = "essential" | "standard" | "premium" | "luxury";

export type VendorStatus =
  | "draft"
  | "pending_review"
  | "published"
  | "rejected"
  | "suspended";

export type AdminRole = "super_admin" | "vendor_reviewer" | "support";

export type EventGroupRole = "owner" | "editor" | "viewer" | "approver";

export type EventType =
  | "wedding"
  | "birthday"
  | "corporate"
  | "religious"
  | "engagement_only"
  | "custom";

export type BudgetTier = "essential" | "standard" | "premium" | "luxury";

export type EventGroupStatus = "planning" | "active" | "completed" | "archived";

export type SubEventStatus = "planned" | "in_progress" | "completed" | "cancelled";

export type RsvpStatus = "pending" | "confirmed" | "declined" | "no_response";

export type TaskOwnerType = "organizer" | "vendor" | "planner";

export type TaskStatus =
  | "not_started"
  | "in_progress"
  | "done"
  | "overdue"
  | "not_applicable";

export type TaskSource = "ai_generated" | "template_default" | "user_added";

export type TaskEditAction =
  | "created"
  | "edited"
  | "status_changed"
  | "deleted"
  | "reordered"
  | "marked_not_applicable";

export type BudgetEntryType = "planned" | "actual";

export type BookingStatus = "requested" | "confirmed" | "cancelled" | "completed";

export type PaymentMilestoneType = "advance" | "midpoint" | "final";

export type PaymentStatus = "pending" | "paid" | "overdue";

export type VendorAvailabilityStatus = "available" | "booked" | "blocked";

export type DocumentType =
  | "id_proof"
  | "vendor_contract"
  | "payment_receipt"
  | "marriage_registration_doc"
  | "other";

export type ThankYouStatus = "pending" | "sent";

export type NotificationRecipientType = "organizer" | "vendor" | "guest";

export type NotificationChannel = "whatsapp" | "push" | "sms";

export type NotificationStatus = "sent" | "delivered" | "failed";

export type ProductionPipelineStatus =
  | "pending"
  | "assigned"
  | "in_production"
  | "delivered"
  | "cancelled";
