export type RoleType = "OWNER" | "CUSTOMER" | "ADMIN";
export type RankType = "Vecino" | "Explorador" | "Referente" | "Conector" | "Radar";
export type VisibilityStatus = "draft" | "active" | "suspended";
export type SignalType =
  | "24hs"
  | "late_night"
  | "special_hours"
  | "special_service"
  | "night_delivery";
export type StockStatus = "available" | "low" | "out";
export type DutyScheduleStatus = "scheduled" | "confirmed" | "modified";
export type ProposalStatus =
  | "open"
  | "in_review"
  | "planned"
  | "done"
  | "rejected";

export interface StoreDoc {
  id: string;
  ownerId: string;
  name: string;
  slug: string;
  category: string;
  description: string;
  imageUrl: string;
  address: string;
  geo: { lat: number; lng: number };
  geohash: string;
  neighborhood: string;
  locality: string;
  visibilityStatus: VisibilityStatus;
  // Derived fields
  isOpenNow: boolean;
  isLateNightNow: boolean;
  isOnDutyToday: boolean;
  hasActiveSpecialSignal: boolean;
  operationalFreshnessHours: number;
  operationalDataCompletenessScore: number;
  activeBadgeKeys: string[];
  createdAt: { _seconds: number; _nanoseconds: number };
  updatedAt: { _seconds: number; _nanoseconds: number };
}

export interface ProductDoc {
  id: string;
  storeId: string;
  name: string;
  description: string;
  price: number;
  stockStatus: StockStatus;
  imageUrls: string[];
  isVisible: boolean;
}

export interface DaySchedule {
  open: string;
  close: string;
  closed: boolean;
}

export interface WeeklySchedule {
  monday: DaySchedule;
  tuesday: DaySchedule;
  wednesday: DaySchedule;
  thursday: DaySchedule;
  friday: DaySchedule;
  saturday: DaySchedule;
  sunday: DaySchedule;
}

export interface ScheduleDoc {
  storeId: string;
  timezone: string;
  weeklySchedule: WeeklySchedule;
}

export interface OperationalSignalDoc {
  id: string;
  storeId: string;
  signalType: SignalType;
  status: "active" | "inactive";
  notes: string;
}

export interface DutyScheduleDoc {
  id: string;
  storeId: string;
  date: string;
  startTime: string;
  endTime: string;
  status: DutyScheduleStatus;
  notes: string;
}

export interface ProposalDoc {
  id: string;
  segment: "OWNER" | "CUSTOMER";
  createdBy: string;
  title: string;
  description: string;
  status: ProposalStatus;
  voteCount: number;
  shareSlug: string;
  moderationStatus: "pending" | "approved" | "rejected";
}
