import { geohashForLocation, geohashQueryBounds, Geopoint } from "geofire-common";

/**
 * Encodes a lat/lng pair into a geohash string.
 */
export function encodeGeohash(lat: number, lng: number, precision = 9): string {
  return geohashForLocation([lat, lng] as Geopoint, precision);
}

/**
 * Returns geohash query bounds for a center point and radius.
 * Used for geographic proximity queries in Firestore.
 */
export function getGeohashQueryBounds(
  center: [number, number],
  radiusMeters: number
): Array<[string, string]> {
  return geohashQueryBounds(center as Geopoint, radiusMeters);
}
