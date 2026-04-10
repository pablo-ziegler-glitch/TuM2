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
  return (
    process.env.GCLOUD_PROJECT ||
    process.env.GCP_PROJECT ||
    process.env.FIREBASE_CONFIG ||
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
