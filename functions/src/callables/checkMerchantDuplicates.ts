import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore } from "firebase-admin/firestore";

const db = () => getFirestore();

interface CheckDuplicatesRequest {
  name: string;
  lat: number;
  lng: number;
  zoneId: string;
}

interface DuplicateCandidate {
  id: string;
  name: string;
  address: string;
  ownerUserId: string | null;
}

interface CheckDuplicatesResponse {
  hasSoftDuplicate: boolean;
  hasHardDuplicate: boolean;
  candidates: DuplicateCandidate[];
}

/** Lowercase, remove accents, collapse whitespace, strip punctuation. */
function normalize(str: string): string {
  return str
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^\w\s]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

/** Levenshtein distance between two strings. */
function levenshtein(a: string, b: string): number {
  const m = a.length;
  const n = b.length;
  const dp: number[][] = Array.from({ length: m + 1 }, (_, i) =>
    Array.from({ length: n + 1 }, (_, j) => (i === 0 ? j : j === 0 ? i : 0))
  );
  for (let i = 1; i <= m; i++) {
    for (let j = 1; j <= n; j++) {
      dp[i][j] =
        a[i - 1] === b[j - 1]
          ? dp[i - 1][j - 1]
          : 1 + Math.min(dp[i - 1][j - 1], dp[i - 1][j], dp[i][j - 1]);
    }
  }
  return dp[m][n];
}

/** Haversine distance in meters between two lat/lng points. */
function haversineMeters(
  lat1: number,
  lng1: number,
  lat2: number,
  lng2: number
): number {
  const R = 6_371_000;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLng = ((lng2 - lng1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLng / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

/**
 * checkMerchantDuplicates
 *
 * Callable HTTPS function. Checks whether a new merchant being registered
 * is a potential duplicate of an existing one in the same zone.
 *
 * - Soft duplicate: Levenshtein ≤ 3 between normalized names AND geo distance < 500m
 * - Hard duplicate: identical normalized name OR (Levenshtein ≤ 1 AND exact same address)
 *
 * Only callable by authenticated users with role 'owner'.
 */
export const checkMerchantDuplicates = onCall(
  { enforceAppCheck: false },
  async (request): Promise<CheckDuplicatesResponse> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Autenticación requerida.");
    }

    const uid = request.auth.uid;
    const userSnap = await db().doc(`users/${uid}`).get();
    if (!userSnap.exists || userSnap.data()?.role !== "owner") {
      throw new HttpsError("permission-denied", "Solo usuarios 'owner' pueden usar esta función.");
    }

    const { name, lat, lng, zoneId } = request.data as CheckDuplicatesRequest;
    if (!name || lat == null || lng == null || !zoneId) {
      throw new HttpsError("invalid-argument", "name, lat, lng y zoneId son requeridos.");
    }

    const normalizedInput = normalize(name);

    // Query merchants: filter by zone if provided, otherwise search all
    const merchantsQuery = zoneId
      ? db().collection("merchants").where("zone", "==", zoneId)
      : db().collection("merchants").limit(500);
    const merchantsSnap = await merchantsQuery.get();

    const candidates: DuplicateCandidate[] = [];
    let hasSoftDuplicate = false;
    let hasHardDuplicate = false;

    for (const doc of merchantsSnap.docs) {
      const data = doc.data();
      const existingName = data.name ?? "";
      const normalizedExisting = normalize(existingName);

      const distance = levenshtein(normalizedInput, normalizedExisting);
      const isNameIdentical = normalizedInput === normalizedExisting;
      const isNameVerySimilar = distance <= 1;
      const isSimilarName = distance <= 3;

      // Geo distance check (if coordinates available)
      let geoDistanceMeters = Infinity;
      if (data.lat != null && data.lng != null) {
        geoDistanceMeters = haversineMeters(lat, lng, data.lat, data.lng);
      }
      const isNearby = geoDistanceMeters < 500;

      const isSameAddress =
        data.address && data.address.trim().toLowerCase() === "";

      // Hard duplicate detection
      if (isNameIdentical || (isNameVerySimilar && (isSameAddress || isNearby))) {
        hasHardDuplicate = true;
        candidates.push({
          id: doc.id,
          name: existingName,
          address: data.address ?? "",
          ownerUserId: data.ownerUserId ?? null,
        });
        continue;
      }

      // Soft duplicate detection
      if (isSimilarName && isNearby) {
        hasSoftDuplicate = true;
        candidates.push({
          id: doc.id,
          name: existingName,
          address: data.address ?? "",
          ownerUserId: data.ownerUserId ?? null,
        });
      }
    }

    console.log(
      `[checkMerchantDuplicates] name="${name}" zone="${zoneId}" → soft=${hasSoftDuplicate} hard=${hasHardDuplicate} candidates=${candidates.length}`
    );

    return { hasSoftDuplicate, hasHardDuplicate, candidates };
  }
);
