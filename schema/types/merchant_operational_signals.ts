import type { Timestamp } from 'firebase/firestore';

export type MerchantOperationalSignalType =
  | 'none'
  | 'vacation'
  | 'temporary_closure'
  | 'delay';

export type ManualOverrideMode = 'none' | 'force_closed' | 'informational';

/**
 * Collection: merchant_operational_signals/{merchantId}
 * Documento privado de estado operativo con override manual OWNER y
 * campos automáticos derivados de horarios/guardias.
 */
export interface MerchantOperationalSignalsDocument {
  merchantId: string;
  ownerUserId: string;
  signalType: MerchantOperationalSignalType;
  isActive: boolean;
  message?: string | null;
  forceClosed: boolean;
  updatedAt: Timestamp;
  updatedByUid: string;
  createdAt?: Timestamp;
  schemaVersion: number;

  // Campos derivados backend (no escribir desde cliente).
  isOpenNow?: boolean;
  todayScheduleLabel?: string;
  hasPharmacyDutyToday?: boolean;
  pharmacyDutyStatus?: 'published' | 'scheduled' | 'cancelled' | null;
  hasScheduleConfigured?: boolean;
  closesAt?: string | null;
  opensNextAt?: string | null;
  scheduleSummary?: {
    timezone: string;
    todayWindows: Array<{
      opensAtLocalMinutes: number;
      closesAtLocalMinutes: number;
    }>;
    hasSchedule: boolean;
    scheduleLastUpdatedAt?: Timestamp;
    lastVerifiedAt?: Timestamp;
  };
  nextOpenAt?: Timestamp | null;
  nextCloseAt?: Timestamp | null;
  nextTransitionAt?: Timestamp | null;
  isOpenNowSnapshot?: boolean;
  snapshotComputedAt?: Timestamp | null;
}
