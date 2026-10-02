// TypeScript interfaces mirroring every table in apps/backend/prisma/schema.prisma
// (Sanchalan — Complete Data Model v1.0). Field names are camelCase, matching
// what the Prisma client / API layer serializes. Dates are ISO strings (as
// they cross the wire over JSON), decimals are `number`.
//
// This is the shared contract: backend and mobile both import from here
// instead of each keeping their own copy of "what a Task looks like."

import type {
  AdminRole,
  BookingStatus,
  BudgetEntryType,
  BudgetTier,
  DocumentType,
  EventGroupRole,
  EventGroupStatus,
  EventType,
  NotificationChannel,
  NotificationRecipientType,
  NotificationStatus,
  OrganizerStatus,
  OrganizerType,
  PaymentMilestoneType,
  PaymentStatus,
  ProductionPipelineStatus,
  RsvpStatus,
  SubEventStatus,
  TaskEditAction,
  TaskOwnerType,
  TaskSource,
  TaskStatus,
  ThankYouStatus,
  VendorAvailabilityStatus,
  VendorPriceTier,
  VendorReviewAction,
  VendorStatus,
} from "./enums.js";

// =============================================================================
// 1. Identity & Accounts
// =============================================================================

export interface Organizer {
  id: string;
  phoneNumber: string;
  email: string | null;
  displayName: string | null;
  organizerType: OrganizerType | null;
  preferredLanguage: string | null;
  createdAt: string;
  status: OrganizerStatus;
}

export interface Vendor {
  id: string;
  businessName: string | null;
  contactPersonName: string | null;
  phoneNumber: string;
  email: string | null;
  priceTier: VendorPriceTier | null;
  serviceArea: string | null;
  description: string | null;
  yearsOfExperience: number | null;
  startingPrice: number | null;
  instagramUrl: string | null;
  websiteUrl: string | null;
  whatsappNumber: string | null;
  status: VendorStatus;
  rejectionReason: string | null;
  submittedAt: string | null;
  reviewedAt: string | null;
  reviewedBy: string | null;
  createdAt: string;
}

export interface VendorCategory {
  id: string;
  categoryKey: string;
  applicableEventTypes: EventType[];
}

export interface VendorVendorCategory {
  vendorId: string;
  vendorCategoryId: string;
}

export interface VendorPortfolioItem {
  id: string;
  vendorId: string;
  title: string;
  mediaUrl: string | null;
  caption: string | null;
  displayOrder: number;
  createdAt: string;
}

export interface VendorReviewLog {
  id: string;
  vendorId: string;
  adminId: string | null;
  action: VendorReviewAction;
  reason: string | null;
  createdAt: string;
}

export interface Admin {
  id: string;
  name: string;
  email: string;
  passwordHash: string;
  role: AdminRole;
  createdAt: string;
}

export interface RolePermission {
  id: string;
  eventGroupId: string;
  userId: string;
  role: EventGroupRole;
  invitedAt: string;
}

// =============================================================================
// 2. The Event Itself
// =============================================================================

export interface EventGroup {
  id: string;
  organizerId: string;
  eventType: EventType;
  name: string;
  region: string;
  religionOrTradition: string | null;
  totalBudget: number;
  budgetTier: BudgetTier;
  guestCountEstimate: number;
  primaryDate: string;
  status: EventGroupStatus;
  createdAt: string;
}

export interface SubEvent {
  id: string;
  eventGroupId: string;
  name: string;
  subEventType: string | null;
  date: string;
  startTime: string | null;
  endTime: string | null;
  venueName: string | null;
  venueAddress: string | null;
  expectedGuestCount: number | null;
  status: SubEventStatus;
}

// =============================================================================
// 3. Guests & RSVP
// =============================================================================

export interface GuestGroup {
  id: string;
  eventGroupId: string;
  label: string;
}

export interface Guest {
  id: string;
  eventGroupId: string;
  guestGroupId: string | null;
  name: string;
  phoneNumber: string;
  relationship: string | null;
  plusOnesAllowed: number;
  plusOnesConfirmed: number;
  travelNeeded: boolean;
  accommodationNeeded: boolean;
  createdAt: string;
}

export interface GuestSubEventInvite {
  id: string;
  guestId: string;
  subEventId: string;
  rsvpStatus: RsvpStatus;
  respondedAt: string | null;
}

export interface GuestSeatingAssignment {
  id: string;
  guestId: string;
  subEventId: string;
  tableNumber: string | null;
}

// =============================================================================
// 4. The AI Roadmap Engine (Tasks)
// =============================================================================

export interface TaskCategory {
  id: string;
  categoryKey: string;
  applicableEventTypes: EventType[];
}

export interface TaskTemplate {
  id: string;
  eventType: EventType;
  region: string | null;
  religionOrTradition: string | null;
  taskCategoryId: string;
  taskKey: string;
  defaultNameEn: string;
  defaultLeadTimeDays: number;
  defaultDependencyKeys: string[];
  typicalOwnerType: TaskOwnerType;
  version: number;
}

export interface Task {
  id: string;
  eventGroupId: string;
  subEventId: string | null;
  taskCategoryId: string;
  name: string;
  description: string | null;
  status: TaskStatus;
  dueDate: string | null;
  source: TaskSource;
  ownerType: TaskOwnerType;
  ownerUserId: string | null;
  linkedVendorId: string | null;
  linkedBudgetCategoryId: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface TaskDependency {
  taskId: string;
  dependsOnTaskId: string;
}

export interface TaskEditLog {
  id: string;
  taskId: string;
  eventGroupId: string;
  action: TaskEditAction;
  previousValue: Record<string, unknown> | null;
  newValue: Record<string, unknown> | null;
  changedBy: string;
  changedAt: string;
}

export interface RoadmapGenerationLog {
  id: string;
  eventGroupId: string;
  inputParams: Record<string, unknown>;
  templateIdsUsed: string[];
  llmModelUsed: string;
  rawOutput: Record<string, unknown>;
  createdAt: string;
}

// =============================================================================
// 5. Budget & Payments
// =============================================================================

export interface BudgetCategory {
  id: string;
  eventGroupId: string;
  categoryKey: string;
  allocatedAmount: number;
  budgetTierOverride: BudgetTier | null;
}

export interface BudgetLine {
  id: string;
  budgetCategoryId: string;
  description: string;
  amount: number;
  entryType: BudgetEntryType;
  linkedVendorId: string | null;
  linkedTaskId: string | null;
  payerLabel: string | null;
  createdAt: string;
}

export interface Booking {
  id: string;
  eventGroupId: string;
  vendorId: string;
  taskId: string | null;
  status: BookingStatus;
  agreedPrice: number;
  contractDocumentId: string | null;
  createdAt: string;
}

export interface Payment {
  id: string;
  bookingId: string;
  milestoneType: PaymentMilestoneType;
  amount: number;
  dueDate: string;
  paidAt: string | null;
  status: PaymentStatus;
}

// =============================================================================
// 6. Vendor Availability & Trust
// =============================================================================

export interface VendorAvailability {
  id: string;
  vendorId: string;
  date: string;
  status: VendorAvailabilityStatus;
}

export interface Review {
  id: string;
  vendorId: string;
  eventGroupId: string;
  rating: number;
  comment: string | null;
  createdAt: string;
}

// =============================================================================
// 7. Legal & Documentation
// =============================================================================

export interface Document {
  id: string;
  eventGroupId: string;
  documentType: DocumentType;
  fileUrl: string;
  uploadedBy: string;
  uploadedAt: string;
}

export interface LegalChecklistItem {
  id: string;
  region: string | null;
  religionOrTradition: string | null;
  requirementKey: string;
  name: string;
  description: string | null;
  isMandatory: boolean;
  createdAt: string;
}

// =============================================================================
// 8. Post-Event
// =============================================================================

export interface EventMedia {
  id: string;
  eventGroupId: string;
  mediaUrl: string;
  uploadedByVendorId: string | null;
  uploadedAt: string;
}

export interface ThankYouNote {
  id: string;
  eventGroupId: string;
  guestId: string;
  status: ThankYouStatus;
}

// =============================================================================
// 9. Notifications & Messaging
// =============================================================================

export interface NotificationLog {
  id: string;
  recipientType: NotificationRecipientType;
  recipientId: string;
  channel: NotificationChannel;
  messageKey: string;
  status: NotificationStatus;
  scheduledAt: string;
  sentAt: string | null;
}

// =============================================================================
// 10. Multi-Language Support
// =============================================================================

export interface TranslationString {
  id: string;
  stringKey: string;
  languageCode: string;
  text: string;
}

// =============================================================================
// 11. Create-or-Delegate Pipelines
// =============================================================================

export interface ProductionPipelineItem {
  id: string;
  taskId: string;
  vendorId: string | null;
  status: ProductionPipelineStatus;
  notes: string | null;
  createdAt: string;
  updatedAt: string;
}
