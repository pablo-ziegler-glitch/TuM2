import type { Timestamp } from 'firebase/firestore';

export type ProductStatus = 'active' | 'inactive';
export type ProductVisibilityStatus = 'hidden' | 'visible';
export type ProductStockStatus = 'unknown' | 'available' | 'out_of_stock';

/**
 * Collection: merchant_products/{productId}
 * A product offered by a merchant.
 */
export interface MerchantProductDocument {
  // Required
  id: string;
  merchantId: string;
  name: string;
  normalizedName: string;
  categoryId: string;
  status: ProductStatus;
  visibilityStatus: ProductVisibilityStatus;
  createdAt: Timestamp;
  updatedAt: Timestamp;

  // Optional
  /** Human-readable price string, e.g. "$1.200" */
  priceLabel?: string | null;
  /** Numeric price for sorting/filtering */
  referencePrice?: number | null;
  stockStatus?: ProductStockStatus;
  images?: string[];
  searchKeywords?: string[];
}
