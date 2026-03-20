import { ZoneCoverageMetrics } from "./types";

/**
 * Computes a 0–100 useful coverage score for a zone.
 * Weighs verified + claimed merchants more heavily than referential ones.
 */
export function computeUsefulCoverageScore(
  counts: Pick<
    ZoneCoverageMetrics,
    | "visibleMerchantCount"
    | "verifiedCount"
    | "referentialCount"
    | "communitySubmittedCount"
  >
): number {
  const { visibleMerchantCount, verifiedCount, referentialCount, communitySubmittedCount } =
    counts;

  if (visibleMerchantCount === 0) return 0;

  const weightedScore =
    verifiedCount * 1.0 +
    communitySubmittedCount * 0.7 +
    referentialCount * 0.3;

  const maxPossible = visibleMerchantCount;
  const raw = (weightedScore / maxPossible) * 100;

  return Math.min(100, Math.round(raw));
}
