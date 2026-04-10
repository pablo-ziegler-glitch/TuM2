import type { Timestamp } from 'firebase/firestore';

export type PharmacyDutyReassignmentRoundStatus =
  | 'open'
  | 'covered'
  | 'expired'
  | 'cancelled';

/**
 * Collection: pharmacy_duty_reassignment_rounds/{roundId}
 */
export interface PharmacyDutyReassignmentRoundDocument {
  dutyId: string;
  incidentId: string;
  originMerchantId: string;
  zoneId: string;
  status: PharmacyDutyReassignmentRoundStatus;
  maxDistanceKmApplied: number;
  candidateCount: number;
  acceptedRequestId?: string;
  acceptedMerchantId?: string;
  expiresAt: Timestamp;
  createdByUserId: string;
  createdAt: Timestamp;
  closedAt?: Timestamp;
  lastEventAt: Timestamp;
}
