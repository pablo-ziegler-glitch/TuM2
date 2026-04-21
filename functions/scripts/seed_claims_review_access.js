#!/usr/bin/env node
/* eslint-disable no-console */
const admin = require("firebase-admin");

function parseArgs(argv) {
  const args = {
    project: process.env.GCLOUD_PROJECT || "",
    apply: false,
    zoneId: "zone-staging-claims",
    categoryId: "kiosk",
  };
  for (let i = 2; i < argv.length; i++) {
    const token = argv[i];
    if (token === "--apply") {
      args.apply = true;
      continue;
    }
    if (!token.startsWith("--")) continue;
    const key = token.slice(2);
    const value = argv[i + 1];
    if (value == null || value.startsWith("--")) {
      throw new Error(`Missing value for --${key}`);
    }
    i += 1;
    if (key === "project") args.project = value.trim();
    if (key === "zone-id") args.zoneId = value.trim();
    if (key === "category-id") args.categoryId = value.trim();
  }
  return args;
}

const USER_SEEDS = [
  {
    uid: "reviewer1",
    email: "reviewer1@tum2.test",
    claims: { role: "admin", claimsReviewLevel: "reviewer" },
  },
  {
    uid: "senior1",
    email: "senior1@tum2.test",
    claims: { role: "admin", claimsReviewLevel: "senior_reviewer" },
  },
  {
    uid: "superadmin1",
    email: "superadmin1@tum2.test",
    claims: { role: "super_admin" },
  },
];

const CLAIM_STATUSES = [
  "under_review",
  "needs_more_info",
  "conflict_detected",
  "duplicate_claim",
];

function resolveSeedPassword() {
  const password =
    process.env.CLAIMS_REVIEW_SEED_PASSWORD ||
    process.env.TUM2_CLAIMS_SEED_PASSWORD ||
    "";

  if (!password) {
    throw new Error(
      "Missing seed password. Define CLAIMS_REVIEW_SEED_PASSWORD (or TUM2_CLAIMS_SEED_PASSWORD) before running with --apply."
    );
  }

  if (password.length < 12) {
    throw new Error("Invalid seed password. Minimum length is 12 characters.");
  }

  return password;
}

async function ensureUser(auth, seed, apply) {
  let user;
  try {
    user = await auth.getUserByEmail(seed.email);
  } catch {
    if (!apply) {
      return { uid: seed.uid, created: false, email: seed.email, dryRun: true };
    }
    const password = resolveSeedPassword();
    user = await auth.createUser({
      uid: seed.uid,
      email: seed.email,
      emailVerified: true,
      password,
      disabled: false,
    });
  }
  if (apply) {
    await auth.setCustomUserClaims(user.uid, seed.claims);
  }
  return { uid: user.uid, created: true, email: seed.email, claims: seed.claims };
}

async function seedClaims(db, args, apply) {
  const now = admin.firestore.FieldValue.serverTimestamp();
  const outputs = [];
  for (let i = 0; i < CLAIM_STATUSES.length; i++) {
    const status = CLAIM_STATUSES[i];
    const claimId = `claim-seed-${status}`;
    const merchantId = `merchant-seed-${status}`;
    if (!apply) {
      outputs.push({ claimId, merchantId, status, dryRun: true });
      continue;
    }
    await db.collection("merchants").doc(merchantId).set(
      {
        merchantId,
        name: `Merchant Seed ${status}`,
        categoryId: args.categoryId,
        zoneId: args.zoneId,
        status: "active",
        visibilityStatus: "visible",
        ownershipStatus: status === "under_review" ? "unclaimed" : "claimed",
        updatedAt: now,
        createdAt: now,
      },
      { merge: true }
    );
    await db.collection("merchant_claims").doc(claimId).set(
      {
        claimId,
        merchantId,
        userId: "seed-user-claims",
        zoneId: args.zoneId,
        categoryId: args.categoryId,
        claimStatus: status,
        userVisibleStatus: status,
        hasConflict: status === "conflict_detected",
        hasDuplicate: status === "duplicate_claim",
        requiresManualReview: true,
        updatedAt: now,
        createdAt: now,
        submittedAt: now,
      },
      { merge: true }
    );
    outputs.push({ claimId, merchantId, status, dryRun: false });
  }
  return outputs;
}

async function main() {
  const args = parseArgs(process.argv);
  if (!admin.apps.length) {
    admin.initializeApp(args.project ? { projectId: args.project } : undefined);
  }
  const auth = admin.auth();
  const db = admin.firestore();

  const users = [];
  for (const seed of USER_SEEDS) {
    users.push(await ensureUser(auth, seed, args.apply));
  }
  const claims = await seedClaims(db, args, args.apply);

  console.log(
    JSON.stringify(
      {
        script: "seed_claims_review_access",
        mode: args.apply ? "apply" : "dry_run",
        project: args.project || process.env.GCLOUD_PROJECT || null,
        zoneId: args.zoneId,
        categoryId: args.categoryId,
        users,
        claims,
      },
      null,
      2
    )
  );
}

main().catch((error) => {
  console.error("[seed_claims_review_access] failed", error);
  process.exit(1);
});
