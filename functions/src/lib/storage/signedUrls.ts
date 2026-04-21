import { getStorage } from "firebase-admin/storage";

interface GenerateSignedUrlParams {
  bucketName?: string;
  objectPath: string;
  expiresInSeconds: number;
  contentDisposition: string;
  contentType?: string;
}

interface SignedUrlGenerator {
  getSignedUrl: (options: {
    version: "v4";
    action: "read";
    expires: number;
    responseDisposition: string;
    responseType?: string;
  }) => Promise<[string]>;
}

interface GenerateWithFileParams extends GenerateSignedUrlParams {
  file?: SignedUrlGenerator;
}

export interface AttachmentSignedUrlResponse {
  url: string;
  expiresAtMillis: number;
}

const MIN_TTL_SECONDS = 5;
const MAX_TTL_SECONDS = 300;

function assertValidPath(path: string): void {
  if (!path || path.trim().length === 0) {
    throw new Error("objectPath es requerido.");
  }
  if (path.includes("..")) {
    throw new Error("objectPath inválido.");
  }
}

function assertValidTtl(expiresInSeconds: number): void {
  if (!Number.isFinite(expiresInSeconds)) {
    throw new Error("expiresInSeconds inválido.");
  }
  const ttl = Math.trunc(expiresInSeconds);
  if (ttl < MIN_TTL_SECONDS || ttl > MAX_TTL_SECONDS) {
    throw new Error(
      `expiresInSeconds fuera de rango (${MIN_TTL_SECONDS}-${MAX_TTL_SECONDS}).`
    );
  }
}

async function generateSignedUrl(
  params: GenerateWithFileParams
): Promise<AttachmentSignedUrlResponse> {
  assertValidPath(params.objectPath);
  assertValidTtl(params.expiresInSeconds);
  if (!params.contentDisposition || params.contentDisposition.trim().length === 0) {
    throw new Error("contentDisposition es requerido.");
  }

  const now = Date.now();
  const expiresAtMillis = now + Math.trunc(params.expiresInSeconds) * 1000;
  const file =
    params.file ??
    getStorage()
      .bucket(params.bucketName)
      .file(params.objectPath);

  const [url] = await file.getSignedUrl({
    version: "v4",
    action: "read",
    expires: expiresAtMillis,
    responseDisposition: params.contentDisposition,
    responseType: params.contentType,
  });

  return { url, expiresAtMillis };
}

export async function generatePreviewSignedUrl(
  params: Omit<GenerateSignedUrlParams, "contentDisposition"> & {
    file?: SignedUrlGenerator;
    fileName: string;
  }
): Promise<AttachmentSignedUrlResponse> {
  return generateSignedUrl({
    ...params,
    contentDisposition: `inline; filename="${params.fileName}"`,
  });
}

export async function generateDownloadSignedUrl(
  params: Omit<GenerateSignedUrlParams, "contentDisposition"> & {
    file?: SignedUrlGenerator;
    fileName: string;
  }
): Promise<AttachmentSignedUrlResponse> {
  return generateSignedUrl({
    ...params,
    contentDisposition: `attachment; filename="${params.fileName}"`,
  });
}
