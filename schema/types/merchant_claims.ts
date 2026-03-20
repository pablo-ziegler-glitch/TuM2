import type { Timestamp } from 'firebase/firestore';

export type MerchantClaimStatus = 'pending' | 'approved' | 'rejected';

export interface ClaimEvidence {
  /** URL to a photo of the business (e.g. storefront, signage) */
  photoUrl?: string;
  /** Self-described role of the claimant */
  ownerDescription?: string;
  /** Phone number provided as proof */
  verificationPhone?: string;
  [key: string]: string | undefined;
}

/**
 * Collection: merchant_claims/{claimId}
 * A user's request to claim ownership of an unverified or referential merchant.
 */
export interface MerchantClaimDocument {
  // Required
  id: string;
  merchantId: string;
  userId: string;
  status: MerchantClaimStatus;
  submittedAt: Timestamp;

  // Optional
  evidence?: ClaimEvidence;
  reviewedAt?: Timestamp | null;
  /** UID of the admin who reviewed the claim */
  reviewedBy?: string | null;
}
