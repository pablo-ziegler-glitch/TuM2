import { CallableRequest, HttpsError } from "firebase-functions/v2/https";
import { getRemoteConfig } from "firebase-admin/remote-config";
import { AlertLevel, getCurrentAlertLevel, trackUsage } from "../utils/usageTracker";

interface UsageGuardOptions {
  skipTrackingForAdmins?: boolean;
  allowDuringShutdown?: boolean;
}

interface UsageGuardDependencies {
  getCurrentAlertLevel: () => Promise<AlertLevel>;
  trackUsage: (event: { function_invocation?: boolean }) => Promise<void>;
}

const defaultDependencies: UsageGuardDependencies = {
  getCurrentAlertLevel,
  trackUsage,
};

let dependencies: UsageGuardDependencies = defaultDependencies;
const REMOTE_CONFIG_CACHE_TTL_MS = 60_000;
let remoteAlertCache: { value: AlertLevel; expiresAtMs: number } | null = null;

function asAlertLevel(raw: string): AlertLevel {
  if (
    raw === "NORMAL" ||
    raw === "WARNING" ||
    raw === "DANGER" ||
    raw === "CRITICAL" ||
    raw === "SHUTDOWN"
  ) {
    return raw;
  }
  return "NORMAL";
}

async function getAlertLevelFromRemoteConfig(): Promise<AlertLevel | null> {
  const nowMs = Date.now();
  if (remoteAlertCache && remoteAlertCache.expiresAtMs > nowMs) {
    return remoteAlertCache.value;
  }

  try {
    const template = await getRemoteConfig().getTemplate();
    const rawValue = template.parameters?.["current_alert_level"]?.defaultValue;
    const value = asAlertLevel(
      typeof rawValue === "object" &&
        rawValue !== null &&
        "value" in rawValue &&
        typeof rawValue.value === "string"
        ? rawValue.value
        : "NORMAL"
    );
    remoteAlertCache = {
      value,
      expiresAtMs: nowMs + REMOTE_CONFIG_CACHE_TTL_MS,
    };
    return value;
  } catch (error) {
    console.error(
      JSON.stringify({
        logType: "usage.guardian.middleware_remote_config_read_failed",
        error: error instanceof Error ? error.message : String(error),
      })
    );
    return null;
  }
}

function isAdminRequest(request: CallableRequest<unknown>): boolean {
  if (!request.auth) return false;
  if (request.auth.token.admin === true) return true;
  const roleClaim = request.auth.token.role;
  if (typeof roleClaim !== "string") return false;
  const normalized = roleClaim.trim().toLowerCase();
  return normalized === "admin" || normalized === "super_admin";
}

export function withUsageGuard<T>(
  handler: (request: CallableRequest) => Promise<T>,
  options?: UsageGuardOptions
): (request: CallableRequest) => Promise<T> {
  return async (request: CallableRequest): Promise<T> => {
    let alertLevel: AlertLevel = "NORMAL";
    try {
      const remoteLevel = await getAlertLevelFromRemoteConfig();
      if (remoteLevel) {
        alertLevel = remoteLevel;
      } else {
        alertLevel = await dependencies.getCurrentAlertLevel();
      }
    } catch (error) {
      console.error(
        JSON.stringify({
          logType: "usage.guardian.middleware_alert_fetch_failed",
          error: error instanceof Error ? error.message : String(error),
        })
      );
    }
    const adminRequest = isAdminRequest(request);

    if (alertLevel === "SHUTDOWN" && options?.allowDuringShutdown !== true) {
      throw new HttpsError(
        "unavailable",
        "Servicio temporalmente no disponible. Por favor intentá más tarde."
      );
    }

    if (alertLevel === "CRITICAL" && !adminRequest) {
      throw new HttpsError("unavailable", "Servicio en modo de capacidad reducida.");
    }

    try {
      return await handler(request);
    } finally {
      if (!(options?.skipTrackingForAdmins === true && adminRequest)) {
        try {
          await dependencies.trackUsage({ function_invocation: true });
        } catch (error) {
          console.error(
            JSON.stringify({
              logType: "usage.guardian.middleware_tracking_failed",
              error: error instanceof Error ? error.message : String(error),
            })
          );
        }
      }
    }
  };
}

export function __setUsageGuardDependenciesForTest(
  overrides: Partial<UsageGuardDependencies>
): void {
  dependencies = {
    ...dependencies,
    ...overrides,
  };
}

export function __resetUsageGuardDependenciesForTest(): void {
  dependencies = defaultDependencies;
  remoteAlertCache = null;
}
