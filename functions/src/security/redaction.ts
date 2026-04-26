import { hashIp, hashUserAgent } from "./hash";
import { normalizeTrapPath } from "./trapClassifier";

export type UserAgentFamily = "browser" | "curl" | "python" | "bot" | "unknown";

export interface RedactedRequestMetadata {
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
}

interface RequestLike {
  method?: unknown;
  path?: unknown;
  originalUrl?: unknown;
  url?: unknown;
  ip?: unknown;
  headers?: Record<string, unknown>;
  query?: Record<string, unknown>;
  body?: unknown;
  socket?: { remoteAddress?: unknown };
  connection?: { remoteAddress?: unknown };
}

function headerValue(headers: Record<string, unknown> | undefined, key: string): string {
  if (!headers) return "";
  const direct = headers[key] ?? headers[key.toLowerCase()] ?? headers[key.toUpperCase()];
  if (direct == null) {
    const match = Object.entries(headers).find(
      ([headerName]) => headerName.toLowerCase() === key.toLowerCase()
    );
    if (match) {
      const [, value] = match;
      if (typeof value === "string") return value;
      if (Array.isArray(value)) {
        const first = value.find((item) => typeof item === "string");
        return typeof first === "string" ? first : "";
      }
    }
    return "";
  }
  if (typeof direct === "string") return direct;
  if (Array.isArray(direct)) {
    const first = direct.find((item) => typeof item === "string");
    return typeof first === "string" ? first : "";
  }
  return "";
}

function extractIp(request: RequestLike): string | undefined {
  const headers = request.headers;
  const forwardedFor = headerValue(headers, "x-forwarded-for");
  if (forwardedFor) {
    const first = forwardedFor.split(",")[0]?.trim();
    if (first) return first;
  }
  if (typeof request.ip === "string" && request.ip.trim().length > 0) {
    return request.ip.trim();
  }
  if (
    typeof request.socket?.remoteAddress === "string" &&
    request.socket.remoteAddress.trim().length > 0
  ) {
    return request.socket.remoteAddress.trim();
  }
  if (
    typeof request.connection?.remoteAddress === "string" &&
    request.connection.remoteAddress.trim().length > 0
  ) {
    return request.connection.remoteAddress.trim();
  }
  return undefined;
}

function normalizePathInput(path: string): string {
  return path.split("?")[0].split("#")[0].trim() || "/";
}

function extractPath(request: RequestLike): string {
  if (typeof request.path === "string" && request.path.trim().length > 0) {
    return normalizePathInput(request.path);
  }
  if (typeof request.originalUrl === "string" && request.originalUrl.trim().length > 0) {
    return normalizePathInput(request.originalUrl);
  }
  if (typeof request.url === "string" && request.url.trim().length > 0) {
    return normalizePathInput(request.url);
  }
  return "/";
}

function toBodySizeBytes(body: unknown): number {
  if (typeof body === "string") return Buffer.byteLength(body, "utf8");
  if (Buffer.isBuffer(body)) return body.length;
  if (body == null) return 0;
  if (typeof body === "object") {
    try {
      return Buffer.byteLength(JSON.stringify(body), "utf8");
    } catch {
      return 0;
    }
  }
  return 0;
}

function normalizeMethod(method: unknown): string {
  if (typeof method !== "string") return "GET";
  const normalized = method.trim().toUpperCase();
  return normalized.length > 0 ? normalized : "GET";
}

function detectUserAgentFamily(userAgent: string): UserAgentFamily {
  const ua = userAgent.toLowerCase();
  if (ua.includes("curl")) return "curl";
  if (ua.includes("python") || ua.includes("requests") || ua.includes("httpx")) {
    return "python";
  }
  if (
    ua.includes("bot") ||
    ua.includes("crawler") ||
    ua.includes("spider") ||
    ua.includes("scrapy") ||
    ua.includes("wget") ||
    ua.includes("headless") ||
    ua.includes("zgrab") ||
    ua.includes("nmap")
  ) {
    return "bot";
  }
  if (
    ua.includes("mozilla/") ||
    ua.includes("chrome/") ||
    ua.includes("safari/") ||
    ua.includes("firefox/")
  ) {
    return "browser";
  }
  return "unknown";
}

function extractQueryKeys(query: Record<string, unknown> | undefined): string[] {
  if (!query) return [];
  return Object.keys(query)
    .map((key) => key.trim())
    .filter((key) => key.length > 0)
    .sort();
}

export function collectQueryValues(query: Record<string, unknown> | undefined): string[] {
  if (!query) return [];
  const values: string[] = [];
  for (const rawValue of Object.values(query)) {
    if (typeof rawValue === "string") {
      values.push(rawValue);
      continue;
    }
    if (Array.isArray(rawValue)) {
      for (const item of rawValue) {
        if (typeof item === "string") values.push(item);
      }
      continue;
    }
    if (rawValue != null) {
      values.push(String(rawValue));
    }
  }
  return values;
}

export function collectHeaderValues(headers: Record<string, unknown> | undefined): string[] {
  if (!headers) return [];
  const values: string[] = [];
  for (const value of Object.values(headers)) {
    if (typeof value === "string") {
      values.push(value);
      continue;
    }
    if (Array.isArray(value)) {
      for (const item of value) {
        if (typeof item === "string") values.push(item);
      }
    }
  }
  return values;
}

export function bodyTextForDetection(body: unknown, maxBytes = 2048): string | undefined {
  if (typeof body === "string") return body.slice(0, maxBytes);
  if (Buffer.isBuffer(body)) return body.subarray(0, maxBytes).toString("utf8");
  if (body != null && typeof body === "object") {
    try {
      return JSON.stringify(body).slice(0, maxBytes);
    } catch {
      return undefined;
    }
  }
  return undefined;
}

export function redactRequestMetadata(request: RequestLike, secret: string): RedactedRequestMetadata {
  const headers = request.headers ?? {};
  const userAgent = headerValue(headers, "user-agent");
  const path = extractPath(request);
  const queryKeys = extractQueryKeys(request.query);

  return {
    method: normalizeMethod(request.method),
    path,
    normalizedPath: normalizeTrapPath(path),
    ipHash: hashIp(extractIp(request), secret),
    userAgentHash: hashUserAgent(userAgent || undefined, secret),
    userAgentFamily: detectUserAgentFamily(userAgent),
    hasAuthHeader: headerValue(headers, "authorization").length > 0,
    hasCookieHeader: headerValue(headers, "cookie").length > 0,
    hasAppCheckHeader: headerValue(headers, "x-firebase-appcheck").length > 0,
    queryKeyCount: queryKeys.length,
    queryKeys,
    bodySizeBytes: toBodySizeBytes(request.body),
    bodyCaptured: false,
  };
}
