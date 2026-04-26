import { FieldValue, Timestamp, getFirestore } from "firebase-admin/firestore";

const db = () => getFirestore();
const TIME_ZONE = "America/Argentina/Buenos_Aires";
const ALERT_CACHE_TTL_MS = 60_000;

export type AlertLevel = "NORMAL" | "WARNING" | "DANGER" | "CRITICAL" | "SHUTDOWN";

export interface UsageMetrics {
  firestore_reads: number;
  firestore_writes: number;
  firestore_deletes: number;
  functions_invocations: number;
  storage_downloads: number;
  storage_uploads: number;
  hosting_bandwidth_mb: number;
  alert_level: AlertLevel;
  last_updated: Date;
}

export interface UsageDeltaInput {
  reads?: number;
  writes?: number;
  deletes?: number;
  storage_downloads?: number;
  storage_uploads?: number;
  hosting_bandwidth_mb?: number;
  function_invocation?: boolean;
  functions_invocations?: number;
}

export const DAILY_LIMITS = {
  firestore_reads: 50_000,
  firestore_writes: 20_000,
  firestore_deletes: 20_000,
  storage_downloads: 1_024,
  storage_uploads: 1_024,
  hosting_bandwidth_mb: 10_240,
} as const;

export const MONTHLY_LIMITS = {
  functions_invocations: 2_000_000,
} as const;

let alertLevelCache: { value: AlertLevel; expiresAtMs: number } | null = null;

function asNonNegativeNumber(value: unknown): number {
  const numeric = Number(value);
  if (!Number.isFinite(numeric) || numeric < 0) return 0;
  return numeric;
}

function resolveDateKeyPart(now: Date): { year: number; month: number; day: number } {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: TIME_ZONE,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  })
    .formatToParts(now)
    .reduce<Record<string, number>>((acc, part) => {
      if (part.type !== "literal") acc[part.type] = Number(part.value);
      return acc;
    }, {});

  return {
    year: parts.year,
    month: parts.month,
    day: parts.day,
  };
}

function buildDateKey(now: Date): string {
  const p = resolveDateKeyPart(now);
  return `${p.year}-${String(p.month).padStart(2, "0")}-${String(p.day).padStart(2, "0")}`;
}

function buildMonthKey(now: Date): string {
  const p = resolveDateKeyPart(now);
  return `${p.year}-${String(p.month).padStart(2, "0")}`;
}

function readTimestampAsDate(raw: unknown): Date | null {
  if (raw instanceof Timestamp) return raw.toDate();
  if (raw instanceof Date) return raw;
  return null;
}

function usagePercentage(current: number, limit: number): number {
  if (!Number.isFinite(limit) || limit <= 0) return 0;
  return (asNonNegativeNumber(current) / limit) * 100;
}

function maxAlertLevel(current: AlertLevel, candidate: AlertLevel): AlertLevel {
  const rank: Record<AlertLevel, number> = {
    NORMAL: 0,
    WARNING: 1,
    DANGER: 2,
    CRITICAL: 3,
    SHUTDOWN: 4,
  };
  return rank[candidate] > rank[current] ? candidate : current;
}

function alertFromPercentage(percentage: number): AlertLevel {
  if (percentage >= 95) return "SHUTDOWN";
  if (percentage >= 85) return "CRITICAL";
  if (percentage >= 75) return "DANGER";
  if (percentage >= 50) return "WARNING";
  return "NORMAL";
}

function normalizeUsageDelta(input: UsageDeltaInput): {
  firestore_reads: number;
  firestore_writes: number;
  firestore_deletes: number;
  storage_downloads: number;
  storage_uploads: number;
  hosting_bandwidth_mb: number;
  functions_invocations: number;
} {
  const explicitFunctionInvocations = asNonNegativeNumber(input.functions_invocations);
  const invocationFromBool = input.function_invocation === true ? 1 : 0;
  return {
    firestore_reads: asNonNegativeNumber(input.reads),
    firestore_writes: asNonNegativeNumber(input.writes),
    firestore_deletes: asNonNegativeNumber(input.deletes),
    storage_downloads: asNonNegativeNumber(input.storage_downloads),
    storage_uploads: asNonNegativeNumber(input.storage_uploads),
    hosting_bandwidth_mb: asNonNegativeNumber(input.hosting_bandwidth_mb),
    functions_invocations:
      explicitFunctionInvocations > 0 ? explicitFunctionInvocations : invocationFromBool,
  };
}

function hasAnyIncrement(delta: {
  firestore_reads: number;
  firestore_writes: number;
  firestore_deletes: number;
  storage_downloads: number;
  storage_uploads: number;
  hosting_bandwidth_mb: number;
  functions_invocations: number;
}): boolean {
  return (
    delta.firestore_reads > 0 ||
    delta.firestore_writes > 0 ||
    delta.firestore_deletes > 0 ||
    delta.storage_downloads > 0 ||
    delta.storage_uploads > 0 ||
    delta.hosting_bandwidth_mb > 0 ||
    delta.functions_invocations > 0
  );
}

export function getArgDateKeyForTesting(now = new Date()): string {
  return buildDateKey(now);
}

export function getArgMonthKeyForTesting(now = new Date()): string {
  return buildMonthKey(now);
}

export function calculateUsagePercentages(metrics: Partial<UsageMetrics>): Record<string, number> {
  return {
    firestore_reads: usagePercentage(
      asNonNegativeNumber(metrics.firestore_reads),
      DAILY_LIMITS.firestore_reads
    ),
    firestore_writes: usagePercentage(
      asNonNegativeNumber(metrics.firestore_writes),
      DAILY_LIMITS.firestore_writes
    ),
    firestore_deletes: usagePercentage(
      asNonNegativeNumber(metrics.firestore_deletes),
      DAILY_LIMITS.firestore_deletes
    ),
    storage_downloads: usagePercentage(
      asNonNegativeNumber(metrics.storage_downloads),
      DAILY_LIMITS.storage_downloads
    ),
    storage_uploads: usagePercentage(
      asNonNegativeNumber(metrics.storage_uploads),
      DAILY_LIMITS.storage_uploads
    ),
    hosting_bandwidth_mb: usagePercentage(
      asNonNegativeNumber(metrics.hosting_bandwidth_mb),
      DAILY_LIMITS.hosting_bandwidth_mb
    ),
    functions_invocations: usagePercentage(
      asNonNegativeNumber(metrics.functions_invocations),
      MONTHLY_LIMITS.functions_invocations
    ),
  };
}

export function calculateAlertLevel(metrics: Partial<UsageMetrics>): AlertLevel {
  const percentages = calculateUsagePercentages(metrics);
  let result: AlertLevel = "NORMAL";
  for (const percentage of Object.values(percentages)) {
    result = maxAlertLevel(result, alertFromPercentage(percentage));
  }
  return result;
}

export async function ensureUsageCounterDocs(now = new Date()): Promise<void> {
  const dateKey = buildDateKey(now);
  const monthKey = buildMonthKey(now);
  await Promise.all([
    db().doc(`_usage_counters/${dateKey}`).set(
      {
        date_key: dateKey,
        firestore_reads: FieldValue.increment(0),
        firestore_writes: FieldValue.increment(0),
        firestore_deletes: FieldValue.increment(0),
        storage_downloads: FieldValue.increment(0),
        storage_uploads: FieldValue.increment(0),
        hosting_bandwidth_mb: FieldValue.increment(0),
        alert_level: "NORMAL",
        last_updated: FieldValue.serverTimestamp(),
      },
      { merge: true }
    ),
    db().doc(`_usage_counters_monthly/${monthKey}`).set(
      {
        month_key: monthKey,
        functions_invocations: FieldValue.increment(0),
        last_updated: FieldValue.serverTimestamp(),
      },
      { merge: true }
    ),
  ]);
}

export async function trackUsage(input: UsageDeltaInput): Promise<void> {
  const delta = normalizeUsageDelta(input);
  if (!hasAnyIncrement(delta)) return;

  const now = new Date();
  const dateKey = buildDateKey(now);
  const monthKey = buildMonthKey(now);

  await Promise.all([
    db().doc(`_usage_counters/${dateKey}`).set(
      {
        date_key: dateKey,
        firestore_reads: FieldValue.increment(delta.firestore_reads),
        firestore_writes: FieldValue.increment(delta.firestore_writes),
        firestore_deletes: FieldValue.increment(delta.firestore_deletes),
        storage_downloads: FieldValue.increment(delta.storage_downloads),
        storage_uploads: FieldValue.increment(delta.storage_uploads),
        hosting_bandwidth_mb: FieldValue.increment(delta.hosting_bandwidth_mb),
        last_updated: FieldValue.serverTimestamp(),
      },
      { merge: true }
    ),
    db().doc(`_usage_counters_monthly/${monthKey}`).set(
      {
        month_key: monthKey,
        functions_invocations: FieldValue.increment(delta.functions_invocations),
        last_updated: FieldValue.serverTimestamp(),
      },
      { merge: true }
    ),
  ]);
}

export async function getUsageSummary(now = new Date()): Promise<UsageMetrics> {
  const dateKey = buildDateKey(now);
  const monthKey = buildMonthKey(now);
  const [dailySnap, monthlySnap] = await Promise.all([
    db().doc(`_usage_counters/${dateKey}`).get(),
    db().doc(`_usage_counters_monthly/${monthKey}`).get(),
  ]);

  const daily = dailySnap.data() ?? {};
  const monthly = monthlySnap.data() ?? {};
  const lastDaily = readTimestampAsDate(daily["last_updated"]);
  const lastMonthly = readTimestampAsDate(monthly["last_updated"]);
  const lastUpdated =
    lastDaily && lastMonthly
      ? new Date(Math.max(lastDaily.getTime(), lastMonthly.getTime()))
      : lastDaily ?? lastMonthly ?? now;

  const summary: UsageMetrics = {
    firestore_reads: asNonNegativeNumber(daily["firestore_reads"]),
    firestore_writes: asNonNegativeNumber(daily["firestore_writes"]),
    firestore_deletes: asNonNegativeNumber(daily["firestore_deletes"]),
    storage_downloads: asNonNegativeNumber(daily["storage_downloads"]),
    storage_uploads: asNonNegativeNumber(daily["storage_uploads"]),
    hosting_bandwidth_mb: asNonNegativeNumber(daily["hosting_bandwidth_mb"]),
    functions_invocations: asNonNegativeNumber(monthly["functions_invocations"]),
    alert_level: "NORMAL",
    last_updated: lastUpdated,
  };

  summary.alert_level = calculateAlertLevel(summary);
  return summary;
}

export async function getCurrentAlertLevel(): Promise<AlertLevel> {
  const nowMs = Date.now();
  if (alertLevelCache && alertLevelCache.expiresAtMs > nowMs) {
    return alertLevelCache.value;
  }
  const summary = await getUsageSummary();
  const value = summary.alert_level;
  alertLevelCache = {
    value,
    expiresAtMs: nowMs + ALERT_CACHE_TTL_MS,
  };
  return value;
}

export function invalidateAlertLevelCache(): void {
  alertLevelCache = null;
}
