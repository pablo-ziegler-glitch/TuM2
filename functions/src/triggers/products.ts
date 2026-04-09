import { getFirestore } from "firebase-admin/firestore";
import { onDocumentWritten } from "firebase-functions/v2/firestore";

import { MerchantProductDoc } from "../lib/types";

const db = () => getFirestore();

type ProductWriteAction = "create" | "update" | "delete";

function isActiveVisible(product: Partial<MerchantProductDoc> | undefined): boolean {
  if (!product) return false;
  return product.status === "active" && product.visibilityStatus === "visible";
}

export const onMerchantProductWriteRecalculateHasProducts = onDocumentWritten(
  "merchant_products/{productId}",
  async (event) => {
    const startedAtMs = Date.now();
    const productId = event.params.productId;
    const beforeExists = event.data?.before.exists ?? false;
    const afterExists = event.data?.after.exists ?? false;
    const action: ProductWriteAction = !beforeExists && afterExists
      ? "create"
      : beforeExists && !afterExists
        ? "delete"
        : "update";

    const beforeProduct = beforeExists
      ? (event.data?.before.data() as MerchantProductDoc | undefined)
      : undefined;
    const afterProduct = afterExists
      ? (event.data?.after.data() as MerchantProductDoc | undefined)
      : undefined;

    if (
      action === "update" &&
      beforeProduct &&
      afterProduct &&
      (beforeProduct.merchantId ?? "") === (afterProduct.merchantId ?? "") &&
      (beforeProduct.status ?? "") === (afterProduct.status ?? "") &&
      (beforeProduct.visibilityStatus ?? "") === (afterProduct.visibilityStatus ?? "")
    ) {
      return;
    }
    if (action === "create" && !isActiveVisible(afterProduct)) return;
    if (action === "delete" && !isActiveVisible(beforeProduct)) return;

    const beforeMerchantId = (
      beforeProduct
    )?.merchantId;
    const afterMerchantId = (
      afterProduct
    )?.merchantId;

    const merchantIds = new Set<string>();
    if (beforeMerchantId?.trim()) merchantIds.add(beforeMerchantId.trim());
    if (afterMerchantId?.trim()) merchantIds.add(afterMerchantId.trim());
    if (merchantIds.size === 0) return;

    await Promise.all(
      [...merchantIds].map(async (merchantId) => {
        const hasProducts = await merchantHasActiveVisibleProducts(merchantId);
        const merchantRef = db().doc(`merchants/${merchantId}`);
        const merchantSnap = await merchantRef.get();
        if (!merchantSnap.exists) {
          console.log(
            JSON.stringify({
              source: "owner_panel",
              action: "recalculate_has_products",
              result: "merchant_not_found",
              merchantId,
              productId,
              writeAction: action,
              latencyMs: Date.now() - startedAtMs,
            })
          );
          return;
        }

        const currentHasProducts = merchantSnap.data()?.hasProducts === true;
        if (currentHasProducts === hasProducts) {
          console.log(
            JSON.stringify({
              source: "owner_panel",
              action: "recalculate_has_products",
              result: "unchanged",
              merchantId,
              productId,
              writeAction: action,
              hasProducts,
              latencyMs: Date.now() - startedAtMs,
            })
          );
          return;
        }

        await merchantRef.set({ hasProducts }, { merge: true });

        console.log(
          JSON.stringify({
            source: "owner_panel",
            action: "recalculate_has_products",
            result: "updated",
            merchantId,
            productId,
            writeAction: action,
            hasProducts,
            latencyMs: Date.now() - startedAtMs,
          })
        );
      })
    );
  }
);

async function merchantHasActiveVisibleProducts(
  merchantId: string
): Promise<boolean> {
  const snapshot = await db()
    .collection("merchant_products")
    .where("merchantId", "==", merchantId)
    .where("status", "==", "active")
    .where("visibilityStatus", "==", "visible")
    .limit(1)
    .get();
  return !snapshot.empty;
}
