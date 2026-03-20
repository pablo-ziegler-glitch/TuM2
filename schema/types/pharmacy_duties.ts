import type { Timestamp } from 'firebase/firestore';
import type { MerchantSourceType } from './merchant';

export type PharmacyDutyStatus = 'draft' | 'published' | 'cancelled';

export type PharmacyDutyVerificationStatus =
  | 'referential'
  | 'validated'
  | 'claimed';

/**
 * Collection: pharmacy_duties/{dutyId}
 * Represents a pharmacy on-duty (turno de guardia) entry for a given date.
 * A single merchant may have multiple duty entries across different dates/zones.
 */
export interface PharmacyDutyDocument {
  // Required
  id: string;
  merchantId: string;
  zoneId: string;
  cityId: string;
  provinceId: string;
  /** ISO date string: YYYY-MM-DD */
  date: string;
  startsAt: Timestamp;
  endsAt: Timestamp;
  status: PharmacyDutyStatus;
  verificationStatus: PharmacyDutyVerificationStatus;
  sourceType: MerchantSourceType;
  createdAt: Timestamp;
  updatedAt: Timestamp;

  // Optional
  notes?: string | null;
}
