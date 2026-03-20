import type { Timestamp } from 'firebase/firestore';

export type ZoneStatus =
  | 'draft'
  | 'internal_test'
  | 'pilot_enabled'
  | 'public_enabled'
  | 'paused';

export type ZoneLaunchPhase = 'fundational' | 'mvp' | 'launch' | 'post_mvp';

export interface ZoneBounds {
  north: number;
  south: number;
  east: number;
  west: number;
}

export interface ZoneCoverageMetrics {
  merchantCount: number;
  visibleMerchantCount: number;
  pharmacyCount: number;
  /** 0–100 score representing useful coverage density */
  usefulCoverageScore: number;
}

/**
 * Collection: zones/{zoneId}
 * Represents a geographic zone (neighborhood / barrio).
 */
export interface ZoneDocument {
  // Required
  id: string;
  name: string;
  slug: string;
  provinceId: string;
  cityId: string;
  countryId: string;
  status: ZoneStatus;
  priorityLevel: number;
  launchPhase: ZoneLaunchPhase;
  centroid: {
    lat: number;
    lng: number;
  };
  createdAt: Timestamp;
  updatedAt: Timestamp;

  // Optional
  bounds?: ZoneBounds;
  coverageMetrics?: ZoneCoverageMetrics;
}
