import {
  createCipheriv,
  createDecipheriv,
  createHash,
  randomBytes,
} from "node:crypto";

type SensitiveFieldKey = "phone" | "claimantDisplayName" | "claimantNote";

export interface SensitiveVault {
  keyVersion: string;
  phoneCiphertext?: string | null;
  claimantDisplayNameCiphertext?: string | null;
  claimantNoteCiphertext?: string | null;
  phoneFingerprint?: string | null;
  claimantDisplayNameFingerprint?: string | null;
  claimantNoteFingerprint?: string | null;
  fingerprintPrimary?: string | null;
}

const AES_ALGO = "aes-256-gcm";
const IV_BYTES = 12;
const TAG_BYTES = 16;

function resolveEncryptionKey(): Buffer {
  const explicitB64 = process.env.CLAIM_SENSITIVE_KEY_B64;
  if (typeof explicitB64 === "string" && explicitB64.trim().length > 0) {
    const decoded = Buffer.from(explicitB64.trim(), "base64");
    if (decoded.length !== 32) {
      throw new Error("CLAIM_SENSITIVE_KEY_B64 inválida: debe decodificar 32 bytes.");
    }
    return decoded;
  }

  const explicitRaw = process.env.CLAIM_SENSITIVE_KEY;
  if (typeof explicitRaw === "string" && explicitRaw.trim().length > 0) {
    const derived = createHash("sha256").update(explicitRaw.trim()).digest();
    if (derived.length === 32) return derived;
  }
  throw new Error(
    "Falta clave sensible: configurá CLAIM_SENSITIVE_KEY_B64 (Secret Manager) en runtime."
  );
}

function keyVersion(): string {
  const raw = process.env.CLAIM_SENSITIVE_KEY_VERSION;
  return typeof raw === "string" && raw.trim().length > 0 ? raw.trim() : "v1";
}

function toBase64(value: Buffer): string {
  return value.toString("base64");
}

function fromBase64(value: string): Buffer {
  return Buffer.from(value, "base64");
}

function normalizeForFingerprint(value: string): string {
  return value
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/\s+/g, " ")
    .trim()
    .toLowerCase();
}

export function fingerprint(value: string, scope: string): string {
  const normalized = normalizeForFingerprint(value);
  if (!normalized) return "";
  return createHash("sha256")
    .update(`${scope}:${normalized}`)
    .digest("hex");
}

export function encryptSensitive(value: string): string {
  const iv = randomBytes(IV_BYTES);
  const key = resolveEncryptionKey();
  const cipher = createCipheriv(AES_ALGO, key, iv, { authTagLength: TAG_BYTES });
  const ciphertext = Buffer.concat([cipher.update(value, "utf8"), cipher.final()]);
  const tag = cipher.getAuthTag();
  return `${toBase64(iv)}.${toBase64(tag)}.${toBase64(ciphertext)}`;
}

export function decryptSensitive(payload: string): string {
  const chunks = payload.split(".");
  if (chunks.length !== 3) {
    throw new Error("payload cifrado inválido");
  }
  const [ivRaw, tagRaw, ciphertextRaw] = chunks;
  const iv = fromBase64(ivRaw);
  const tag = fromBase64(tagRaw);
  const ciphertext = fromBase64(ciphertextRaw);
  const key = resolveEncryptionKey();
  const decipher = createDecipheriv(AES_ALGO, key, iv, {
    authTagLength: TAG_BYTES,
  });
  decipher.setAuthTag(tag);
  const plaintext = Buffer.concat([
    decipher.update(ciphertext),
    decipher.final(),
  ]);
  return plaintext.toString("utf8");
}

function maskPhone(phone: string): string {
  const compact = phone.replace(/\s+/g, "");
  if (compact.length <= 4) return "***";
  return `${compact.slice(0, 2)}***${compact.slice(-2)}`;
}

function maskText(value: string): string {
  const trimmed = value.trim();
  if (trimmed.length <= 2) return "**";
  return `${trimmed[0]}***${trimmed[trimmed.length - 1]}`;
}

export function buildSensitiveVault(params: {
  userId: string;
  merchantId: string;
  phone: string | null;
  claimantDisplayName: string | null;
  claimantNote: string | null;
}): {
  vault: SensitiveVault;
  masked: Record<string, string | null>;
} {
  const phone = params.phone?.trim() ?? null;
  const displayName = params.claimantDisplayName?.trim() ?? null;
  const note = params.claimantNote?.trim() ?? null;

  const phoneFingerprint = phone ? fingerprint(phone, "phone") : null;
  const claimantDisplayNameFingerprint = displayName
    ? fingerprint(displayName, "claimantDisplayName")
    : null;
  const claimantNoteFingerprint = note ? fingerprint(note, "claimantNote") : null;
  const fingerprintPrimary = fingerprint(
    `${params.userId}|${params.merchantId}|${phoneFingerprint ?? ""}|${
      claimantDisplayNameFingerprint ?? ""
    }`,
    "claim-primary"
  );

  const vault: SensitiveVault = {
    keyVersion: keyVersion(),
    phoneCiphertext: phone ? encryptSensitive(phone) : null,
    claimantDisplayNameCiphertext: displayName ? encryptSensitive(displayName) : null,
    claimantNoteCiphertext: note ? encryptSensitive(note) : null,
    phoneFingerprint,
    claimantDisplayNameFingerprint,
    claimantNoteFingerprint,
    fingerprintPrimary: fingerprintPrimary || null,
  };

  return {
    vault,
    masked: {
      phoneMasked: phone ? maskPhone(phone) : null,
      claimantDisplayNameMasked: displayName ? maskText(displayName) : null,
      claimantNoteMasked: note ? maskText(note) : null,
    },
  };
}

export function revealSensitiveFields(params: {
  vault: SensitiveVault;
  requestedFields: SensitiveFieldKey[];
}): Partial<Record<SensitiveFieldKey, string>> {
  const result: Partial<Record<SensitiveFieldKey, string>> = {};
  for (const field of params.requestedFields) {
    if (field === "phone" && params.vault.phoneCiphertext) {
      result.phone = decryptSensitive(params.vault.phoneCiphertext);
      continue;
    }
    if (field === "claimantDisplayName" && params.vault.claimantDisplayNameCiphertext) {
      result.claimantDisplayName = decryptSensitive(
        params.vault.claimantDisplayNameCiphertext
      );
      continue;
    }
    if (field === "claimantNote" && params.vault.claimantNoteCiphertext) {
      result.claimantNote = decryptSensitive(params.vault.claimantNoteCiphertext);
    }
  }
  return result;
}
