import type { Timestamp } from 'firebase/firestore';

export type MerchantStatus = 'draft' | 'active' | 'inactive' | 'archived';

/**
 * Nivel de confianza persistido. Compartido entre merchants y pharmacy_duties.
 * Escala: 80–100 → verified | 60–79 → community_trusted | 30–59 → pending | 0–29 → under_review
 */
export type ConfidenceLevel =
  | 'verified'
  | 'community_trusted'
  | 'pending'
  | 'under_review'
  | 'low_confidence';

export type MerchantVisibilityStatus =
  | 'hidden'
  | 'review_pending'
  | 'visible'
  | 'suppressed';

export type MerchantVerificationStatus =
  | 'unverified'
  | 'referential'
  | 'community_submitted'
  | 'claimed'
  | 'validated'
  | 'verified';

export type MerchantSourceType =
  | 'external_seed'
  | 'user_submitted'
  | 'owner_created'
  | 'admin_created'
  | 'manual_owner'
  | 'manual_admin'
  | 'community_suggested';

export interface MerchantLocation {
  address: string;
  lat: number;
  lng: number;
  geohash: string;
}

export interface MerchantContact {
  phone: string | null;
  whatsapp: string | null;
  website: string | null;
}

/**
 * Collection: merchants/{merchantId}
 * Canonical entity for a local commerce. Source of truth — not for direct
 * public reads (use merchant_public instead).
 *
 * Minimum fields required to reach visibilityStatus = 'visible':
 *   - name, categoryId, zoneId, primaryLocation.lat/lng
 *   - verificationStatus >= 'referential' | 'community_submitted'
 *   - status not 'inactive' | 'archived'
 */
export interface MerchantDocument {
  // Required
  id: string;
  name: string;
  normalizedName: string;
  categoryId: string;
  zoneId: string;
  provinceId: string;
  cityId: string;
  status: MerchantStatus;
  visibilityStatus: MerchantVisibilityStatus;
  verificationStatus: MerchantVerificationStatus;
  sourceType: MerchantSourceType;
  isClaimable: boolean;
  createdAt: Timestamp;
  updatedAt: Timestamp;

  // Optional
  description?: string | null;
  subCategoryIds?: string[];
  ownerUserId?: string | null;
  createdByUserId?: string | null;
  /** Numeric weight for source priority (higher = more trusted seed) */
  sourcePriority?: number;
  primaryLocation?: MerchantLocation;
  contact?: MerchantContact;
  hasProducts?: boolean;
  hasSchedules?: boolean;
  hasOperationalSignals?: boolean;
  hasPharmacyDuty?: boolean;
  reportCount?: number;
  lastReviewedAt?: Timestamp | null;
}
