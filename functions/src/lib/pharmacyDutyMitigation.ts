import { HttpsError } from "firebase-functions/v2/https";

export type ActorRole =
  | "owner"
  | "owner_pending"
  | "admin"
  | "super_admin"
  | "customer"
  | "unknown";

export type DutyStatus =
  | "draft"
  | "published"
  | "scheduled"
  | "active"
  | "incident_reported"
  | "replacement_pending"
  | "reassigned"
  | "cancelled";

export type DutyConfirmationStatus =
  | "pending"
  | "confirmed"
  | "overdue"
  | "incident_reported"
  | "replaced";

export type DutyPublicStatusLabel =
  | "guardia_confirmada"
  | "guardia_en_verificacion"
  | "cambio_operativo_en_curso";

export type DutyConfidenceLevel = "high" | "medium" | "low";

export type IncidentType =
  | "power_outage"
  | "staff_shortage"
  | "technical_issue"
  | "operational_issue"
  | "other";

export type RoundStatus = "open" | "covered" | "expired" | "cancelled";

export type RequestStatus =
  | "pending"
  | "accepted"
  | "rejected"
  | "expired"
  | "cancelled";

export type RequestAction = "accept" | "reject";

export interface PharmacyDutyRulesConfig {
  maxReassignmentDistanceKm: number;
  requestExpiryMinutes: number;
  maxCandidatesPerRound: number;
  allowParallelRequests: boolean;
  preventMultipleOpenRoundsPerDuty: boolean;
}

export const DEFAULT_PHARMACY_DUTY_RULES_CONFIG: PharmacyDutyRulesConfig = {
  maxReassignmentDistanceKm: 10,
  requestExpiryMinutes: 15,
  maxCandidatesPerRound: 5,
  allowParallelRequests: true,
  preventMultipleOpenRoundsPerDuty: true,
};

const INCIDENT_TYPES: IncidentType[] = [
  "power_outage",
  "staff_shortage",
  "technical_issue",
  "operational_issue",
  "other",
];

export function resolveActorRole(roleClaim: unknown): ActorRole {
  if (typeof roleClaim !== "string" || roleClaim.trim().length === 0) {
    return "unknown";
  }

  const normalized = roleClaim.trim().toLowerCase();
  if (normalized === "owner") return "owner";
  if (normalized === "owner_pending") return "owner_pending";
  if (normalized === "admin") return "admin";
  if (normalized === "super_admin") return "super_admin";
  if (normalized === "customer") return "customer";
  return "unknown";
}

export function isAdminRole(role: ActorRole): boolean {
  return role === "admin" || role === "super_admin";
}

export function assertMutableRole(role: ActorRole): void {
  if (role === "owner" || isAdminRole(role)) return;
  throw new HttpsError(
    "permission-denied",
    "No tenés permisos para gestionar guardias de farmacia."
  );
}

export function parseIncidentType(value: unknown): IncidentType {
  if (typeof value !== "string") {
    throw new HttpsError(
      "invalid-argument",
      "incidentType es requerido."
    );
  }
  const normalized = value.trim().toLowerCase() as IncidentType;
  if (!INCIDENT_TYPES.includes(normalized)) {
    throw new HttpsError("invalid-argument", "incidentType inválido.");
  }
  return normalized;
}

export function parseRequestAction(value: unknown): RequestAction {
  if (value === "accept" || value === "reject") return value;
  throw new HttpsError(
    "invalid-argument",
    "action debe ser accept o reject."
  );
}

export function normalizeDutyStatus(value: unknown): DutyStatus {
  if (typeof value !== "string" || value.trim().length === 0) {
    return "scheduled";
  }

  const normalized = value.trim().toLowerCase();
  if (normalized === "draft" || normalized === "published") {
    return "scheduled";
  }
  if (
    normalized === "scheduled" ||
    normalized === "active" ||
    normalized === "incident_reported" ||
    normalized === "replacement_pending" ||
    normalized === "reassigned" ||
    normalized === "cancelled"
  ) {
    return normalized;
  }
  throw new HttpsError("invalid-argument", "status inválido.");
}

export function normalizeDutyConfirmationStatus(
  value: unknown
): DutyConfirmationStatus {
  if (typeof value !== "string" || value.trim().length === 0) {
    return "pending";
  }

  const normalized = value.trim().toLowerCase();
  if (
    normalized === "pending" ||
    normalized === "confirmed" ||
    normalized === "overdue" ||
    normalized === "incident_reported" ||
    normalized === "replaced"
  ) {
    return normalized;
  }
  return "pending";
}

export function parsePositiveInt(
  value: unknown,
  {
    field,
    fallback,
    min = 1,
    max = Number.MAX_SAFE_INTEGER,
  }: {
    field: string;
    fallback: number;
    min?: number;
    max?: number;
  }
): number {
  if (value == null) return fallback;
  if (typeof value !== "number" || !Number.isFinite(value)) return fallback;
  const parsed = Math.trunc(value);
  if (parsed < min || parsed > max) {
    throw new HttpsError(
      "invalid-argument",
      `${field} debe estar entre ${min} y ${max}.`
    );
  }
  return parsed;
}

export function deriveDutyPublicState(input: {
  status: DutyStatus;
  confirmationStatus: DutyConfirmationStatus;
  incidentOpen?: boolean;
}): { confidenceLevel: DutyConfidenceLevel; publicStatusLabel: DutyPublicStatusLabel } {
  if (
    input.incidentOpen === true ||
    input.status === "incident_reported" ||
    input.status === "replacement_pending" ||
    input.confirmationStatus === "incident_reported"
  ) {
    return {
      confidenceLevel: "low",
      publicStatusLabel: "cambio_operativo_en_curso",
    };
  }

  if (
    input.confirmationStatus === "confirmed" ||
    input.confirmationStatus === "replaced" ||
    input.status === "active" ||
    input.status === "reassigned"
  ) {
    return {
      confidenceLevel: "high",
      publicStatusLabel: "guardia_confirmada",
    };
  }

  return {
    confidenceLevel: "medium",
    publicStatusLabel: "guardia_en_verificacion",
  };
}

export function haversineDistanceKm(
  fromLat: number,
  fromLng: number,
  toLat: number,
  toLng: number
): number {
  const toRadians = (value: number) => (value * Math.PI) / 180;
  const earthRadiusKm = 6371;

  const dLat = toRadians(toLat - fromLat);
  const dLng = toRadians(toLng - fromLng);
  const lat1 = toRadians(fromLat);
  const lat2 = toRadians(toLat);

  const a = Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLng / 2) ** 2;
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return earthRadiusKm * c;
}

export function normalizeNote(value: unknown): string | null {
  if (value == null) return null;
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", "note debe ser string.");
  }
  const trimmed = value.trim();
  if (trimmed.length === 0) return null;
  if (trimmed.length > 500) {
    throw new HttpsError("invalid-argument", "note excede 500 caracteres.");
  }
  return trimmed;
}

export function distanceBucket(distanceKm: number): string {
  if (distanceKm <= 2) return "0_2km";
  if (distanceKm <= 5) return "2_5km";
  if (distanceKm <= 10) return "5_10km";
  return "10km_plus";
}

export function roundDistance(distanceKm: number): number {
  return Math.round(distanceKm * 100) / 100;
}
