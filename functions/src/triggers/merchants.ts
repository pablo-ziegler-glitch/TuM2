import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { getFirestore } from "firebase-admin/firestore";
import { computeMerchantPublicProjection } from "../lib/projection";
import { MerchantDoc, OperationalSignals } from "../lib/types";
import {
  areComparablePublicStatesEqual,
  syncMerchantPublicProjection,
} from "../lib/publicProjectionSync";

const db = () => getFirestore();

/**
 * onMerchantWriteSyncPublic
 *
 * Triggered on any write to merchants/{merchantId}.
 * Creates or updates merchant_public/{merchantId} with a computed projection.
 * Suppressed merchants are hidden from public view.
 */
export const onMerchantWriteSyncPublic = onDocumentWritten(
  "merchants/{merchantId}",
  async (event) => {
    const merchantId = event.params.merchantId;
    const beforeSnap = event.data?.before;
    const afterSnap = event.data?.after;

    // Document was deleted
    if (!afterSnap?.exists) {
      await db()
        .doc(`merchant_public/${merchantId}`)
        .delete();
      return;
    }

    const merchant = afterSnap.data() as MerchantDoc;
    let beforeMerchant: MerchantDoc | undefined;
    if (beforeSnap?.exists) {
      beforeMerchant = beforeSnap.data() as MerchantDoc;
    }

    // Fetch current signals (best-effort)
    const [signalsSnap] = await Promise.all([
      db().doc(`merchant_operational_signals/${merchantId}`).get(),
    ]);

    const signals = signalsSnap.exists
      ? (signalsSnap.data() as OperationalSignals)
      : null;

    const projection = computeMerchantPublicProjection(merchant, signals ?? undefined);
    if (beforeMerchant) {
      const beforeProjection = computeMerchantPublicProjection(
        beforeMerchant,
        signals ?? undefined
      );
      // TODO(finops): Re-evaluar este pre-skip híbrido con métricas reales de costo.
      // Mantener mientras reduzca invocaciones al sync canónico sin perder consistencia.
      if (areComparablePublicStatesEqual(beforeProjection, projection)) {
        return;
      }
    }

    await syncMerchantPublicProjection({
      merchantId,
      merchant,
      signals,
    });

    console.log(`[onMerchantWriteSyncPublic] Synced ${merchantId}`);
  }
);
