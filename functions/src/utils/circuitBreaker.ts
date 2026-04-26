import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { getRemoteConfig } from "firebase-admin/remote-config";
import { SLACK_WEBHOOK_URL_SECRET } from "../config/secrets";
import {
  AlertLevel,
  DAILY_LIMITS,
  UsageMetrics,
  calculateAlertLevel,
  getUsageSummary,
  invalidateAlertLevelCache,
} from "./usageTracker";

const db = () => getFirestore();
const remoteConfig = () => getRemoteConfig();

const DEFAULT_MAINTENANCE_MESSAGE =
  "Estamos realizando tareas de mantenimiento para proteger la estabilidad del servicio.";

export type MaintenanceMode = "NONE" | "PARTIAL" | "FULL";

interface RemoteConfigState {
  alertLevel: AlertLevel;
  maintenanceMode: MaintenanceMode;
  reason?: string;
  metrics: Partial<UsageMetrics>;
}

interface SlackAlertPayload {
  alertLevel: AlertLevel;
  triggeredBy: string;
  currentValue: number;
  limit: number;
  percentage: number;
  autoAction?: string;
}

interface CircuitBreakerDependencies {
  getUsageSummary: () => Promise<UsageMetrics>;
  publishRemoteConfig: (state: RemoteConfigState) => Promise<void>;
}

const defaultDependencies: CircuitBreakerDependencies = {
  getUsageSummary,
  publishRemoteConfig: updateRemoteConfig,
};

let dependencies: CircuitBreakerDependencies = defaultDependencies;

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function toRemoteConfigValue(value: string | number | boolean): string {
  if (typeof value === "boolean") return value ? "true" : "false";
  return String(value);
}

function emojiForLevel(level: AlertLevel): string {
  switch (level) {
  case "WARNING":
    return "⚠️";
  case "DANGER":
    return "🟠";
  case "CRITICAL":
    return "🔴";
  case "SHUTDOWN":
    return "🛑";
  case "NORMAL":
  default:
    return "✅";
  }
}

export async function updateRemoteConfig(state: RemoteConfigState): Promise<void> {
  const maxAttempts = 3;
  let attempt = 0;
  let lastError: unknown = null;

  while (attempt < maxAttempts) {
    attempt += 1;
    try {
      const rc = remoteConfig();
      const template = await rc.getTemplate();
      const nowIso = new Date().toISOString();
      const shutdownActive = state.alertLevel === "SHUTDOWN" || state.maintenanceMode === "FULL";
      const maintenanceMessage =
        state.reason != null && state.reason.trim().length > 0
          ? `${DEFAULT_MAINTENANCE_MESSAGE} (${state.reason.trim()})`
          : DEFAULT_MAINTENANCE_MESSAGE;

      template.parameters = {
        ...(template.parameters ?? {}),
        maintenance_mode: {
          defaultValue: { value: toRemoteConfigValue(state.maintenanceMode) },
        },
        maintenance_reason: {
          defaultValue: { value: toRemoteConfigValue(state.reason ?? "none") },
        },
        maintenance_message: {
          defaultValue: { value: toRemoteConfigValue(maintenanceMessage) },
        },
        shutdown_active: {
          defaultValue: { value: toRemoteConfigValue(shutdownActive) },
        },
        current_alert_level: {
          defaultValue: { value: toRemoteConfigValue(state.alertLevel) },
        },
        reads_used_today: {
          defaultValue: {
            value: toRemoteConfigValue(state.metrics.firestore_reads ?? 0),
          },
        },
        reads_limit_daily: {
          defaultValue: {
            value: toRemoteConfigValue(DAILY_LIMITS.firestore_reads),
          },
        },
        usage_last_sync_at: {
          defaultValue: { value: toRemoteConfigValue(nowIso) },
        },
      };

      await rc.publishTemplate(template);
      invalidateAlertLevelCache();
      console.log(
        JSON.stringify({
          logType: "usage.guardian.remote_config_updated",
          alertLevel: state.alertLevel,
          maintenanceMode: state.maintenanceMode,
          reason: state.reason ?? "none",
          attempt,
        })
      );
      return;
    } catch (error) {
      lastError = error;
      const backoffMs = 500 * 2 ** (attempt - 1);
      console.error(
        JSON.stringify({
          logType: "usage.guardian.remote_config_update_retry",
          attempt,
          backoffMs,
          error: error instanceof Error ? error.message : String(error),
        })
      );
      if (attempt < maxAttempts) {
        await sleep(backoffMs);
      }
    }
  }

  console.error(
    JSON.stringify({
      logType: "usage.guardian.remote_config_update_failed",
      error: lastError instanceof Error ? lastError.message : String(lastError),
    })
  );
}

export async function sendSlackAlert(data: SlackAlertPayload): Promise<void> {
  const webhookUrl =
    SLACK_WEBHOOK_URL_SECRET.value() || process.env.SLACK_WEBHOOK_URL || "";
  if (
    webhookUrl.trim().length === 0 ||
    !webhookUrl.trim().startsWith("https://hooks.slack.com/")
  ) {
    console.warn(
      JSON.stringify({
        logType: "usage.guardian.slack_skipped_missing_webhook",
        alertLevel: data.alertLevel,
      })
    );
    return;
  }

  const emoji = emojiForLevel(data.alertLevel);
  const dashboardUrl =
    process.env.ADMIN_DASHBOARD_URL ??
    "https://console.firebase.google.com/project/_/firestore/data";
  const mention = data.alertLevel === "SHUTDOWN" ? "<!channel>\n" : "";
  const actionSuffix = data.autoAction ? `\nAuto-action: ${data.autoAction}` : "";

  const text = [
    `${mention}${emoji} *TuM² Free Tier Guardian — ${data.alertLevel}*`,
    `Trigger: \`${data.triggeredBy}\``,
    `Current: ${data.currentValue} / ${data.limit} (${data.percentage.toFixed(2)}%)`,
    `Dashboard: ${dashboardUrl}`,
    actionSuffix,
  ]
    .join("\n")
    .trim();

  try {
    const response = await fetch(webhookUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        text,
        ...(data.alertLevel === "SHUTDOWN"
          ? {
            attachments: [
              {
                color: "#D32F2F",
                text: "Circuit breaker activado automáticamente.",
              },
            ],
          }
          : {}),
      }),
    });
    if (!response.ok) {
      const body = await response.text();
      console.error(
        JSON.stringify({
          logType: "usage.guardian.slack_failed",
          status: response.status,
          body,
        })
      );
    }
  } catch (error) {
    console.error(
      JSON.stringify({
        logType: "usage.guardian.slack_error",
        error: error instanceof Error ? error.message : String(error),
      })
    );
  }
}

export async function activateShutdown(reason: string): Promise<void> {
  const metrics = await dependencies.getUsageSummary();
  await dependencies.publishRemoteConfig({
    alertLevel: "SHUTDOWN",
    maintenanceMode: "FULL",
    reason,
    metrics,
  });
  invalidateAlertLevelCache();
  try {
    await db().collection("_circuit_breaker_events").add({
      event_type: "SHUTDOWN_ACTIVATED",
      reason,
      metrics_snapshot: metrics,
      created_at: FieldValue.serverTimestamp(),
    });
  } catch (error) {
    console.error(
      JSON.stringify({
        logType: "usage.guardian.shutdown_event_write_failed",
        eventType: "SHUTDOWN_ACTIVATED",
        error: error instanceof Error ? error.message : String(error),
      })
    );
  }
  console.error(
    JSON.stringify({
      severity: "EMERGENCY",
      logType: "usage.guardian.shutdown_activated",
      reason,
      metrics,
    })
  );
}

export async function deactivateShutdown(): Promise<void> {
  const metrics = await dependencies.getUsageSummary();
  const currentLevel = calculateAlertLevel(metrics);
  if (currentLevel === "DANGER" || currentLevel === "CRITICAL" || currentLevel === "SHUTDOWN") {
    console.warn(
      JSON.stringify({
        logType: "usage.guardian.shutdown_deactivate_blocked",
        currentLevel,
        metrics,
      })
    );
    return;
  }

  await dependencies.publishRemoteConfig({
    alertLevel: currentLevel,
    maintenanceMode: "NONE",
    reason: "automatic_recovery",
    metrics,
  });
  invalidateAlertLevelCache();
  try {
    await db().collection("_circuit_breaker_events").add({
      event_type: "SHUTDOWN_DEACTIVATED",
      reason: "automatic_recovery",
      metrics_snapshot: metrics,
      created_at: FieldValue.serverTimestamp(),
    });
  } catch (error) {
    console.error(
      JSON.stringify({
        logType: "usage.guardian.shutdown_event_write_failed",
        eventType: "SHUTDOWN_DEACTIVATED",
        error: error instanceof Error ? error.message : String(error),
      })
    );
  }
  console.log(
    JSON.stringify({
      logType: "usage.guardian.shutdown_deactivated",
      currentLevel,
      metrics,
    })
  );
}

export function __setCircuitBreakerDependenciesForTest(
  overrides: Partial<CircuitBreakerDependencies>
): void {
  dependencies = {
    ...dependencies,
    ...overrides,
  };
}

export function __resetCircuitBreakerDependenciesForTest(): void {
  dependencies = defaultDependencies;
}
