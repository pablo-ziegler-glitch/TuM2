import type { Timestamp } from 'firebase/firestore';

export type PharmacyDutyIncidentType =
  | 'power_outage'
  | 'staff_shortage'
  | 'technical_issue'
  | 'operational_issue'
  | 'other';

export type PharmacyDutyIncidentStatus =
  | 'open'
  | 'covered'
  | 'expired'
  | 'cancelled';

/**
 * Collection: pharmacy_duty_incidents/{incidentId}
 */
export interface PharmacyDutyIncidentDocument {
  dutyId: string;
  merchantId: string;
  zoneId: string;
  incidentType: PharmacyDutyIncidentType;
  note?: string;
  status: PharmacyDutyIncidentStatus;
  createdByUserId: string;
  createdAt: Timestamp;
  updatedAt: Timestamp;
  resolvedAt?: Timestamp;
  resolvedByUserId?: string;
}
