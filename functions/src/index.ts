import * as admin from "firebase-admin";

// Initialize Firebase Admin SDK
admin.initializeApp();

// Auth triggers
export { onUserCreate } from "./auth/onUserCreate";

// Store triggers
export { onStoreCreate } from "./stores/onStoreCreate";

// Derived field triggers
export {
  onScheduleWrite,
  onSignalWrite,
} from "./derived/recalculateDerivedFields";

export { recalculateDutyStatus } from "./derived/recalculateDutyStatus";

export { onStoreWriteUpdateBadges } from "./derived/updateBadges";

export { onVoteWrite } from "./derived/updateXpAndRank";
