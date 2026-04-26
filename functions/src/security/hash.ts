import { createHmac } from "node:crypto";

const LOCAL_DEV_FALLBACK_SECRET = "local-dev-only-security-hash-secret";

function normalizeSecret(raw: string | undefined): string {
  if (typeof raw !== "string") return "";
  return raw.trim();
}

function isEmulatorRuntime(): boolean {
  return process.env.FUNCTIONS_EMULATOR === "true";
}

export function resolveSecurityHashSecret(): string {
  const explicit = normalizeSecret(process.env.SECURITY_HASH_SECRET);
  if (explicit.length > 0) return explicit;
  if (isEmulatorRuntime()) return LOCAL_DEV_FALLBACK_SECRET;
  throw new Error(
    "SECURITY_HASH_SECRET es obligatorio fuera del emulador para securityTrap."
  );
}

function normalizeValue(value: string | undefined): string {
  if (typeof value !== "string") return "unknown";
  const normalized = value.trim();
  return normalized.length > 0 ? normalized : "unknown";
}

export function hmacSha256(value: string, secret: string): string {
  return createHmac("sha256", secret).update(value, "utf8").digest("hex");
}

export function hashIp(rawIp: string | undefined, secret: string): string {
  return hmacSha256(normalizeValue(rawIp), secret);
}

export function hashUserAgent(rawUserAgent: string | undefined, secret: string): string {
  return hmacSha256(normalizeValue(rawUserAgent), secret);
}
