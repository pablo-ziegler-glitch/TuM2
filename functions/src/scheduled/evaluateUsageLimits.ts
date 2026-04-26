import { onSchedule } from "firebase-functions/v2/scheduler";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { getRemoteConfig } from "firebase-admin/remote-config";
import {
  AlertLevel,
  MONTHLY_LIMITS,
  DAILY_LIMITS,
  calculateAlertLevel,
  calculateUsagePercentages,
  ensureUsageCounterDocs,
  getArgDateKeyForTesting,
  getUsageSummary,
} from "../utils/usageTracker";
import {
  activateShutdown,
  deactivateShutdown,
  sendSlackAlert,
  updateRemoteConfig,
} from "../utils/circuitBreaker";
import { SLACK_WEBHOOK_URL_SECRET } from "../config/secrets";

const db = () => getFirestore();

const DAILY_KEYS = [
  "firestore_reads",
  "firestore_writes",
  "firestore_deletes",
  "storage_downloads",
  "storage_uploads",
  "hosting_bandwidth_mb",
] as const;

const MONTHLY_KEYS = ["functions_invocations"] as const;

type UsageMetricKey = (typeof DAILY_KEYS)[number] | (typeof MONTHLY_KEYS)[number];

interface EvaluateDependencies {
  now: () => Date;
  ensureUsageCounterDocs: () => Promise<void>;
  getUsageSummary: typeof getUsageSummary;
  updateRemoteConfig: typeof updateRemoteConfig;
  sendSlackAlert: typeof sendSlackAlert;
  activateShutdown: typeof activateShutdown;
  deactivateShutdown: typeof deactivateShutdown;
  getRemoteCurrentAlertLevel: () => Promise<AlertLevel>;
  markCycleAsProcessed: (cycleKey: string) => Promise<boolean>;
  loadState: () => Promise<Record<string, unknown>>;
  saveState: (data: Record<string, unknown>) => Promise<void>;
  saveDailyAlert: (dateKey: string, alertLevel: AlertLevel) => Promise<void>;
  appendHistory: (data: Record<string, unknown>) => Promise<void>;
  registerShutdown: (dateKey: string, data: Record<string, unknown>) => Promise<void>;
}

const defaultDependencies: EvaluateDependencies = {
  now: () => new Date(),
  ensureUsageCounterDocs: async () => ensureUsageCounterDocs(),
  getUsageSummary,
  updateRemoteConfig,
  sendSlackAlert,
  activateShutdown,
  deactivateShutdown,
  getRemoteCurrentAlertLevel: async () => {
    try {
      const template = await getRemoteConfig().getTemplate();
      const raw = template.parameters?.["current_alert_level"]?.defaultValue;
      const level =
        raw && "value" in raw && typeof raw.value === "string" ? raw.value : "NORMAL";
      if (
        level === "NORMAL" ||
        level === "WARNING" ||
        level === "DANGER" ||
        level === "CRITICAL" ||
        level === "SHUTDOWN"
      ) {
        return level;
      }
    } catch (error) {
      console.error(
        JSON.stringify({
          logType: "usage.guardian.remote_level_read_failed",
          error: error instanceof Error ? error.message : String(error),
        })
      );
    }
    return "NORMAL";
  },
  markCycleAsProcessed,
  loadState: async () => {
    const snap = await db().doc("_usage_guardian_state/current").get();
    return snap.exists ? (snap.data() ?? {}) : {};
  },
  saveState: async (data) => {
    await db().doc("_usage_guardian_state/current").set(data, { merge: true });
  },
  saveDailyAlert: async (dateKey, alertLevel) => {
    await db().doc(`_usage_counters/${dateKey}`).set(
      {
        alert_level: alertLevel,
        last_updated: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  },
  appendHistory: async (data) => {
    await db().collection("_usage_alert_history").add(data);
  },
  registerShutdown: async (dateKey, data) => {
    await db().collection(`_usage_counters/${dateKey}/shutdowns`).add(data);
  },
};

function resolveArgDateTimeParts(date: Date): {
  year: number;
  month: number;
  day: number;
  hour: number;
  minute: number;
} {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: "America/Argentina/Buenos_Aires",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  })
    .formatToParts(date)
    .reduce<Record<string, number>>((acc, part) => {
      if (part.type !== "literal") acc[part.type] = Number(part.value);
      return acc;
    }, {});
  return {
    year: parts.year,
    month: parts.month,
    day: parts.day,
    hour: parts.hour === 24 ? 0 : parts.hour,
    minute: parts.minute,
  };
}

function resolveCycleKey(date: Date): string {
  const p = resolveArgDateTimeParts(date);
  const halfHour = p.minute < 30 ? "00" : "30";
  return `${p.year}-${String(p.month).padStart(2, "0")}-${String(p.day).padStart(2, "0")}_${String(p.hour).padStart(2, "0")}:${halfHour}`;
}

function resolveTopMetric(
  percentages: Record<string, number>,
  summary: ReturnType<typeof getUsageSummary> extends Promise<infer T> ? T : never
): { key: UsageMetricKey; percentage: number; currentValue: number; limit: number; cadence: "daily" | "monthly" } {
  let top: { key: UsageMetricKey; percentage: number; currentValue: number; limit: number; cadence: "daily" | "monthly" } = {
    key: "firestore_reads",
    percentage: -1,
    currentValue: 0,
    limit: DAILY_LIMITS.firestore_reads,
    cadence: "daily",
  };

  for (const key of DAILY_KEYS) {
    const percentage = percentages[key] ?? 0;
    if (percentage > top.percentage) {
      top = {
        key,
        percentage,
        currentValue: Number(summary[key] ?? 0),
        limit: DAILY_LIMITS[key],
        cadence: "daily",
      };
    }
  }

  for (const key of MONTHLY_KEYS) {
    const percentage = percentages[key] ?? 0;
    if (percentage > top.percentage) {
      top = {
        key,
        percentage,
        currentValue: Number(summary[key] ?? 0),
        limit: MONTHLY_LIMITS[key],
        cadence: "monthly",
      };
    }
  }

  return top;
}

function maintenanceModeFromLevel(level: AlertLevel): "NONE" | "PARTIAL" | "FULL" {
  if (level === "SHUTDOWN") return "FULL";
  if (level === "DANGER" || level === "CRITICAL") return "PARTIAL";
  return "NONE";
}

async function markCycleAsProcessed(cycleKey: string): Promise<boolean> {
  const ref = db().doc(`_usage_evaluations/${cycleKey}`);
  let alreadyProcessed = false;
  await db().runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (snap.exists) {
      alreadyProcessed = true;
      return;
    }
    tx.set(ref, {
      cycle_key: cycleKey,
      processed_at: FieldValue.serverTimestamp(),
    });
  });
  return !alreadyProcessed;
}

export async function runEvaluateUsageLimits(
  deps: EvaluateDependencies = defaultDependencies
): Promise<{
  skipped: boolean;
  cycleKey: string;
  alertLevel: AlertLevel;
}> {
  await deps.ensureUsageCounterDocs();
  const now = deps.now();
  const cycleKey = resolveCycleKey(now);
  const canProcessCycle = await deps.markCycleAsProcessed(cycleKey);
  if (!canProcessCycle) {
    console.log(
      JSON.stringify({
        logType: "usage.guardian.evaluate_skipped_duplicate_cycle",
        cycleKey,
      })
    );
    return { skipped: true, cycleKey, alertLevel: "NORMAL" };
  }

  const summary = await deps.getUsageSummary();
  const percentages = calculateUsagePercentages(summary);
  const alertLevel = calculateAlertLevel(summary);
  const topMetric = resolveTopMetric(percentages, summary);
  const triggeredBy = `${topMetric.key}_at_${topMetric.percentage.toFixed(2)}pct_${topMetric.cadence}`;
  const reason = `${topMetric.key}_${Math.floor(topMetric.percentage)}pct_${topMetric.cadence}`;

  const stateData = await deps.loadState();
  const previousAlertFromState = stateData?.["alert_level"];
  const previousAlert =
    previousAlertFromState === "NORMAL" ||
    previousAlertFromState === "WARNING" ||
    previousAlertFromState === "DANGER" ||
    previousAlertFromState === "CRITICAL" ||
    previousAlertFromState === "SHUTDOWN"
      ? (previousAlertFromState as AlertLevel)
      : await deps.getRemoteCurrentAlertLevel();

  const shouldNotify =
    alertLevel !== previousAlert ||
    alertLevel === "DANGER" ||
    alertLevel === "CRITICAL" ||
    alertLevel === "SHUTDOWN";

  const dateKey = getArgDateKeyForTesting(now);
  await deps.saveDailyAlert(dateKey, alertLevel);

  if (alertLevel === "SHUTDOWN") {
    await deps.activateShutdown(reason);
    await deps.registerShutdown(dateKey, {
      reason,
      triggered_by: triggeredBy,
      metric_percentage: topMetric.percentage,
      created_at: FieldValue.serverTimestamp(),
      cycle_key: cycleKey,
    });
    await deps.sendSlackAlert({
      alertLevel,
      triggeredBy,
      currentValue: topMetric.currentValue,
      limit: topMetric.limit,
      percentage: topMetric.percentage,
      autoAction: "maintenance_mode=FULL + shutdown_active=true",
    });
  } else if (shouldNotify) {
    await deps.updateRemoteConfig({
      alertLevel,
      maintenanceMode: maintenanceModeFromLevel(alertLevel),
      reason,
      metrics: summary,
    });
    await deps.sendSlackAlert({
      alertLevel,
      triggeredBy,
      currentValue: topMetric.currentValue,
      limit: topMetric.limit,
      percentage: topMetric.percentage,
      autoAction:
        alertLevel === "DANGER" || alertLevel === "CRITICAL"
          ? "maintenance_mode=PARTIAL"
          : undefined,
    });
  }

  await deps.saveState(
    {
      alert_level: alertLevel,
      previous_alert_level: previousAlert,
      last_cycle_key: cycleKey,
      last_reason: reason,
      last_triggered_by: triggeredBy,
      last_evaluated_at: FieldValue.serverTimestamp(),
      shutdown_reason: alertLevel === "SHUTDOWN" ? reason : stateData?.["shutdown_reason"] ?? "",
    }
  );

  if (shouldNotify) {
    await deps.appendHistory({
      cycle_key: cycleKey,
      alert_level: alertLevel,
      previous_alert_level: previousAlert,
      reason,
      triggered_by: triggeredBy,
      percentage: topMetric.percentage,
      created_at: FieldValue.serverTimestamp(),
    });
  }

  const parts = resolveArgDateTimeParts(now);
  const isFirstCycleOfDay = parts.hour === 0 && parts.minute < 30;
  const lastShutdownReason =
    typeof stateData?.["shutdown_reason"] === "string" ? stateData["shutdown_reason"] : "";
  const shutdownWasDaily = lastShutdownReason.includes("_daily");
  const monthlyRatio =
    summary.functions_invocations / MONTHLY_LIMITS.functions_invocations;
  const monthlyHealthy = monthlyRatio < 0.9;

  if (isFirstCycleOfDay && shutdownWasDaily && monthlyHealthy && alertLevel !== "SHUTDOWN") {
    await deps.deactivateShutdown();
    await deps.sendSlackAlert({
      alertLevel: "NORMAL",
      triggeredBy: "automatic_daily_reset",
      currentValue: summary.firestore_reads,
      limit: DAILY_LIMITS.firestore_reads,
      percentage: (summary.firestore_reads / DAILY_LIMITS.firestore_reads) * 100,
      autoAction: "maintenance_mode=NONE + shutdown_active=false",
    });
    console.log(
      JSON.stringify({
        logType: "usage.guardian.daily_auto_recovery",
        cycleKey,
        dateKey,
      })
    );
  }

  if (alertLevel === "SHUTDOWN") {
    console.error(
      JSON.stringify({
        severity: "ERROR",
        logType: "usage.guardian.shutdown_state_active",
        cycleKey,
        reason,
      })
    );
  }

  return { skipped: false, cycleKey, alertLevel };
}

export const evaluateUsageLimits = onSchedule(
  {
    schedule: "*/30 * * * *",
    timeZone: "America/Argentina/Buenos_Aires",
    maxInstances: 1,
    timeoutSeconds: 60,
    memory: "256MiB",
    secrets: [SLACK_WEBHOOK_URL_SECRET],
  },
  async () => {
    await runEvaluateUsageLimits();
  }
);
