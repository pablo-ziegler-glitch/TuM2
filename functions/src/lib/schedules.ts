import { DayOfWeek, MerchantScheduleDoc, WeeklyScheduleEntry } from "./types";

const TZ = "America/Argentina/Buenos_Aires";

const DAY_INDEX_TO_KEY: DayOfWeek[] = [
  "sunday",
  "monday",
  "tuesday",
  "wednesday",
  "thursday",
  "friday",
  "saturday",
];

function getNowInArgentina(now?: Date): Date {
  const ref = now ?? new Date();
  // Convert to Argentina time by formatting and re-parsing
  const formatted = ref.toLocaleString("en-CA", {
    timeZone: TZ,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
    hour12: false,
  });
  return new Date(formatted);
}

function parseHHMM(timeStr: string): { hours: number; minutes: number } {
  const [h, m] = timeStr.split(":").map(Number);
  return { hours: h ?? 0, minutes: m ?? 0 };
}

function timeToMinutes(timeStr: string): number {
  const { hours, minutes } = parseHHMM(timeStr);
  return hours * 60 + minutes;
}

function getTodayEntry(
  scheduleDoc: MerchantScheduleDoc,
  now?: Date
): WeeklyScheduleEntry | null {
  const localNow = getNowInArgentina(now);
  const dayKey = DAY_INDEX_TO_KEY[localNow.getDay()];
  if (!dayKey) return null;
  return scheduleDoc.schedule[dayKey] ?? null;
}

/**
 * Determines whether a merchant is currently open based on its weekly schedule.
 * Handles overnight hours (close < open, e.g. 22:00–02:00).
 */
export function isOpenNow(
  scheduleDoc: MerchantScheduleDoc,
  now?: Date
): boolean {
  const localNow = getNowInArgentina(now);
  const dayKey = DAY_INDEX_TO_KEY[localNow.getDay()];
  if (!dayKey) return false;

  const entry = scheduleDoc.schedule[dayKey];
  if (!entry || entry.closed) return false;

  const currentMinutes =
    localNow.getHours() * 60 + localNow.getMinutes();
  const openMinutes = timeToMinutes(entry.open);
  const closeMinutes = timeToMinutes(entry.close);

  if (closeMinutes > openMinutes) {
    // Normal range: e.g. 09:00–20:00
    return currentMinutes >= openMinutes && currentMinutes < closeMinutes;
  } else {
    // Overnight: e.g. 22:00–02:00
    return currentMinutes >= openMinutes || currentMinutes < closeMinutes;
  }
}

/**
 * Returns a human-readable schedule label for today in Spanish.
 * E.g. "Hoy: 9:00–20:00" or "Cerrado hoy"
 */
export function todayScheduleLabel(
  scheduleDoc: MerchantScheduleDoc,
  now?: Date
): string {
  const entry = getTodayEntry(scheduleDoc, now);
  if (!entry || entry.closed) return "Cerrado hoy";
  return `Hoy: ${entry.open}–${entry.close}`;
}

/**
 * Checks whether a given date (in Argentina TZ) falls on today.
 */
export function isToday(date: Date, now?: Date): boolean {
  const localNow = getNowInArgentina(now);
  const localDate = getNowInArgentina(date);
  return (
    localDate.getFullYear() === localNow.getFullYear() &&
    localDate.getMonth() === localNow.getMonth() &&
    localDate.getDate() === localNow.getDate()
  );
}

/**
 * Returns today's date string in YYYY-MM-DD format (Argentina TZ).
 */
export function todayDateString(now?: Date): string {
  const localNow = getNowInArgentina(now);
  const y = localNow.getFullYear();
  const m = String(localNow.getMonth() + 1).padStart(2, "0");
  const d = String(localNow.getDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}
