import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { recomputeMerchantOperationalProjection } from "../lib/ownerSchedules";

export const onOwnerWeeklyScheduleWrite = onDocumentWritten(
  "merchants/{merchantId}/schedule_config/{docId}",
  async (event) => {
    const merchantId = event.params.merchantId;
    await recomputeMerchantOperationalProjection(merchantId);
  },
);

export const onOwnerScheduleExceptionWrite = onDocumentWritten(
  "merchants/{merchantId}/schedule_exceptions/{date}",
  async (event) => {
    const merchantId = event.params.merchantId;
    await recomputeMerchantOperationalProjection(merchantId);
  },
);

export const onOwnerScheduleRangeWrite = onDocumentWritten(
  "merchants/{merchantId}/schedule_exceptions_ranges/{rangeId}",
  async (event) => {
    const merchantId = event.params.merchantId;
    await recomputeMerchantOperationalProjection(merchantId);
  },
);
