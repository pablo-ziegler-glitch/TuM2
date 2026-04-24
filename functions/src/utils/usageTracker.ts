import { FieldValue, Timestamp, getFirestore } from "firebase-admin/firestore";

export type AlertLevel =
  | "NORMAL"
  | "WARNING"
  | "DANGER"
  | "CRITICAL"
  | "SHUTDOWN";

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

export interface MonthlyUsageMetrics {
  functions_invocations: number;
  last_updated: Date;
}

export const DAILY_LIMITS = {
  firestore_reads: 25000,
  firestore_writes: 10000,
  firestore_deletes: 10000,
  storage_downloads: 25000,
  storage_uploads: 10000,
  hosting_bandwidth_mb: 180,
} as const;

export const MONTHLY_LIMITS = {
  functions_invocations: 1000000,
} as const;

const ARG_TIME_ZONE = "America/Argentina/Buenos_Aires";
const ALERT_CACHE_TTL_MS = 60_000;
const db = () => getFirestore();

export const INTERNAL_READ = Symbol("INTERNAL_READ");

export interface TrackUsageEvent {
  reads?: number;
  writes?: number;
  deletes?: number;
  storage_downloads?: number;
  storage_uploads?: number;
  hosting_bandwidth_mb?: number;
  function_invocation?: boolean;
  [INTERNAL_READ]?: boolean;
}

interface CachedAlertLevel {
  value: AlertLevel;
  expiresAtMs: number;
}

let cachedAlertLevel: CachedAlertLevel | null = null;

function resolveDateKey(date = new Date()): string {
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: ARG_TIME_ZONE,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(date);
}

function resolveMonthKey(date = new Date()): string {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: ARG_TIME_ZONE,
    year: "numeric",
    month: "2-digit",
  })
    .formatToParts(date)
    .reduce<Record<string, string>>((acc, part) => {
      if (part.type !== "literal") acc[part.type] = part.value;
      return acc;
    }, {});
  return `${parts.year}-${parts.month}`;
}

function asDate(raw: unknown): Date {
  if (raw instanceof Timestamp) return raw.toDate();
  if (raw instanceof Date) return raw;
  return new Date();
}

function asNumber(raw: unknown): number {
  return typeof raw === "number" && Number.isFinite(raw) ? raw : 0;
}

function levelWeight(level: AlertLevel): number {
  switch (level) {
  case "NORMAL":
    return 0;
  case "WARNING":
    return 1;
  case "DANGER":
    return 2;
  case "CRITICAL":
    return 3;
  case "SHUTDOWN":
    return 4;
  default:
    return 0;
  }
}

function levelForDailyPercentage(percentage: number): AlertLevel {
  if (percentage >= 95) return "SHUTDOWN";
  if (percentage >= 90) return "CRITICAL";
  if (percentage >= 75) return "DANGER";
  if (percentage >= 50) return "WARNING";
  return "NORMAL";
}

function levelForMonthlyPercentage(percentage: number): AlertLevel {
  if (percentage >= 90) return "SHUTDOWN";
  if (percentage >= 75) return "DANGER";
  if (percentage >= 50) return "WARNING";
  return "NORMAL";
}

export function calculateAlertLevel(metrics: Partial<UsageMetrics>): AlertLevel {
  let highest: AlertLevel = "NORMAL";

  const dailyKeys = Object.keys(DAILY_LIMITS) as Array<keyof typeof DAILY_LIMITS>;
  for (const key of dailyKeys) {
    const current = asNumber(metrics[key]);
    const limit = DAILY_LIMITS[key];
    const percentage = limit > 0 ? (current / limit) * 100 : 0;
    const candidate = levelForDailyPercentage(percentage);
    if (levelWeight(candidate) > levelWeight(highest)) {
      highest = candidate;
    }
  }

  const monthlyKeys = Object.keys(MONTHLY_LIMITS) as Array<keyof typeof MONTHLY_LIMITS>;
  for (const key of monthlyKeys) {
    const current = asNumber(metrics[key]);
    const limit = MONTHLY_LIMITS[key];
    const percentage = limit > 0 ? (current / limit) * 100 : 0;
    const candidate = levelForMonthlyPercentage(percentage);
    if (levelWeight(candidate) > levelWeight(highest)) {
      highest = candidate;
    }
  }

  return highest;
}

export function calculateUsagePercentages(
  metrics: Pick<
    UsageMetrics,
    | "firestore_reads"
    | "firestore_writes"
    | "firestore_deletes"
    | "storage_downloads"
    | "storage_uploads"
    | "hosting_bandwidth_mb"
    | "functions_invocations"
  >
): Record<string, number> {
  return {
    firestore_reads: (metrics.firestore_reads / DAILY_LIMITS.firestore_reads) * 100,
    firestore_writes: (metrics.firestore_writes / DAILY_LIMITS.firestore_writes) * 100,
    firestore_deletes: (metrics.firestore_deletes / DAILY_LIMITS.firestore_deletes) * 100,
    storage_downloads: (metrics.storage_downloads / DAILY_LIMITS.storage_downloads) * 100,
    storage_uploads: (metrics.storage_uploads / DAILY_LIMITS.storage_uploads) * 100,
    hosting_bandwidth_mb: (metrics.hosting_bandwidth_mb / DAILY_LIMITS.hosting_bandwidth_mb) * 100,
    functions_invocations:
      (metrics.functions_invocations / MONTHLY_LIMITS.functions_invocations) * 100,
  };
}

export async function ensureUsageCounterDocs(now = new Date()): Promise<void> {
  const dateKey = resolveDateKey(now);
  const monthKey = resolveMonthKey(now);
  const dayRef = db().doc(`_usage_counters/${dateKey}`);
  const monthRef = db().doc(`_usage_monthly/${monthKey}`);

  try {
    await Promise.all([
      dayRef.set(
        {
          firestore_reads: 0,
          firestore_writes: 0,
          firestore_deletes: 0,
          functions_invocations: 0,
          storage_downloads: 0,
          storage_uploads: 0,
          hosting_bandwidth_mb: 0,
          alert_level: "NORMAL",
          last_updated: FieldValue.serverTimestamp(),
        },
        { merge: true }
      ),
      monthRef.set(
        {
          functions_invocations: 0,
          last_updated: FieldValue.serverTimestamp(),
        },
        { merge: true }
      ),
    ]);
  } catch (error) {
    console.error(
      JSON.stringify({
        logType: "usage.guardian.ensure_docs_failed",
        error: error instanceof Error ? error.message : String(error),
        dateKey,
        monthKey,
      })
    );
  }
}

export async function trackUsage(event: TrackUsageEvent): Promise<void> {
  if (event[INTERNAL_READ] === true) {
    return;
  }

  const dateKey = resolveDateKey();
  const monthKey = resolveMonthKey();
  const counterRef = db().doc(`_usage_counters/${dateKey}`);
  const monthlyRef = db().doc(`_usage_monthly/${monthKey}`);

  const counterUpdate: Record<string, unknown> = {
    last_updated: FieldValue.serverTimestamp(),
  };
  const monthlyUpdate: Record<string, unknown> = {
    last_updated: FieldValue.serverTimestamp(),
  };

  const reads = asNumber(event.reads);
  const writes = asNumber(event.writes);
  const deletes = asNumber(event.deletes);
  const storageDownloads = asNumber(event.storage_downloads);
  const storageUploads = asNumber(event.storage_uploads);
  const hostingBandwidthMb = asNumber(event.hosting_bandwidth_mb);

  if (reads > 0) counterUpdate.firestore_reads = FieldValue.increment(reads);
  if (writes > 0) counterUpdate.firestore_writes = FieldValue.increment(writes);
  if (deletes > 0) counterUpdate.firestore_deletes = FieldValue.increment(deletes);
  if (storageDownloads > 0) {
    counterUpdate.storage_downloads = FieldValue.increment(storageDownloads);
  }
  if (storageUploads > 0) {
    counterUpdate.storage_uploads = FieldValue.increment(storageUploads);
  }
  if (hostingBandwidthMb > 0) {
    counterUpdate.hosting_bandwidth_mb = FieldValue.increment(hostingBandwidthMb);
  }
  if (event.function_invocation === true) {
    counterUpdate.functions_invocations = FieldValue.increment(1);
    monthlyUpdate.functions_invocations = FieldValue.increment(1);
  }

  try {
    await Promise.all([
      counterRef.set(counterUpdate, { merge: true }),
      event.function_invocation === true
        ? monthlyRef.set(monthlyUpdate, { merge: true })
        : Promise.resolve(),
    ]);
  } catch (error) {
    console.error(
      JSON.stringify({
        logType: "usage.guardian.track_usage_failed",
        error: error instanceof Error ? error.message : String(error),
        event,
        dateKey,
        monthKey,
      })
    );
  }
}

export async function getUsageSummary(): Promise<UsageMetrics> {
  const dateKey = resolveDateKey();
  const monthKey = resolveMonthKey();
  const counterRef = db().doc(`_usage_counters/${dateKey}`);
  const monthlyRef = db().doc(`_usage_monthly/${monthKey}`);

  const [daySnap, monthSnap] = await Promise.all([counterRef.get(), monthlyRef.get()]);

  const dayData = daySnap.exists ? daySnap.data() : {};
  const monthData = monthSnap.exists ? monthSnap.data() : {};
  const lastUpdated = asDate(dayData?.["last_updated"] ?? monthData?.["last_updated"]);

  const metrics: UsageMetrics = {
    firestore_reads: asNumber(dayData?.["firestore_reads"]),
    firestore_writes: asNumber(dayData?.["firestore_writes"]),
    firestore_deletes: asNumber(dayData?.["firestore_deletes"]),
    functions_invocations: asNumber(monthData?.["functions_invocations"]),
    storage_downloads: asNumber(dayData?.["storage_downloads"]),
    storage_uploads: asNumber(dayData?.["storage_uploads"]),
    hosting_bandwidth_mb: asNumber(dayData?.["hosting_bandwidth_mb"]),
    alert_level: "NORMAL",
    last_updated: lastUpdated,
  };
  metrics.alert_level = calculateAlertLevel(metrics);
  return metrics;
}

export async function getCurrentAlertLevel(): Promise<AlertLevel> {
  const nowMs = Date.now();
  if (cachedAlertLevel && cachedAlertLevel.expiresAtMs > nowMs) {
    return cachedAlertLevel.value;
  }

  try {
    const dateKey = resolveDateKey();
    const monthKey = resolveMonthKey();
    const [daySnap, monthSnap] = await Promise.all([
      db().doc(`_usage_counters/${dateKey}`).get(),
      db().doc(`_usage_monthly/${monthKey}`).get(),
    ]);
    const dayData = daySnap.exists ? daySnap.data() : {};
    const monthData = monthSnap.exists ? monthSnap.data() : {};
    const metrics: UsageMetrics = {
      firestore_reads: asNumber(dayData?.["firestore_reads"]),
      firestore_writes: asNumber(dayData?.["firestore_writes"]),
      firestore_deletes: asNumber(dayData?.["firestore_deletes"]),
      functions_invocations: asNumber(monthData?.["functions_invocations"]),
      storage_downloads: asNumber(dayData?.["storage_downloads"]),
      storage_uploads: asNumber(dayData?.["storage_uploads"]),
      hosting_bandwidth_mb: asNumber(dayData?.["hosting_bandwidth_mb"]),
      alert_level: "NORMAL",
      last_updated: asDate(dayData?.["last_updated"] ?? monthData?.["last_updated"]),
    };
    const alertLevel = calculateAlertLevel(metrics);
    cachedAlertLevel = {
      value: alertLevel,
      expiresAtMs: nowMs + ALERT_CACHE_TTL_MS,
    };
    return alertLevel;
  } catch (error) {
    console.error(
      JSON.stringify({
        logType: "usage.guardian.get_alert_level_failed",
        error: error instanceof Error ? error.message : String(error),
      })
    );
    cachedAlertLevel = {
      value: "NORMAL",
      expiresAtMs: nowMs + ALERT_CACHE_TTL_MS,
    };
    return "NORMAL";
  }
}

export function invalidateAlertLevelCache(): void {
  cachedAlertLevel = null;
}

export function getArgDateKeyForTesting(date: Date): string {
  return resolveDateKey(date);
}
