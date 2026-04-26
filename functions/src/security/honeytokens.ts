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

function tokenFromParts(parts: string[]): string {
  return parts.join("");
}

const HONEYTOKENS: HoneytokenDefinition[] = [
  {
    token: tokenFromParts(["tum2_", "honey_", "key_", "001"]),
    type: "api_key",
  },
  {
    token: tokenFromParts(["tum2_", "fake_", "admin_", "export_", "token"]),
    type: "admin_token",
  },
  {
    token: tokenFromParts(["tum2_", "fake_", "claim_", "reveal_", "token"]),
    type: "claim_id",
  },
  {
    token: tokenFromParts(["honey_", "merchant_", "do_", "not_", "use"]),
    type: "merchant_id",
  },
  {
    token: tokenFromParts(["honey_", "claim_", "probe"]),
    type: "claim_id",
  },
  {
    token: tokenFromParts(["honey_", "internal_", "admin_", "probe"]),
    type: "admin_token",
  },
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
