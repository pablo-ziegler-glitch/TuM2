import type { Timestamp } from 'firebase/firestore';
import type { MerchantSourceType } from './merchant';

export type IsOpenNowSource =
  | 'schedule'
  | 'manual_override'
  | 'signal'
  | 'unknown';

export type IsOpenNowConfidence = 'high' | 'medium' | 'low' | 'unknown';

/** Owner-reported operational signals (MVP subset). */
export interface OperationalSignals {
  temporaryClosed?: boolean;
  hasDelivery?: boolean;
  acceptsWhatsappOrders?: boolean;
  /** Owner manually marks as open/closed overriding schedule. null = no override. */
  openNowManualOverride?: boolean | null;
  [key: string]: boolean | null | undefined;
}

/** Computed signals derived by Cloud Functions. */
export interface DerivedSignals {
  /** null when confidence is too low to determine */
  isOpenNow: boolean | null;
  isOpenNowSource: IsOpenNowSource;
  isOpenNowConfidence: IsOpenNowConfidence;
  [key: string]: boolean | null | string | undefined;
}

/**
 * Collection: merchant_operational_signals/{merchantId}
 * Stores real-time operational state for a merchant.
 * One document per merchant (merchantId = docId).
 */
export interface MerchantOperationalSignalsDocument {
  // Required
  merchantId: string;
  signals: OperationalSignals;
  /** Computed by Cloud Functions — do not write from client */
  derivedSignals: DerivedSignals;
  sourceType: MerchantSourceType;
  updatedAt: Timestamp;

  // Optional
  updatedBy?: string | null;
}
