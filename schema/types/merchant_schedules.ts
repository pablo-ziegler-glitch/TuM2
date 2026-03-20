import type { Timestamp } from 'firebase/firestore';
import type { MerchantVerificationStatus, MerchantSourceType } from './merchant';

export interface ScheduleSlot {
  open: string;  // HH:mm
  close: string; // HH:mm
}

export type DayOfWeek =
  | 'monday'
  | 'tuesday'
  | 'wednesday'
  | 'thursday'
  | 'friday'
  | 'saturday'
  | 'sunday';

/** A day can have multiple slots (e.g. morning + evening split). */
export type DaySchedule = ScheduleSlot[];

export type WeeklySchedule = {
  [day in DayOfWeek]?: DaySchedule;
};

export interface ScheduleException {
  date: string; // YYYY-MM-DD
  isClosed: boolean;
  slots?: ScheduleSlot[];
  label?: string;
}

/**
 * Collection: merchant_schedules/{merchantId}
 * Operating hours for a merchant. One document per merchant (merchantId = docId).
 */
export interface MerchantSchedulesDocument {
  // Required
  merchantId: string;
  /** IANA timezone string, e.g. "America/Argentina/Buenos_Aires" */
  timezone: string;
  weeklySchedule: WeeklySchedule;
  sourceType: MerchantSourceType;
  verificationStatus: MerchantVerificationStatus;
  lastUpdatedAt: Timestamp;

  // Optional
  exceptions?: ScheduleException[];
}
