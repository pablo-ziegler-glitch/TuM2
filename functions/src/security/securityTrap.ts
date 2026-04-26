import { onRequest } from "firebase-functions/v2/https";

import { detectHoneytoken, HoneytokenType } from "./honeytokens";
import { resolveSecurityHashSecret } from "./hash";
import {
  bodyTextForDetection,
  collectHeaderValues,
  collectQueryValues,
  redactRequestMetadata,
  RedactedRequestMetadata,
  UserAgentFamily,
} from "./redaction";
import {
  classifyTrapPath,
  TrapCategory,
  TrapSeverity,
} from "./trapClassifier";

type RuntimeEnvironment = "dev" | "staging" | "prod" | "unknown";

interface SecurityHoneypotHitLog {
  eventType: "security_honeypot_hit";
  schemaVersion: 1;
  environment: RuntimeEnvironment;
  projectId?: string;
  trapCategory: TrapCategory;
  severity: TrapSeverity;
  riskScore: number;
  method: string;
  path: string;
  normalizedPath: string;
  ipHash: string;
  userAgentHash: string;
  userAgentFamily: UserAgentFamily;
  hasAuthHeader: boolean;
  hasCookieHeader: boolean;
  hasAppCheckHeader: boolean;
  queryKeyCount: number;
  queryKeys: string[];
  bodySizeBytes: number;
  bodyCaptured: false;
  honeytokenDetected: boolean;
  honeytokenType?: HoneytokenType;
  responseStatus: 404;
  timestamp: string;
}

function resolveProjectId(): string | undefined {
  const rawProject = process.env.GCLOUD_PROJECT ?? process.env.GCP_PROJECT;
  if (typeof rawProject === "string" && rawProject.trim().length > 0) {
    return rawProject.trim();
  }

  const firebaseConfig = process.env.FIREBASE_CONFIG;
  if (typeof firebaseConfig === "string" && firebaseConfig.trim().length > 0) {
    try {
      const parsed = JSON.parse(firebaseConfig) as { projectId?: unknown };
      if (typeof parsed.projectId === "string" && parsed.projectId.trim().length > 0) {
        return parsed.projectId.trim();
      }
    } catch {
      return undefined;
    }
  }

  return undefined;
}

function resolveEnvironment(projectId: string | undefined): RuntimeEnvironment {
  if (projectId === "tum2-dev-6283d") return "dev";
  if (projectId === "tum2-staging-45c83") return "staging";
  if (projectId === "tum2-prod-bc9b4") return "prod";
  return "unknown";
}

function trapEnabled(): boolean {
  const raw = process.env.SECURITY_TRAP_ENABLED;
  if (typeof raw !== "string") return true;
  const normalized = raw.trim().toLowerCase();
  if (normalized === "false") return false;
  if (normalized === "0") return false;
  return true;
}

function buildLogPayload(
  metadata: RedactedRequestMetadata,
  input: {
    trapCategory: TrapCategory;
    severity: TrapSeverity;
    riskScore: number;
    honeytokenDetected: boolean;
    honeytokenType?: HoneytokenType;
  }
): SecurityHoneypotHitLog {
  const projectId = resolveProjectId();
  return {
    eventType: "security_honeypot_hit",
    schemaVersion: 1,
    environment: resolveEnvironment(projectId),
    projectId,
    trapCategory: input.trapCategory,
    severity: input.severity,
    riskScore: input.riskScore,
    method: metadata.method,
    path: metadata.path,
    normalizedPath: metadata.normalizedPath,
    ipHash: metadata.ipHash,
    userAgentHash: metadata.userAgentHash,
    userAgentFamily: metadata.userAgentFamily,
    hasAuthHeader: metadata.hasAuthHeader,
    hasCookieHeader: metadata.hasCookieHeader,
    hasAppCheckHeader: metadata.hasAppCheckHeader,
    queryKeyCount: metadata.queryKeyCount,
    queryKeys: metadata.queryKeys,
    bodySizeBytes: metadata.bodySizeBytes,
    bodyCaptured: false,
    honeytokenDetected: input.honeytokenDetected,
    ...(input.honeytokenType ? { honeytokenType: input.honeytokenType } : {}),
    responseStatus: 404,
    timestamp: new Date().toISOString(),
  };
}

function sendNotFound(response: {
  status: (code: number) => { json: (body: unknown) => void };
  set: (name: string, value: string) => void;
}): void {
  response.set("Cache-Control", "no-store");
  response.status(404).json({ error: "not_found" });
}

export const securityTrap = onRequest(
  {
    region: "southamerica-east1",
    timeoutSeconds: 3,
    memory: "256MiB",
    minInstances: 0,
    maxInstances: 5,
  },
  async (request, response) => {
    try {
      if (!trapEnabled()) {
        sendNotFound(response);
        return;
      }

      const secret = resolveSecurityHashSecret();
      const metadata = redactRequestMetadata(request, secret);
      const trap = classifyTrapPath(metadata.normalizedPath);
      const honeytoken = detectHoneytoken({
        normalizedPath: metadata.normalizedPath,
        queryValues: collectQueryValues(request.query as Record<string, unknown>),
        headerValues: collectHeaderValues(request.headers as Record<string, unknown>),
        bodyText: bodyTextForDetection(request.body),
      });

      const severity = honeytoken.honeytokenDetected ? "critical" : trap.severity;
      const riskScore = honeytoken.honeytokenDetected ? 100 : trap.riskScore;
      const payload = buildLogPayload(metadata, {
        trapCategory: trap.trapCategory,
        severity,
        riskScore,
        honeytokenDetected: honeytoken.honeytokenDetected,
        honeytokenType: honeytoken.honeytokenType,
      });
      console.log(JSON.stringify(payload));
    } catch {
      // Fall through to generic 404 response.
    }

    sendNotFound(response);
  }
);
