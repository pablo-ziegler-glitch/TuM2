import * as admin from "firebase-admin";

// Initialize Firebase Admin SDK for server-side operations
// Uses Application Default Credentials in production (Firebase Hosting)
if (!admin.apps.length) {
  const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;

  if (serviceAccountJson) {
    // Local dev: use service account JSON from env
    const serviceAccount = JSON.parse(serviceAccountJson);
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      projectId: process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID,
    });
  } else {
    // Production: use Application Default Credentials
    admin.initializeApp({
      projectId: process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID,
    });
  }
}

export const adminDb = admin.firestore();
export const adminAuth = admin.auth();
export { admin };
