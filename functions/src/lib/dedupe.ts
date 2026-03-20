import { DedupeResult, MerchantDoc } from "./types";

/**
 * Normalizes a string for comparison: lowercase, remove accents,
 * collapse whitespace, strip punctuation.
 */
function normalize(str: string): string {
  return str
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^\w\s]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

/**
 * Simple token overlap coefficient between two strings.
 * Returns 0–1.
 */
function tokenOverlap(a: string, b: string): number {
  const setA = new Set(normalize(a).split(" ").filter(Boolean));
  const setB = new Set(normalize(b).split(" ").filter(Boolean));
  if (setA.size === 0 || setB.size === 0) return 0;

  let shared = 0;
  for (const token of setA) {
    if (setB.has(token)) shared++;
  }

  return shared / Math.max(setA.size, setB.size);
}

/**
 * Haversine distance in km between two lat/lng points.
 */
function haversineKm(
  lat1: number,
  lng1: number,
  lat2: number,
  lng2: number
): number {
  const R = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLng = ((lng2 - lng1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLng / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

export interface CandidateInput {
  name: string;
  address?: string;
  lat?: number;
  lng?: number;
  zoneId: string;
  externalId: string;
}

export interface ExistingMerchant {
  merchantId: string;
  name: string;
  address?: string;
  lat?: number;
  lng?: number;
  zone: string;
}

const NAME_THRESHOLD = 0.7;
const GEO_THRESHOLD_KM = 0.1; // 100 meters

/**
 * Finds the best matching existing merchant for a candidate external place.
 * Matches on name overlap and (optionally) geo proximity.
 */
export function dedupeMerchantCandidate(
  candidate: CandidateInput,
  existingMerchants: ExistingMerchant[]
): DedupeResult {
  let bestMatch: ExistingMerchant | null = null;
  let bestScore = 0;

  for (const merchant of existingMerchants) {
    if (merchant.zone !== candidate.zoneId) continue;

    const nameScore = tokenOverlap(candidate.name, merchant.name);
    if (nameScore < NAME_THRESHOLD) continue;

    let geoScore = 0;
    if (
      candidate.lat != null &&
      candidate.lng != null &&
      merchant.lat != null &&
      merchant.lng != null
    ) {
      const distKm = haversineKm(
        candidate.lat,
        candidate.lng,
        merchant.lat,
        merchant.lng
      );
      geoScore = distKm < GEO_THRESHOLD_KM ? 0.3 : 0;
    }

    const combinedScore = nameScore + geoScore;
    if (combinedScore > bestScore) {
      bestScore = combinedScore;
      bestMatch = merchant;
    }
  }

  if (bestMatch) {
    return {
      matched: true,
      merchantId: bestMatch.merchantId,
      confidence: Math.min(1, bestScore),
    };
  }

  return { matched: false };
}

export { MerchantDoc };
