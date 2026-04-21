import assert from "node:assert/strict";
import test from "node:test";
import {
  generateDownloadSignedUrl,
  generatePreviewSignedUrl,
} from "../storage/signedUrls";

test("preview usa inline y respeta expiración", async () => {
  let receivedDisposition = "";
  const response = await generatePreviewSignedUrl({
    objectPath: "claims/claim-1/attachments/doc-1/original",
    expiresInSeconds: 60,
    contentType: "application/pdf",
    fileName: "doc.pdf",
    file: {
      getSignedUrl: async (options) => {
        receivedDisposition = options.responseDisposition;
        return ["https://signed-preview.local"];
      },
    },
  });

  assert.equal(response.url, "https://signed-preview.local");
  assert.ok(response.expiresAtMillis > Date.now());
  assert.equal(receivedDisposition, 'inline; filename="doc.pdf"');
});

test("download usa attachment", async () => {
  let disposition = "";
  const response = await generateDownloadSignedUrl({
    objectPath: "claims/claim-1/attachments/doc-1/original",
    expiresInSeconds: 30,
    fileName: "doc.pdf",
    file: {
      getSignedUrl: async (options) => {
        disposition = String(options.responseDisposition ?? "");
        return ["https://signed-download.local"];
      },
    },
  });

  assert.equal(response.url, "https://signed-download.local");
  assert.equal(disposition, 'attachment; filename="doc.pdf"');
});

test("TTL fuera de rango rechaza", async () => {
  await assert.rejects(
    () =>
      generatePreviewSignedUrl({
        objectPath: "claims/claim-1/attachments/doc-1/original",
        expiresInSeconds: 301,
        fileName: "doc.pdf",
        file: {
          getSignedUrl: async () => ["never"],
        },
      })
  );
});

test("error de objeto inexistente no fuga información", async () => {
  await assert.rejects(
    () =>
      generateDownloadSignedUrl({
        objectPath: "claims/claim-1/attachments/doc-missing/original",
        expiresInSeconds: 30,
        fileName: "missing.pdf",
        file: {
          getSignedUrl: async () => {
            throw new Error("Not Found");
          },
        },
      }),
    /Not Found/
  );
});
