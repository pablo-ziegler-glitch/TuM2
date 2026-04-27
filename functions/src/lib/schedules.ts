import { Timestamp } from "firebase-admin/firestore";
import {
  DayOfWeek,
  MerchantScheduleDoc,
  ScheduleSummary,
  WeeklyScheduleEntry,
} from "./types";

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
  // Extraer componentes individuales en la zona horaria de Argentina
  // para evitar dependencia del parsing de new Date(string) que varía
  // entre versiones de Node.js.
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: TZ,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
    hour12: false,
  }).formatToParts(ref);

  const get = (type: Intl.DateTimeFormatPartTypes) =>
    Number(parts.find((p) => p.type === type)?.value ?? 0);

  return new Date(
    get("year"),
    get("month") - 1,
    get("day"),
    get("hour"),
    get("minute"),
    get("second"),
  );
}

function parseHHMM(timeStr: string): { hours: number; minutes: number } {
  const [h, m] = timeStr.split(":").map(Number);
  return { hours: h ?? 0, minutes: m ?? 0 };
}

function timeToMinutes(timeStr: string): number {
  const { hours, minutes } = parseHHMM(timeStr);
  return hours * 60 + minutes;
}

function argentinaLocalToUtcMillis(
  year: number,
  month: number,
  day: number,
  hours: number,
  minutes: number
): number {
  // Argentina se maneja en UTC-3 en el MVP.
  return Date.UTC(year, month - 1, day, hours + 3, minutes, 0, 0);
}

function resolveNowParts(now?: Date): {
  year: number;
  month: number;
  day: number;
  hour: number;
  minute: number;
  second: number;
} {
  const ref = now ?? new Date();
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: TZ,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
    hour12: false,
  }).formatToParts(ref);

  const get = (type: Intl.DateTimeFormatPartTypes) =>
    Number(parts.find((p) => p.type === type)?.value ?? 0);

  return {
    year: get("year"),
    month: get("month"),
    day: get("day"),
    hour: get("hour"),
    minute: get("minute"),
    second: get("second"),
  };
}

function addDaysLocalDate(
  year: number,
  month: number,
  day: number,
  offsetDays: number
): { year: number; month: number; day: number } {
  const seed = new Date(Date.UTC(year, month - 1, day + offsetDays));
  return {
    year: seed.getUTCFullYear(),
    month: seed.getUTCMonth() + 1,
    day: seed.getUTCDate(),
  };
}

function getDayKeyFromLocalDate(
  year: number,
  month: number,
  day: number
): DayOfWeek {
  const utcMidday = new Date(Date.UTC(year, month - 1, day, 12, 0, 0));
  return DAY_INDEX_TO_KEY[utcMidday.getUTCDay()]!;
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

export interface NextScheduleTransition {
  scheduleSummary: ScheduleSummary;
  nextOpenAt: Timestamp | null;
  nextCloseAt: Timestamp | null;
  nextTransitionAt: Timestamp | null;
}

export function computeNextScheduleTransition(
  scheduleDoc: MerchantScheduleDoc,
  now?: Date
): NextScheduleTransition {
  const nowParts = resolveNowParts(now);
  const nowMs = (now ?? new Date()).getTime();
  const todayKey = getDayKeyFromLocalDate(
    nowParts.year,
    nowParts.month,
    nowParts.day
  );
  const todayEntry = scheduleDoc.schedule[todayKey];
  const timezone = scheduleDoc.timezone?.trim() || TZ;

  const todayWindows = !todayEntry || todayEntry.closed
    ? []
    : [{
        opensAtLocalMinutes: timeToMinutes(todayEntry.open),
        closesAtLocalMinutes: timeToMinutes(todayEntry.close),
      }];

  const hasSchedule = Object.values(scheduleDoc.schedule ?? {}).some(
    (entry) => !!entry && entry.closed !== true
  );

  const summary: ScheduleSummary = {
    timezone,
    todayWindows,
    hasSchedule,
  };
  if (scheduleDoc.updatedAt) {
    summary.scheduleLastUpdatedAt = scheduleDoc.updatedAt;
  }

  const openCandidates: number[] = [];
  const closeCandidates: number[] = [];
  for (let dayOffset = 0; dayOffset <= 7; dayOffset++) {
    const localDate = addDaysLocalDate(
      nowParts.year,
      nowParts.month,
      nowParts.day,
      dayOffset
    );
    const dayKey = getDayKeyFromLocalDate(
      localDate.year,
      localDate.month,
      localDate.day
    );
    const entry = scheduleDoc.schedule[dayKey];
    if (!entry || entry.closed) continue;

    const open = parseHHMM(entry.open);
    const close = parseHHMM(entry.close);
    const openMs = argentinaLocalToUtcMillis(
      localDate.year,
      localDate.month,
      localDate.day,
      open.hours,
      open.minutes
    );
    let closeMs = argentinaLocalToUtcMillis(
      localDate.year,
      localDate.month,
      localDate.day,
      close.hours,
      close.minutes
    );
    if (closeMs <= openMs) {
      closeMs += 24 * 60 * 60 * 1000;
    }

    if (openMs > nowMs) openCandidates.push(openMs);
    if (closeMs > nowMs) closeCandidates.push(closeMs);
  }

  const nextOpenMs = openCandidates.length > 0 ? Math.min(...openCandidates) : null;
  const nextCloseMs = closeCandidates.length > 0 ? Math.min(...closeCandidates) : null;
  const nextTransitionMs = [nextOpenMs, nextCloseMs]
    .filter((value): value is number => value != null)
    .reduce<number | null>((acc, value) => {
      if (acc == null) return value;
      return Math.min(acc, value);
    }, null);

  return {
    scheduleSummary: summary,
    nextOpenAt: nextOpenMs != null ? Timestamp.fromMillis(nextOpenMs) : null,
    nextCloseAt: nextCloseMs != null ? Timestamp.fromMillis(nextCloseMs) : null,
    nextTransitionAt: nextTransitionMs != null
      ? Timestamp.fromMillis(nextTransitionMs)
      : null,
  };
}
