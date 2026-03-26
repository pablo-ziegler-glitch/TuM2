import type { Timestamp } from 'firebase/firestore';

/**
 * Subcolección: users/{userId}/favorites/{merchantId}
 * El ID del documento ES el merchantId para lookups O(1).
 *
 * El contador global se mantiene en merchants.favoritesCount,
 * actualizado por Cloud Functions.
 */
export interface FavoriteDocument {
  merchantId: string;
  createdAt: Timestamp;
}
