import type { Timestamp } from 'firebase/firestore';

export type MerchantStatus =
  | 'draft'
  | 'pending_review'
  | 'active'
  | 'inactive'
  | 'archived'
  | 'blocked';

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

export type MerchantOwnershipStatus =
  | 'unclaimed'
  | 'claimed'
  | 'disputed'
  | 'restricted';

export type MerchantSourceType =
  | 'external_seed'
  | 'user_submitted'
  | 'owner_created'
  | 'admin_created'
  | 'manual_owner'
  | 'manual_admin'
  | 'community_suggested';

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
 * Snapshot público del dueño, denormalizado en el documento del comercio.
 * Se actualiza cuando se aprueba un merchant_claim.
 * Permite mostrar en ficha pública quién reclamó el comercio sin join a users.
 */
export interface OwnerDisplay {
  userId: string;
  username: string | null;
  displayName: string;
}

/**
 * Collection: merchants/{merchantId}
 * Entidad canónica de un comercio local. Source of truth.
 * No usar para lecturas públicas directas — usar merchant_public en su lugar.
 *
 * Campos mínimos para alcanzar visibilityStatus = 'visible':
 *   - name, categoryId, zoneId, primaryLocation.lat/lng
 *   - verificationStatus >= 'referential' | 'community_submitted'
 *   - status not 'inactive' | 'archived' | 'blocked'
 *
 * confidenceScore (0–100) se persiste y recalcula por Cloud Functions,
 * no debe escribirse desde clientes.
 */
export interface MerchantDocument {
  // Obligatorios
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
  ownershipStatus: MerchantOwnershipStatus;
  sourceType: MerchantSourceType;
  /** Score de confianza 0–100. Escrito solo por Cloud Functions. */
  confidenceScore: number;
  confidenceLevel: ConfidenceLevel;
  isClaimable: boolean;
  createdAt: Timestamp;
  updatedAt: Timestamp;

  // Opcionales
  slug?: string | null;
  description?: string | null;
  subCategoryIds?: string[];
  ownerUserId?: string | null;
  /** Snapshot público del dueño para la ficha. Solo presente si ownershipStatus = 'claimed'. */
  ownerDisplay?: OwnerDisplay | null;
  badge?: string | null;
  createdByUserId?: string | null;
  /** Peso numérico de la fuente semilla (mayor = más confiable). */
  sourcePriority?: number;
  primaryLocation?: MerchantLocation;
  contact?: MerchantContact;
  mapsUrl?: string | null;
  paymentMethods?: string[];
  coverImageUrl?: string | null;
  logoImageUrl?: string | null;
  storefrontImageUrl?: string | null;
  hasProducts?: boolean;
  hasSchedules?: boolean;
  hasOperationalSignals?: boolean;
  hasPharmacyDuty?: boolean;
  catalogEnabled?: boolean;
  chatEnabled?: boolean;
  communityEditable?: boolean;
  favoritesCount?: number;
  reportsCount?: number;
  contributionsCount?: number;
  reportCount?: number;
  lastVerifiedAt?: Timestamp | null;
  lastCommunityUpdateAt?: Timestamp | null;
  lastOwnerUpdateAt?: Timestamp | null;
  lastSignalUpdateAt?: Timestamp | null;
  lastReviewedAt?: Timestamp | null;
  archivedAt?: Timestamp | null;
}
