type FinOpsLevel = "info" | "warning" | "critical";

interface FinOpsEventPayload {
  [key: string]: unknown;
}

interface FinOpsEventInput {
  event: string;
  level?: FinOpsLevel;
  module: string;
  payload?: FinOpsEventPayload;
}

function resolveProjectId(): string {
  const gcloudProject = process.env.GCLOUD_PROJECT ?? process.env.GCP_PROJECT;
  if (typeof gcloudProject === "string" && gcloudProject.trim().length > 0) {
    return gcloudProject.trim();
  }

  const firebaseConfig = process.env.FIREBASE_CONFIG;
  if (typeof firebaseConfig === "string" && firebaseConfig.trim().length > 0) {
    try {
      const parsed = JSON.parse(firebaseConfig) as { projectId?: unknown };
      if (typeof parsed.projectId === "string" && parsed.projectId.trim().length > 0) {
        return parsed.projectId.trim();
      }
    } catch {
      // Ignore parse errors and fall through to unknown.
    }
  }

  return (
    "unknown"
  );
}

export function logFinOpsEvent(input: FinOpsEventInput): void {
  const level = input.level ?? "info";
  const record = {
    logType: "finops.cost.v1",
    event: input.event,
    level,
    module: input.module,
    projectId: resolveProjectId(),
    ts: new Date().toISOString(),
    ...(input.payload ?? {}),
  };
  console.log(JSON.stringify(record));
}
