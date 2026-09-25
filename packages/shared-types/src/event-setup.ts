import type { EventGroup, SubEvent, BudgetCategory } from "./models.js";
import type { OrganizerType, EventType, BudgetTier } from "./enums.js";

export interface UpdateOrganizerProfileBody {
  displayName: string;
  organizerType: OrganizerType;
}

export interface CreateEventGroupBody {
  eventType: EventType;
  name: string;
  region: string;
  religionOrTradition?: string;
  totalBudget: number;
  budgetTier: BudgetTier;
  guestCountEstimate: number;
  primaryDate: string; // YYYY-MM-DD
}

export interface EventGroupWithSubEvents extends EventGroup {
  subEvents: SubEvent[];
}

export interface EventGroupWithDetails extends EventGroupWithSubEvents {
  budgetCategories: BudgetCategory[];
}

export interface UpdateBudgetCategoryBody {
  allocatedAmount?: number;
  budgetTierOverride?: BudgetTier;
}

export interface CreateBudgetCategoryBody {
  categoryKey: string;
  allocatedAmount: number;
}

export interface BudgetCategoryMutationResponse {
  budgetCategory: BudgetCategory;
  warning: string | null;
}
