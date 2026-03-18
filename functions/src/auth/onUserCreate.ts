import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import { UserDoc } from "../types";

/**
 * Triggered when a new Firebase Auth user is created.
 * Creates the corresponding Firestore user document.
 */
export const onUserCreate = functions.auth.user().onCreate(async (user) => {
  const db = admin.firestore();

  const userDoc: UserDoc = {
    id: user.uid,
    email: user.email ?? "",
    displayName: user.displayName ?? user.email?.split("@")[0] ?? "Usuario",
    roleType: null,
    currentRank: "Vecino",
    xpPoints: 0,
    status: "active",
    createdAt: admin.firestore.Timestamp.now(),
  };

  try {
    await db.collection("users").doc(user.uid).set(userDoc);
    functions.logger.info(`User document created for uid: ${user.uid}`);
  } catch (error) {
    functions.logger.error(`Failed to create user document for uid: ${user.uid}`, error);
    throw error;
  }
});
