export const DUTY_TIME_ZONE = "America/Argentina/Buenos_Aires";

const DATE_KEY_REGEX = /^\d{4}-\d{2}-\d{2}$/;

export function isValidDateKey(value: string): boolean {
  if (!DATE_KEY_REGEX.test(value)) return false;
  const [year, month, day] = value.split("-").map(Number);
  if (!year || !month || !day) return false;
  const date = new Date(Date.UTC(year, month - 1, day));
  return (
    date.getUTCFullYear() === year &&
    date.getUTCMonth() === month - 1 &&
    date.getUTCDate() === day
  );
}

export function formatDateInArgentina(date: Date): string {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: DUTY_TIME_ZONE,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(date);

  const year = parts.find((p) => p.type === "year")?.value ?? "0000";
  const month = parts.find((p) => p.type === "month")?.value ?? "00";
  const day = parts.find((p) => p.type === "day")?.value ?? "00";
  return `${year}-${month}-${day}`;
}

export function addDaysToDateKey(dateKey: string, days: number): string {
  const [year, month, day] = dateKey.split("-").map(Number);
  const seed = new Date(Date.UTC(year, (month ?? 1) - 1, day ?? 1));
  seed.setUTCDate(seed.getUTCDate() + days);
  const y = seed.getUTCFullYear();
  const m = String(seed.getUTCMonth() + 1).padStart(2, "0");
  const d = String(seed.getUTCDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}

export function areRangesOverlapping(
  aStartsAt: Date,
  aEndsAt: Date,
  bStartsAt: Date,
  bEndsAt: Date
): boolean {
  return aStartsAt < bEndsAt && bStartsAt < aEndsAt;
}

export function isPharmacyCategory(input: unknown): boolean {
  if (typeof input !== "string") return false;
  const value = input.trim().toLowerCase();
  if (!value) return false;
  return value === "pharmacy" ||
    value === "farmacia" ||
    value.includes("farm");
}
