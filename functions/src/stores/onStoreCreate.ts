import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import { slugify } from "../utils/slugify";

/**
 * Triggered when a new store document is created.
 * Generates a unique URL-friendly slug from the store name.
 */
export const onStoreCreate = functions.firestore
  .document("stores/{storeId}")
  .onCreate(async (snap, context) => {
    const db = admin.firestore();
    const storeId = context.params.storeId;
    const data = snap.data();

    if (!data.name) {
      functions.logger.warn(`Store ${storeId} created without a name.`);
      return;
    }

    // If slug already provided and valid, use it; otherwise generate from name
    let baseSlug = data.slug && typeof data.slug === "string"
      ? slugify(data.slug)
      : slugify(data.name as string);

    // Ensure slug is unique
    const uniqueSlug = await ensureUniqueSlug(db, baseSlug, storeId);

    await snap.ref.update({
      slug: uniqueSlug,
      updatedAt: admin.firestore.Timestamp.now(),
    });

    functions.logger.info(`Store ${storeId} slug set to: ${uniqueSlug}`);
  });

async function ensureUniqueSlug(
  db: admin.firestore.Firestore,
  baseSlug: string,
  currentStoreId: string,
  attempt = 0
): Promise<string> {
  const candidate = attempt === 0 ? baseSlug : `${baseSlug}-${attempt}`;

  const existing = await db
    .collection("stores")
    .where("slug", "==", candidate)
    .limit(1)
    .get();

  // If no conflict, or conflict is with itself (shouldn't happen on create), use it
  if (existing.empty) {
    return candidate;
  }

  return ensureUniqueSlug(db, baseSlug, currentStoreId, attempt + 1);
}
