import type { Timestamp } from 'firebase/firestore';

export type ReportTargetType = 'merchant' | 'proposal' | 'signal';

export type ReportType =
  | 'wrong_schedule'
  | 'wrong_location'
  | 'closed_permanently'
  | 'duplicate'
  | 'other';

export type ReportStatus = 'open' | 'reviewing' | 'resolved' | 'dismissed';

/**
 * Collection: reports/{reportId}
 * User-submitted report flagging incorrect or abusive data.
 */
export interface ReportDocument {
  // Required
  id: string;
  targetType: ReportTargetType;
  /** ID of the document being reported */
  targetId: string;
  reportType: ReportType;
  status: ReportStatus;
  /** UID of the user who submitted the report */
  createdBy: string;
  createdAt: Timestamp;

  // Optional
  description?: string | null;
  reviewedAt?: Timestamp | null;
  /** UID of the admin who reviewed the report */
  reviewedBy?: string | null;
}
