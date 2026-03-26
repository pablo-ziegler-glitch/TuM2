import type { Timestamp } from 'firebase/firestore';

/**
 * Subcolección: users/{userId}/favorites/{merchantId}
 * El ID del documento ES el merchantId para lookups O(1).
 *
 * Simple e intencional: no necesita top-level en MVP.
 * El contador global se mantiene en merchants.favoritesCount
 * actualizado por Cloud Functions.
 */
export interface FavoriteDocument {
  merchantId: string;
  createdAt: Timestamp;
}
