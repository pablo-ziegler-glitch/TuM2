import type { Timestamp } from 'firebase/firestore';

export type ProductStatus = 'active' | 'inactive';
export type ProductVisibilityStatus = 'hidden' | 'visible';
export type ProductStockStatus = 'available' | 'out_of_stock';
export type ProductImageUploadStatus = 'pending' | 'ready' | 'failed';

/**
 * Collection: merchant_products/{productId}
 * A product offered by a merchant.
 */
export interface MerchantProductDocument {
  // Required
  id: string;
  merchantId: string;
  ownerUserId: string;
  name: string;
  normalizedName: string;
  priceLabel: string;
  stockStatus: ProductStockStatus;
  visibilityStatus: ProductVisibilityStatus;
  status: ProductStatus;
  sourceType: 'owner_created';
  createdAt: Timestamp;
  updatedAt: Timestamp;
  createdBy: string;
  updatedBy: string;

  // Optional
  imageUrl?: string;
  imagePath?: string;
  imageUploadStatus?: ProductImageUploadStatus;
  sortOrder?: number;
  searchKeywords?: string[];
}
