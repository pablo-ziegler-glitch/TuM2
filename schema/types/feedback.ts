import type { Timestamp } from 'firebase/firestore';

export type FeedbackType = 'feature_feedback' | 'bug_report' | 'general';
export type FeedbackChannel = 'in_app' | 'web';
export type FeedbackStatus = 'new' | 'reviewed' | 'closed';

/**
 * Collection: feedback/{feedbackId}
 * Feedback simple de usuarios sobre la plataforma.
 *
 * Deliberadamente mínimo en MVP. No incluye threading ni respuestas.
 * La revisión es interna (admin), no visible al usuario que lo envió.
 */
export interface FeedbackDocument {
  // Obligatorios
  id: string;
  userId: string;
  type: FeedbackType;
  channel: FeedbackChannel;
  status: FeedbackStatus;
  createdAt: Timestamp;

  // Opcionales
  text?: string | null;
  reviewedAt?: Timestamp | null;
  reviewedBy?: string | null;
}
