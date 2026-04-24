import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import test, { before, beforeEach } from "node:test";
import { getApps, initializeApp } from "firebase-admin/app";
import { FieldValue, getFirestore } from "firebase-admin/firestore";

const emulatorHost = process.env.FIRESTORE_EMULATOR_HOST;

let submitOutdatedInfoReportRun:
  | ((request: Record<string, unknown>) => Promise<unknown>)
  | undefined;

function buildRequest(data: Record<string, unknown>): Record<string, unknown> {
  return {
    data,
    auth: null,
    rawRequest: {
      ip: "203.0.113.10",
      headers: {},
    },
  };
}

async function deleteCollection(collectionName: string): Promise<void> {
  const firestore = getFirestore();
  let hasMore = true;
  while (hasMore) {
    const snapshot = await firestore.collection(collectionName).limit(200).get();
    if (snapshot.empty) {
      hasMore = false;
      continue;
    }
    const batch = firestore.batch();
    for (const doc of snapshot.docs) {
      batch.delete(doc.ref);
    }
    await batch.commit();
  }
}

if (!emulatorHost) {
  test(
    "outdated info integration requires FIRESTORE_EMULATOR_HOST",
    { skip: true },
    () => {
      assert.ok(true);
    }
  );
} else {
  before(async () => {
    process.env.GCLOUD_PROJECT ??= "tum2-dev-6283d";
    process.env.OUTDATED_INFO_REPORT_RATE_LIMIT_WINDOW_MS = "60000";
    process.env.OUTDATED_INFO_REPORT_RATE_LIMIT_MAX = "2";
    process.env.OUTDATED_INFO_REPORT_DEDUPE_WINDOW_MS = "86400000";
    process.env.IP_HASH_SALT = "integration-test-salt";

    if (getApps().length === 0) {
      initializeApp({ projectId: process.env.GCLOUD_PROJECT });
    }

    const callables = await import("../outdatedInfoReports");
    submitOutdatedInfoReportRun = (
      callables.submitOutdatedInfoReport as unknown as {
        run: (request: Record<string, unknown>) => Promise<unknown>;
      }
    ).run;
  });

  beforeEach(async () => {
    await Promise.all([
      deleteCollection("merchant_public"),
      deleteCollection("reports"),
      deleteCollection("outdated_info_report_dedupes"),
      deleteCollection("outdated_info_report_rate_limits"),
    ]);
  });

  test("crea reporte válido y persiste dedupe/rate-limit", async () => {
    assert.ok(submitOutdatedInfoReportRun);
    const firestore = getFirestore();
    const merchantId = `merchant-${randomUUID()}`;
    await firestore.doc(`merchant_public/${merchantId}`).set({
      merchantId,
      zoneId: "zone-1",
      categoryId: "pharmacy",
      name: "Farmacia Test",
      updatedAt: FieldValue.serverTimestamp(),
    });

    const response = (await submitOutdatedInfoReportRun!(
      buildRequest({
        merchantId,
        zoneId: "zone-1",
        reasonCode: "wrong_schedule",
        source: "pharmacy_duty_list",
        dateKey: "2099-01-15",
      })
    )) as {
      created: boolean;
      deduped: boolean;
      reportId: string | null;
    };

    assert.equal(response.created, true);
    assert.equal(response.deduped, false);
    assert.equal(typeof response.reportId, "string");
    assert.ok(response.reportId && response.reportId.length > 0);

    const reportSnap = await firestore.collection("reports").doc(response.reportId!).get();
    assert.equal(reportSnap.exists, true);
    assert.equal(reportSnap.get("targetId"), merchantId);
    assert.equal(reportSnap.get("reasonCode"), "wrong_schedule");
    assert.equal(reportSnap.get("source"), "pharmacy_duty_list");
    assert.equal(reportSnap.get("zoneId"), "zone-1");
    assert.equal(reportSnap.get("channel"), "outdated_info");

    const dedupeSnap = await firestore
      .collection("outdated_info_report_dedupes")
      .limit(1)
      .get();
    assert.equal(dedupeSnap.empty, false);
    assert.equal(dedupeSnap.docs[0].get("lastReportId"), response.reportId);

    const rateSnap = await firestore
      .collection("outdated_info_report_rate_limits")
      .limit(1)
      .get();
    assert.equal(rateSnap.empty, false);
    assert.equal(rateSnap.docs[0].get("count"), 1);
  });

  test("dedupe evita crear múltiples reports para mismo fingerprint", async () => {
    assert.ok(submitOutdatedInfoReportRun);
    const firestore = getFirestore();
    const merchantId = `merchant-${randomUUID()}`;
    await firestore.doc(`merchant_public/${merchantId}`).set({
      merchantId,
      zoneId: "zone-1",
      categoryId: "pharmacy",
      name: "Farmacia Dedupe",
      updatedAt: FieldValue.serverTimestamp(),
    });

    const first = (await submitOutdatedInfoReportRun!(
      buildRequest({
        merchantId,
        zoneId: "zone-1",
        reasonCode: "wrong_schedule",
        source: "pharmacy_duty_detail",
        dateKey: "2099-01-16",
      })
    )) as { created: boolean; deduped: boolean; reportId: string | null };

    const second = (await submitOutdatedInfoReportRun!(
      buildRequest({
        merchantId,
        zoneId: "zone-1",
        reasonCode: "wrong_schedule",
        source: "pharmacy_duty_detail",
        dateKey: "2099-01-16",
      })
    )) as { created: boolean; deduped: boolean; reportId: string | null };

    assert.equal(first.created, true);
    assert.equal(second.created, false);
    assert.equal(second.deduped, true);
    assert.equal(second.reportId, first.reportId);

    const reports = await firestore.collection("reports").get();
    assert.equal(reports.size, 1);
  });

  test("rechaza reasonCode no permitido", async () => {
    assert.ok(submitOutdatedInfoReportRun);
    const firestore = getFirestore();
    const merchantId = `merchant-${randomUUID()}`;
    await firestore.doc(`merchant_public/${merchantId}`).set({
      merchantId,
      zoneId: "zone-1",
      categoryId: "pharmacy",
      updatedAt: FieldValue.serverTimestamp(),
    });

    await assert.rejects(
      async () =>
        submitOutdatedInfoReportRun!(
          buildRequest({
            merchantId,
            zoneId: "zone-1",
            reasonCode: "unknown_reason",
            source: "pharmacy_duty_list",
            dateKey: "2099-01-17",
          })
        ),
      (error: unknown) => {
        const err = error as { code?: string };
        assert.equal(err.code, "invalid-argument");
        return true;
      }
    );
  });

  test("rechaza categoría no farmacia", async () => {
    assert.ok(submitOutdatedInfoReportRun);
    const firestore = getFirestore();
    const merchantId = `merchant-${randomUUID()}`;
    await firestore.doc(`merchant_public/${merchantId}`).set({
      merchantId,
      zoneId: "zone-1",
      categoryId: "kiosk",
      updatedAt: FieldValue.serverTimestamp(),
    });

    await assert.rejects(
      async () =>
        submitOutdatedInfoReportRun!(
          buildRequest({
            merchantId,
            zoneId: "zone-1",
            reasonCode: "wrong_schedule",
            source: "pharmacy_duty_list",
            dateKey: "2099-01-18",
          })
        ),
      (error: unknown) => {
        const err = error as { code?: string };
        assert.equal(err.code, "failed-precondition");
        return true;
      }
    );
  });

  test("aplica rate limit por ipHash/ventana", async () => {
    assert.ok(submitOutdatedInfoReportRun);
    const firestore = getFirestore();
    const merchantId = `merchant-${randomUUID()}`;
    await firestore.doc(`merchant_public/${merchantId}`).set({
      merchantId,
      zoneId: "zone-1",
      categoryId: "pharmacy",
      updatedAt: FieldValue.serverTimestamp(),
    });

    await submitOutdatedInfoReportRun!(
      buildRequest({
        merchantId,
        zoneId: "zone-1",
        reasonCode: "wrong_schedule",
        source: "pharmacy_duty_list",
        dateKey: "2099-01-19",
      })
    );
    await submitOutdatedInfoReportRun!(
      buildRequest({
        merchantId,
        zoneId: "zone-1",
        reasonCode: "not_found",
        source: "pharmacy_duty_list",
        dateKey: "2099-01-19",
      })
    );

    await assert.rejects(
      async () =>
        submitOutdatedInfoReportRun!(
          buildRequest({
            merchantId,
            zoneId: "zone-1",
            reasonCode: "data_mismatch",
            source: "pharmacy_duty_list",
            dateKey: "2099-01-19",
          })
        ),
      (error: unknown) => {
        const err = error as { code?: string; details?: Record<string, unknown> };
        assert.equal(err.code, "resource-exhausted");
        assert.equal(err.details?.code, "rate_limited");
        return true;
      }
    );
  });
}
