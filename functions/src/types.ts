import { Timestamp } from "firebase-admin/firestore";

export type RoleType = "OWNER" | "CUSTOMER" | "ADMIN";
export type RankType = "Vecino" | "Explorador" | "Referente" | "Conector" | "Radar";
export type VisibilityStatus = "draft" | "active" | "suspended";
export type SignalType = "24hs" | "late_night" | "special_hours" | "special_service" | "night_delivery";
export type SignalStatus = "active" | "inactive";
export type SourceType = "owner" | "admin" | "system";
export type ConfidenceLevel = "high" | "medium" | "low";
export type StockStatus = "available" | "low" | "out";
export type DutyStatus = "scheduled" | "confirmed" | "modified";
export type ProposalStatus = "open" | "in_review" | "planned" | "done" | "rejected";
export type ModerationStatus = "pending" | "approved" | "rejected";
export type ContextType = "loading" | "empty_state" | "onboarding" | "notification" | "badge";

export interface UserDoc {
  id: string;
  email: string;
  displayName: string;
  roleType: RoleType | null;
  currentRank: RankType;
  xpPoints: number;
  status: "active" | "suspended";
  createdAt: Timestamp;
}

export interface GeoPoint {
  lat: number;
  lng: number;
}

export interface DaySchedule {
  open: string;  // "HH:mm"
  close: string; // "HH:mm"
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

export interface StoreDoc {
  id: string;
  ownerId: string;
  name: string;
  slug: string;
  category: string;
  description: string;
  imageUrl: string;
  address: string;
  geo: GeoPoint;
  geohash: string;
  neighborhood: string;
  locality: string;
  visibilityStatus: VisibilityStatus;
  // Derived fields (calculated by Cloud Functions)
  isOpenNow: boolean;
  isLateNightNow: boolean;
  isOnDutyToday: boolean;
  hasActiveSpecialSignal: boolean;
  operationalFreshnessHours: number;
  operationalDataCompletenessScore: number;
  activeBadgeKeys: string[];
  createdAt: Timestamp;
  updatedAt: Timestamp;
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
  updatedAt: Timestamp;
}

export interface ScheduleDoc {
  storeId: string;
  timezone: string;
  weeklySchedule: WeeklySchedule;
  updatedAt: Timestamp;
}

export interface OperationalSignalDoc {
  id: string;
  storeId: string;
  signalType: SignalType;
  status: SignalStatus;
  notes: string;
  sourceType: SourceType;
  confidenceLevel: ConfidenceLevel;
  updatedAt: Timestamp;
}

export interface DutyScheduleDoc {
  id: string;
  storeId: string;
  date: string; // "YYYY-MM-DD"
  startTime: string;
  endTime: string;
  status: DutyStatus;
  notes: string;
  sourceType: SourceType;
  updatedAt: Timestamp;
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
  moderationStatus: ModerationStatus;
  createdAt: Timestamp;
}

export interface VoteDoc {
  proposalId: string;
  userId: string;
  segment: "OWNER" | "CUSTOMER";
  voteType: "up";
  createdAt: Timestamp;
}

export interface BrandingSnippetDoc {
  id: string;
  contextType: ContextType;
  segment: "OWNER" | "CUSTOMER" | "all";
  tone: string;
  text: string;
  active: boolean;
  version: number;
}

export interface BadgeDefinitionDoc {
  id: string;
  key: string;
  label: string;
  description: string;
  visualStyle: string;
  active: boolean;
}
