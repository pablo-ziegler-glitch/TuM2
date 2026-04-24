import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { initializeApp } from "firebase-admin/app";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { getRemoteConfig } from "firebase-admin/remote-config";

type MaintenanceMode = "NONE" | "PARTIAL" | "FULL";
type AlertLevel = "NORMAL" | "WARNING" | "DANGER" | "CRITICAL" | "SHUTDOWN";

const ARG_TIME_ZONE = "America/Argentina/Buenos_Aires";

const DAILY_LIMITS = {
  firestore_reads: 25000,
  firestore_writes: 10000,
  firestore_deletes: 10000,
  storage_downloads: 25000,
  storage_uploads: 10000,
  hosting_bandwidth_mb: 180,
} as const;

const MONTHLY_LIMITS = {
  functions_invocations: 1000000,
} as const;

function resolveArgDateKey(date = new Date()): string {
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: ARG_TIME_ZONE,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(date);
}

function resolveArgMonthKey(date = new Date()): string {
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

async function assertRulesGuardingUsageCollections(): Promise<boolean> {
  const rulesPath = resolve(process.cwd(), "firestore.rules");
  const rules = await readFile(rulesPath, "utf8");
  const guards = [
    /match\s+\/_usage_counters\/\{document=\*\*\}\s*\{\s*allow\s+read,\s*write:\s*if\s+false;\s*\}/s,
    /match\s+\/_usage_monthly\/\{document=\*\*\}\s*\{\s*allow\s+read,\s*write:\s*if\s+false;\s*\}/s,
    /match\s+\/_circuit_breaker_events\/\{document=\*\*\}\s*\{\s*allow\s+read,\s*write:\s*if\s+false;\s*\}/s,
  ];
  return guards.every((guard) => guard.test(rules));
}

async function initializeRemoteConfigDefaults(): Promise<{
  maintenance_mode: MaintenanceMode;
  current_alert_level: AlertLevel;
}> {
  const rc = getRemoteConfig();
  const template = await rc.getTemplate();

  template.parameters = {
    ...(template.parameters ?? {}),
    maintenance_mode: { defaultValue: { value: "NONE" } },
    maintenance_reason: { defaultValue: { value: "none" } },
    maintenance_message: {
      defaultValue: {
        value: "Estamos realizando tareas de mantenimiento para proteger la estabilidad del servicio.",
      },
    },
    shutdown_active: { defaultValue: { value: "false" } },
    current_alert_level: { defaultValue: { value: "NORMAL" } },
    reads_used_today: { defaultValue: { value: "0" } },
    reads_limit_daily: { defaultValue: { value: String(DAILY_LIMITS.firestore_reads) } },
    usage_last_sync_at: { defaultValue: { value: new Date().toISOString() } },
  };

  await rc.publishTemplate(template);
  return {
    maintenance_mode: "NONE",
    current_alert_level: "NORMAL",
  };
}

async function main(): Promise<void> {
  initializeApp();
  const db = getFirestore();
  const dateKey = resolveArgDateKey();
  const monthKey = resolveArgMonthKey();

  await db.doc(`_usage_counters/${dateKey}`).set(
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
      initialized_at: FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  await db.doc(`_usage_monthly/${monthKey}`).set(
    {
      functions_invocations: 0,
      last_updated: FieldValue.serverTimestamp(),
      initialized_at: FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  const remoteConfig = await initializeRemoteConfigDefaults();
  const rulesGuarded = await assertRulesGuardingUsageCollections();

  const summary = {
    initializedAt: new Date().toISOString(),
    dateKey,
    monthKey,
    limits: {
      daily: DAILY_LIMITS,
      monthly: MONTHLY_LIMITS,
    },
    remoteConfig,
    rulesGuarded,
  };

  console.log(JSON.stringify(summary, null, 2));

  if (!rulesGuarded) {
    throw new Error(
      "firestore.rules no contiene el bloqueo esperado para _usage_counters/_usage_monthly/_circuit_breaker_events."
    );
  }
}

main().catch((error) => {
  console.error(
    JSON.stringify({
      logType: "usage.guardian.init_failed",
      error: error instanceof Error ? error.message : String(error),
    })
  );
  process.exitCode = 1;
});
