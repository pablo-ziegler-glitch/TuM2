import type { Timestamp } from 'firebase/firestore';

export interface ZonePublicationRules {
  /** Minimum number of visible merchants for a zone to go public */
  minimumVisibleMerchants: number;
  /** Minimum useful coverage score (0–100) for a zone to go public */
  minimumUsefulCoverageScore: number;
}

export interface BootstrapRules {
  /** confidenceScore threshold above which a place is auto-published */
  autoPublishThreshold: number;
  /** confidenceScore threshold below which a place goes to review queue */
  reviewThreshold: number;
}

export interface FeatureFlags {
  enableClaims: boolean;
  enableProposals: boolean;
  enableExternalBootstrap: boolean;
  [flag: string]: boolean;
}

/**
 * Collection: admin_configs/global
 * Singleton config document. Readable by admins, writable by super_admins.
 */
export interface AdminConfigGlobal {
  zonePublicationRules: ZonePublicationRules;
  bootstrapRules: BootstrapRules;
  featureFlags: FeatureFlags;
  updatedAt: Timestamp;
}
