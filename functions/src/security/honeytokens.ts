export type HoneytokenType =
  | "api_key"
  | "claim_id"
  | "merchant_id"
  | "admin_token"
  | "unknown";

export interface HoneytokenDetectionResult {
  honeytokenDetected: boolean;
  honeytokenType?: HoneytokenType;
}

interface HoneytokenDefinition {
  token: string;
  type: HoneytokenType;
}

const HONEYTOKENS: HoneytokenDefinition[] = [
  { token: "tum2_honey_key_001", type: "api_key" },
  { token: "tum2_fake_admin_export_token", type: "admin_token" },
  { token: "tum2_fake_claim_reveal_token", type: "claim_id" },
  { token: "honey_merchant_do_not_use", type: "merchant_id" },
  { token: "honey_claim_probe", type: "claim_id" },
  { token: "honey_internal_admin_probe", type: "admin_token" },
];

function sanitizeForScan(values: string[]): string[] {
  const sanitized: string[] = [];
  for (const value of values) {
    if (typeof value !== "string") continue;
    const trimmed = value.trim().toLowerCase();
    if (trimmed.length === 0) continue;
    sanitized.push(trimmed);
  }
  return sanitized;
}

export function detectHoneytoken(input: {
  normalizedPath: string;
  queryValues?: string[];
  headerValues?: string[];
  bodyText?: string;
}): HoneytokenDetectionResult {
  const candidates = sanitizeForScan([
    input.normalizedPath,
    ...(input.queryValues ?? []),
    ...(input.headerValues ?? []),
    ...(typeof input.bodyText === "string" ? [input.bodyText] : []),
  ]);

  for (const candidate of candidates) {
    for (const honeypot of HONEYTOKENS) {
      if (candidate.includes(honeypot.token)) {
        return {
          honeytokenDetected: true,
          honeytokenType: honeypot.type,
        };
      }
    }
  }

  return { honeytokenDetected: false };
}
