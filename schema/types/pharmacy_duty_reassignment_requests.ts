import type { Timestamp } from 'firebase/firestore';

export type PharmacyDutyReassignmentRequestStatus =
  | 'pending'
  | 'accepted'
  | 'rejected'
  | 'expired'
  | 'cancelled';

export type PharmacyDutyReassignmentResponseReason =
  | 'accepted'
  | 'rejected'
  | 'expired'
  | 'cancelled_due_to_other_acceptance';

/**
 * Collection: pharmacy_duty_reassignment_requests/{requestId}
 */
export interface PharmacyDutyReassignmentRequestDocument {
  roundId: string;
  dutyId: string;
  incidentId: string;
  originMerchantId: string;
  candidateMerchantId: string;
  zoneId: string;
  distanceKm: number;
  status: PharmacyDutyReassignmentRequestStatus;
  sentAt: Timestamp;
  expiresAt: Timestamp;
  respondedAt?: Timestamp;
  responseReason?: PharmacyDutyReassignmentResponseReason;
  createdByUserId: string;
  responseByUserId?: string;
  lastEventAt: Timestamp;
}
