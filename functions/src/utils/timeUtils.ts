import { WeeklySchedule, DaySchedule } from "../types";

const DAYS_OF_WEEK = [
  "sunday",
  "monday",
  "tuesday",
  "wednesday",
  "thursday",
  "friday",
  "saturday",
] as const;

type DayKey = (typeof DAYS_OF_WEEK)[number];

/**
 * Returns the current date string (YYYY-MM-DD) in the given timezone.
 */
export function getCurrentDateInTimezone(timezone: string): string {
  const formatter = new Intl.DateTimeFormat("en-CA", {
    timeZone: timezone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  });
  return formatter.format(new Date());
}

/**
 * Returns the current time in minutes since midnight in the given timezone.
 */
function getCurrentMinutesInTimezone(timezone: string): number {
  const now = new Date();
  const formatter = new Intl.DateTimeFormat("en-US", {
    timeZone: timezone,
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  });
  const parts = formatter.formatToParts(now);
  const hour = parseInt(parts.find((p) => p.type === "hour")?.value ?? "0");
  const minute = parseInt(parts.find((p) => p.type === "minute")?.value ?? "0");
  return hour * 60 + minute;
}

/**
 * Returns the current day of week key ("monday", "tuesday", etc.) in the given timezone.
 */
function getCurrentDayKey(timezone: string): DayKey {
  const now = new Date();
  const formatter = new Intl.DateTimeFormat("en-US", {
    timeZone: timezone,
    weekday: "long",
  });
  return formatter.format(now).toLowerCase() as DayKey;
}

/**
 * Parses "HH:mm" string into minutes since midnight.
 */
function parseTime(time: string): number {
  const [h, m] = time.split(":").map(Number);
  return (h || 0) * 60 + (m || 0);
}

/**
 * Checks if the store is currently open based on its weekly schedule and timezone.
 */
export function isOpenNow(
  weeklySchedule: WeeklySchedule | null | undefined,
  timezone: string
): boolean {
  if (!weeklySchedule) return false;

  const dayKey = getCurrentDayKey(timezone);
  const daySchedule: DaySchedule | undefined =
    weeklySchedule[dayKey as keyof WeeklySchedule];

  if (!daySchedule || daySchedule.closed) return false;

  const currentMinutes = getCurrentMinutesInTimezone(timezone);
  const openMinutes = parseTime(daySchedule.open);
  const closeMinutes = parseTime(daySchedule.close);

  // Handle overnight hours (e.g., open 22:00, close 02:00)
  if (closeMinutes < openMinutes) {
    return currentMinutes >= openMinutes || currentMinutes < closeMinutes;
  }

  return currentMinutes >= openMinutes && currentMinutes < closeMinutes;
}

/**
 * Checks if the store has late-night hours today (closes after midnight or closes at/after 00:00).
 */
export function isLateNightNow(
  weeklySchedule: WeeklySchedule | null | undefined,
  timezone: string
): boolean {
  if (!weeklySchedule) return false;

  const dayKey = getCurrentDayKey(timezone);
  const daySchedule: DaySchedule | undefined =
    weeklySchedule[dayKey as keyof WeeklySchedule];

  if (!daySchedule || daySchedule.closed) return false;

  const closeMinutes = parseTime(daySchedule.close);
  // Late night: closes after 00:00 (i.e., next day) or after 23:00
  return closeMinutes < parseTime("06:00") || closeMinutes >= parseTime("23:00");
}

/**
 * Calculates the completeness score (0-100) of the weekly schedule.
 * Score is the percentage of weekdays that have a non-closed schedule.
 */
export function calculateCompletenessScore(
  weeklySchedule: WeeklySchedule | null | undefined
): number {
  if (!weeklySchedule) return 0;

  const days: (keyof WeeklySchedule)[] = [
    "monday",
    "tuesday",
    "wednesday",
    "thursday",
    "friday",
    "saturday",
    "sunday",
  ];

  const configuredDays = days.filter(
    (day) => weeklySchedule[day] && !weeklySchedule[day].closed
  ).length;

  return Math.round((configuredDays / 7) * 100);
}
